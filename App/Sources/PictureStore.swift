import Foundation
import CoreGraphics
import ImageIO
import Combine
import UniformTypeIdentifiers
import SeedboardCore

// Where the pictures laid on boards are kept (0.3). A folder `Pictures` beside `Boards`: on the device and, when iCloud
// is on, in the same iCloud folder (Documents/Pictures). A picture file is written ONCE under a fresh name
// `<UUID>.jpg` and never changed, so two devices can never write the same file. The board only names it.
//
// Reading: a memory cache of decoded pictures, filled off the main thread; a file that is not here yet (iCloud is
// still bringing it) is asked for, and the board redraws when it arrives. With `-sampleData` everything lives in a
// temporary folder and iCloud is never touched.

final class PictureStore: @unchecked Sendable {
    static let shared = PictureStore()

    /// Tells the boards on screen to redraw: a picture was read, or arrived from iCloud.
    let arrived = PassthroughSubject<Void, Never>()

    /// The longest side a picture is kept at, in pixels, and the JPEG quality.
    static let longestSide = 2048
    static let quality = 0.8

    private final class Box { let image: CGImage; init(_ image: CGImage) { self.image = image } }

    private let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.totalCostLimit = 160 * 1024 * 1024
        return cache
    }()
    private let lock = NSLock()
    private var loading: Set<String> = []
    private var tries: [String: (count: Int, last: Date)] = [:]
    private var cloudPictures: URL?
    private var coming: Set<String> = []
    /// Picture files that are on this device but that iCloud has not taken yet (the amber dot in the list).
    private var goingUp: Set<String> = []
    private var upTimer: Timer?

    let sample = LaunchOptions.sampleData

    private init() {
        guard !sample else { return }
        // The same places the boards use (BoardStore's iCloud container), found through the store's own folders.
        Task { @MainActor in
            let found: URL? = await AppModel.shared.store.kept { places in
                places.boards.dropFirst().first?.deletingLastPathComponent().appendingPathComponent("Pictures", isDirectory: true)
            } ?? nil
            if let found { try? FileManager.default.createDirectory(at: found, withIntermediateDirectories: true) }
            self.lock.lock(); self.cloudPictures = found; self.lock.unlock()
            self.arrived.send()
            self.housekeepingSoon()
            self.lookAtUploads()
        }
    }

    // MARK: Places

    /// The device's folder (or, in sample mode, a temporary one).
    var local: URL {
        let base = sample
            ? FileManager.default.temporaryDirectory.appendingPathComponent("SeedboardSamplePictures", isDirectory: true)
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pictures", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private var cloud: URL? {
        lock.lock(); defer { lock.unlock() }
        return cloudPictures
    }

    // MARK: Taking a picture in

    /// A picture that came in: scaled so its long side is at most 2048 pixels, transparency flattened onto white,
    /// saved as JPEG 0.8 under a fresh name, on the device and in iCloud. nil when the bytes are no picture or could not be saved.
    func take(_ data: Data, as fixedName: String? = nil) -> (name: String, pixels: CGSize)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else { return nil }
        let limit = min(Self.longestSide, max(w, h))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: limit,
        ]
        guard let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let flat = Self.flattened(scaled), let bytes = Self.jpeg(flat) else { return nil }
        let name = fixedName ?? PictureKeeping.freshName()
        let file = local.appendingPathComponent(name)
        guard (try? bytes.write(to: file, options: .atomic)) != nil else { return nil }
        if let cloud {
            var problem: NSError?
            NSFileCoordinator().coordinate(writingItemAt: cloud.appendingPathComponent(name), options: .forReplacing, error: &problem) { url in
                try? bytes.write(to: url, options: .atomic)
            }
            watchUpload([name])
        }
        cache.setObject(Box(flat), forKey: name as NSString, cost: flat.width * flat.height * 4)
        return (name, CGSize(width: flat.width, height: flat.height))
    }

    /// The picture on white (a JPEG has no transparency).
    private static func flattened(_ image: CGImage) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(box)
        ctx.draw(image, in: box)
        return ctx.makeImage()
    }

    private static func jpeg(_ image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    // MARK: Reading

    /// The picture if it is in memory; otherwise nil, and it is being read (or asked for from iCloud) — the boards
    /// redraw through `arrived` when it is there.
    func image(_ name: String) -> CGImage? {
        if let box = cache.object(forKey: name as NSString) { return box.image }
        start(name)
        return nil
    }

    /// The picture now, read here and now if need be: for the pictures a board is exported or shared as.
    func imageNow(_ name: String) -> CGImage? {
        if let box = cache.object(forKey: name as NSString) { return box.image }
        guard let image = read(name) else { return nil }
        cache.setObject(Box(image), forKey: name as NSString, cost: image.width * image.height * 4)
        return image
    }

    /// True when the file is not on this device yet and iCloud has been asked for it.
    func isComing(_ name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return coming.contains(name)
    }

    private func start(_ name: String) {
        guard PictureKeeping.isPlainName(name) else { return }
        lock.lock()
        let now = Date()
        // Looked for again every few seconds, for a few minutes, while the board keeps asking.
        if loading.contains(name) || (tries[name].map { now.timeIntervalSince($0.last) < 3 || ($0.count >= 60 && now.timeIntervalSince($0.last) < 60) } ?? false) {
            lock.unlock()
            return
        }
        loading.insert(name)
        let count = (tries[name]?.count ?? 0) + 1
        tries[name] = (count >= 60 ? 0 : count, now)
        lock.unlock()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let found = read(name)
            lock.lock(); loading.remove(name); if found != nil { coming.remove(name) }; lock.unlock()
            if let found {
                cache.setObject(Box(found), forKey: name as NSString, cost: found.width * found.height * 4)
                DispatchQueue.main.async { self.arrived.send() }
            } else {
                let on = ask(name)
                lock.lock(); if on { coming.insert(name) } else { coming.remove(name) }; lock.unlock()
                // Not here yet: look again in a few seconds, so a picture that arrives shows by itself.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { self.arrived.send() }
            }
        }
    }

    /// The file's own bytes, for the export of all boards. nil when the file is not on this device.
    func fileBytes(_ name: String) -> Data? {
        guard PictureKeeping.isPlainName(name) else { return nil }
        var places = [local]
        if let cloud { places.append(cloud) }
        for folder in places {
            let file = folder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            var data: Data?
            var problem: NSError?
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { url in data = try? Data(contentsOf: url) }
            if let data { return data }
        }
        return nil
    }

    /// A picture file from an export comes back under its own name. One that is already here stays as it is.
    func adopt(_ data: Data, named name: String) -> Bool {
        guard PictureKeeping.isPlainName(name), name.lowercased().hasSuffix(".jpg") else { return false }
        if FileManager.default.fileExists(atPath: local.appendingPathComponent(name).path) { return true }
        return take(data, as: name) != nil
    }

    /// Reads the file from the device's folder, else from iCloud's when it has been downloaded.
    private func read(_ name: String) -> CGImage? {
        guard PictureKeeping.isPlainName(name) else { return nil }
        var places = [local]
        if let cloud { places.append(cloud) }
        for folder in places {
            let file = folder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            var data: Data?
            var problem: NSError?
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { url in data = try? Data(contentsOf: url) }
            if let data, let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) { return image }
        }
        return nil
    }

    /// Asks iCloud for a file it has not brought yet. True when it is on its way.
    @discardableResult
    private func ask(_ name: String) -> Bool {
        guard let cloud, PictureKeeping.isPlainName(name) else { return false }
        let file = cloud.appendingPathComponent(name)
        let waiting = cloud.appendingPathComponent(".\(name).icloud")
        if FileManager.default.fileExists(atPath: waiting.path) || (try? file.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true {
            try? FileManager.default.startDownloadingUbiquitousItem(at: file)
            return true
        }
        return false
    }

    // MARK: Not in iCloud yet

    /// At the start: every picture on this device is looked at. One that iCloud's folder does not hold at all
    /// (a write that failed) is put there again; one that is there but not sent yet is watched.
    private func lookAtUploads() {
        guard let cloud else { return }
        let local = self.local
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            var waiting: Set<String> = []
            for url in (try? fm.contentsOfDirectory(at: local, includingPropertiesForKeys: nil)) ?? [] {
                let name = url.lastPathComponent
                guard PictureKeeping.isPlainName(name), name.lowercased().hasSuffix(".jpg") else { continue }
                let there = cloud.appendingPathComponent(name)
                if fm.fileExists(atPath: there.path) || fm.fileExists(atPath: cloud.appendingPathComponent(".\(name).icloud").path) {
                    if !Self.isUploaded(there) { waiting.insert(name) }
                } else if let bytes = try? Data(contentsOf: url) {
                    var problem: NSError?
                    NSFileCoordinator().coordinate(writingItemAt: there, options: .forReplacing, error: &problem) { try? bytes.write(to: $0, options: .atomic) }
                    waiting.insert(name)
                }
            }
            if !waiting.isEmpty { self.watchUpload(waiting) }
        }
    }

    /// iCloud has this file. A file it does not know (iCloud off) counts as sent: nothing waits for ever.
    private static func isUploaded(_ file: URL) -> Bool {
        guard let values = try? file.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey]),
              values.isUbiquitousItem == true else { return true }
        return values.ubiquitousItemIsUploaded ?? true
    }

    /// These files were just handed to iCloud: they count as "not in iCloud yet" until it has taken them.
    private func watchUpload(_ names: Set<String>) {
        lock.lock(); goingUp.formUnion(names); let now = goingUp; lock.unlock()
        DispatchQueue.main.async {
            AppModel.shared.picturesNotInCloud = now
            guard self.upTimer == nil else { return }
            self.upTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.checkUploads() }
        }
    }

    private func checkUploads() {
        guard let cloud else { return }
        lock.lock(); let waiting = goingUp; lock.unlock()
        DispatchQueue.global(qos: .utility).async {
            let done = waiting.filter { Self.isUploaded(cloud.appendingPathComponent($0)) }
            self.lock.lock(); self.goingUp.subtract(done); let now = self.goingUp; self.lock.unlock()
            DispatchQueue.main.async {
                if AppModel.shared.picturesNotInCloud != now { AppModel.shared.picturesNotInCloud = now }
                if now.isEmpty { self.upTimer?.invalidate(); self.upTimer = nil }
            }
        }
    }

    // MARK: Housekeeping

    private var housekeepingDone = false

    /// Once per start, a little after the boards are up: a picture file goes only when no board names it —
    /// not the boards, not the removed ones, not the safety copies or earlier versions — and it is older than 30 days.
    /// Rule: `PictureKeeping.deletable`. Anything unreadable or still in iCloud only means: nothing is deleted.
    private func housekeepingSoon() {
        lock.lock()
        if housekeepingDone { lock.unlock(); return }
        housekeepingDone = true
        lock.unlock()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            // Named by a board, or by a starter (a starter keeps a board of its own).
            var named = Set(AppModel.shared.boards.flatMap { $0.pictureNames })
            for entry in AppModel.shared.shelf.entries.values { named.formUnion(entry.board?.pictureNames ?? []) }
            let folders = [self.local] + [self.cloud].compactMap { $0 }
            _ = await AppModel.shared.store.kept { places in
                Self.tidy(pictures: folders, places: places, named: named)
            }
        }
    }

    /// The pass itself. Returns how many files went.
    @discardableResult
    static func tidy(pictures folders: [URL], places: KeptPlaces, named inUse: Set<String>, now: Date = Date()) -> Int {
        let fm = FileManager.default
        var candidates: [(name: String, date: Date?)] = []
        var complete = true
        for folder in folders {
            for url in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                let name = url.lastPathComponent
                if name.hasPrefix(".") { complete = false; continue }   // still only in iCloud: do not guess
                candidates.append((name, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate))
            }
        }
        // Every file that can name a picture, read as plain bytes: boards, removed boards, safety copies, earlier versions.
        var roots = places.boards + places.removed
        roots.append(places.safety)
        // Starters sit in a folder beside each Pictures folder; a starter's board may name a picture too.
        roots += folders.map { $0.deletingLastPathComponent().appendingPathComponent("Starters", isDirectory: true) }
        var blobs: [Data] = []
        for root in roots {
            guard let walk = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: []) else { continue }
            for case let url as URL in walk {
                if url.lastPathComponent.hasSuffix(".icloud") { complete = false; continue }
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { complete = false; continue }
                blobs.append(data)
            }
        }
        var named = inUse
        // Only the files old enough are looked for in the copies.
        let old = Set(PictureKeeping.deletable(files: candidates, named: inUse, now: now))
        for file in candidates where old.contains(file.name) {
            guard let key = file.name.data(using: .utf8) else { continue }
            if blobs.contains(where: { $0.range(of: key) != nil }) { named.insert(file.name) }
        }
        let go = Set(PictureKeeping.deletable(files: candidates, named: named, now: now, complete: complete))
        var gone = 0
        for folder in folders {
            for name in go {
                let file = folder.appendingPathComponent(name)
                guard fm.fileExists(atPath: file.path) else { continue }
                var problem: NSError?
                NSFileCoordinator().coordinate(writingItemAt: file, options: .forDeleting, error: &problem) { url in
                    if (try? fm.removeItem(at: url)) != nil { gone += 1 }
                }
            }
        }
        return gone
    }
}
