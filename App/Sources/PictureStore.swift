import Foundation
import CoreGraphics
import ImageIO
import Combine
import UniformTypeIdentifiers
import SeedboardCore
#if canImport(UIKit)
import UIKit
#endif

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

    /// The copy a board keeps in memory: the picture with its long side at most 1024 pixels (0.5; the file keeps
    /// its 2048). `whole`: the copy is the file itself, there is nothing sharper to read.
    private final class Box {
        let image: CGImage
        let whole: Bool
        init(_ image: CGImage, whole: Bool) { self.image = image; self.whole = whole }
    }

    private let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.totalCostLimit = PictureKeeping.memoryRoom
        return cache
    }()
    private let lock = NSLock()
    private var loading: Set<String> = []
    private var tries: [String: (count: Int, last: Date)] = [:]
    private var cloudPictures: URL?
    private var cloudAsked = Date()
    private var coming: Set<String> = []
    /// Files that were looked for and are not on this device (the plate then says "Picture not here yet").
    private var missing: Set<String> = []
    /// Picture files that are on this device but that iCloud has not taken yet (the amber dot in the list).
    private var goingUp: Set<String> = []
    private var upTimer: Timer?
    /// How often the watch has looked since a picture was last handed to iCloud (it slows down after a minute).
    private var upLooks = 0
    /// The few pictures that are shown larger than their memory copy, in full (behind `lock`).
    private var sharp: [String: (image: CGImage, cost: Int, wanted: Date)] = [:]
    private var sharpLoading: Set<String> = []
    private var sharpTried: [String: Date] = [:]
    private var sharpTrimming = false

    /// The same iCloud container the boards use.
    private static let container = "iCloud.com.schabbauer.AMSSeedboard"

    /// iCloud is switched on for this device (never with the example boards).
    var cloudOn: Bool { !sample && FileManager.default.ubiquityIdentityToken != nil }

    let sample = LaunchOptions.sampleData

    private init() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] _ in
            self?.letSharpGo()
        }
        #endif
        guard !sample else { return }
        // The same places the boards use (BoardStore's iCloud container), found through the store's own folders.
        Task { @MainActor in
            let found: URL? = await AppModel.shared.store.kept { places in
                places.boards.dropFirst().first?.deletingLastPathComponent().appendingPathComponent("Pictures", isDirectory: true)
            } ?? nil
            if let found { try? FileManager.default.createDirectory(at: found, withIntermediateDirectories: true) }
            self.lock.lock(); self.cloudPictures = found; self.cloudAsked = Date(); self.lock.unlock()
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

    var cloud: URL? {
        lock.lock(); defer { lock.unlock() }
        return cloudPictures
    }

    /// iCloud's Pictures folder. While it is not known and iCloud is on (it was switched on after Seedboard
    /// started, or did not answer then), it is asked for again: 30 seconds apart at most, never on the main thread.
    /// Once it is found, everything laid meanwhile goes up.
    private func cloudNow() -> URL? {
        lock.lock()
        if let known = cloudPictures { lock.unlock(); return known }
        guard cloudOn, !Thread.isMainThread, Date().timeIntervalSince(cloudAsked) > 30 else { lock.unlock(); return nil }
        cloudAsked = Date()
        lock.unlock()
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: Self.container) else { return nil }
        let found = root.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent("Pictures", isDirectory: true)
        try? FileManager.default.createDirectory(at: found, withIntermediateDirectories: true)
        lock.lock(); cloudPictures = found; lock.unlock()
        DispatchQueue.main.async { self.arrived.send() }
        lookAtUploads()
        return found
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
        sendUp(name)
        if let copy = Self.picture(from: bytes, side: PictureKeeping.memorySide) { keep(copy, as: name) }
        return (name, CGSize(width: flat.width, height: flat.height))
    }

    /// A picture file that is new on this device goes into iCloud's folder and is watched until iCloud has taken
    /// it. A write that fails (iCloud is full, the folder is not known yet) is NOT forgotten: the file stays
    /// "not in iCloud yet" — the amber dot — and the watch writes it again.
    private func sendUp(_ name: String) {
        guard cloudOn else { return }
        if let cloud = cloudNow() { _ = putInCloud(name, in: cloud) }
        watchUpload([name])
    }

    /// Copies the device's file into iCloud's folder when it is not there (a picture file is written once and
    /// never changed). False when the write failed.
    private func putInCloud(_ name: String, in cloud: URL) -> Bool {
        let fm = FileManager.default
        let there = cloud.appendingPathComponent(name)
        if fm.fileExists(atPath: there.path) || fm.fileExists(atPath: cloud.appendingPathComponent(".\(name).icloud").path) { return true }
        guard let bytes = try? Data(contentsOf: local.appendingPathComponent(name)) else { return false }
        var ok = false
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: there, options: .forReplacing, error: &problem) { url in
            ok = (try? bytes.write(to: url, options: .atomic)) != nil
        }
        return ok && problem == nil
    }

    /// A picture from its file's bytes, unpacked here and now (never later on the main thread). `side`: the
    /// longest side wanted (the board's memory copy); nil: the whole picture.
    private static func picture(from data: Data, side: Int?) -> (image: CGImage, whole: Bool)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let side else {
            let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            return CGImageSourceCreateImageAtIndex(source, 0, options).map { ($0, true) }
        }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let long = max(props?[kCGImagePropertyPixelWidth] as? Int ?? 0, props?[kCGImagePropertyPixelHeight] as? Int ?? 0)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: long > 0 ? min(side, long) : side,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { ($0, long > 0 && long <= side) }
    }

    /// Into memory, counted by the bytes it really takes.
    private func keep(_ copy: (image: CGImage, whole: Bool), as name: String) {
        cache.setObject(Box(copy.image, whole: copy.whole), forKey: name as NSString, cost: copy.image.bytesPerRow * copy.image.height)
    }

    /// True when the bytes open as a picture.
    private static func opensAsPicture(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int else { return false }
        return w > 0 && h > 0
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
    /// redraw through `arrived` when it is there. What comes back is the board's memory copy (long side 1024).
    /// `shown`: how many screen pixels long the picture is drawn right now, when it is in view; a picture drawn
    /// clearly larger than its copy (zoomed in) is read in full as well, a few at a time.
    func image(_ name: String, shown: Double = 0) -> CGImage? {
        guard let box = cache.object(forKey: name as NSString) else {
            start(name)
            return nil
        }
        if !box.whole, PictureKeeping.wantsSharp(shown: shown, kept: max(box.image.width, box.image.height)),
           let full = sharpImage(name) { return full }
        return box.image
    }

    /// The picture now, read here and now if need be: for the pictures a board is exported or shared as, and the
    /// small pictures of the list. The memory copy (long side 1024).
    func imageNow(_ name: String) -> CGImage? {
        if let box = cache.object(forKey: name as NSString) { return box.image }
        guard let copy = read(name, side: PictureKeeping.memorySide) else {
            lock.lock(); missing.insert(name); lock.unlock()
            return nil
        }
        keep(copy, as: name)
        return copy.image
    }

    /// The memory copy if it is there; nothing is read.
    func imageInMemory(_ name: String) -> CGImage? { cache.object(forKey: name as NSString)?.image }

    /// The whole picture as its file holds it, read and unpacked NOW and not kept: for "Crop the picture" and for
    /// anything that needs every pixel. Call it off the main thread.
    func fullImage(_ name: String) -> CGImage? { read(name, side: nil)?.image }

    /// True when the file is not on this device yet and iCloud has been asked for it.
    func isComing(_ name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return coming.contains(name)
    }

    /// True when the file was looked for and is not on this device. False while it is only being read.
    func isMissing(_ name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return missing.contains(name)
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
            let found = read(name, side: PictureKeeping.memorySide)
            lock.lock()
            loading.remove(name)
            if found != nil { coming.remove(name); missing.remove(name); tries[name] = nil }
            lock.unlock()
            if let found {
                keep(found, as: name)
                DispatchQueue.main.async { self.arrived.send() }
            } else {
                let on = ask(name)
                lock.lock()
                let news = missing.insert(name).inserted
                if on { coming.insert(name) } else { coming.remove(name) }
                lock.unlock()
                // The plate now says so.
                if news { DispatchQueue.main.async { self.arrived.send() } }
                // Not here yet: look again in a few seconds, so a picture that arrives shows by itself.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { self.arrived.send() }
            }
        }
    }

    /// The whole picture for one that is shown larger than its memory copy; nil while it is being read, or while
    /// the room for such pictures (64 MB) is taken by others that are on screen right now.
    private func sharpImage(_ name: String) -> CGImage? {
        let now = Date()
        lock.lock()
        if var entry = sharp[name] {
            entry.wanted = now
            sharp[name] = entry
            lock.unlock()
            return entry.image
        }
        // The others that were asked for in the last two seconds are on screen: they are not pushed out
        // (that would make pictures flicker), this one stays as it is.
        let inUse = sharp.values.filter { now.timeIntervalSince($0.wanted) < 2 }.reduce(0) { $0 + $1.cost }
        let guess = PictureKeeping.memoryCost(width: Self.longestSide, height: Self.longestSide * 3 / 4)
        // 0.11: at most 12 full-size pictures open at once; while all 12 are on screen, the next keeps its small copy.
        let full = sharp.count + sharpLoading.count >= PictureKeeping.sharpMost
            && !sharp.values.contains { now.timeIntervalSince($0.wanted) >= 2 }
        if full || sharpLoading.contains(name) || inUse + guess * (sharpLoading.count + 1) > PictureKeeping.sharpRoom
            || (sharpTried[name].map { now.timeIntervalSince($0) < 10 } ?? false) {
            lock.unlock()
            return nil
        }
        sharpLoading.insert(name)
        sharpTried[name] = now
        lock.unlock()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let found = read(name, side: nil)?.image
            lock.lock()
            sharpLoading.remove(name)
            var show = false
            if let found {
                let cost = found.bytesPerRow * found.height
                if cost <= PictureKeeping.sharpRoom {
                    sharp[name] = (found, cost, Date())
                    sharpTried[name] = nil
                    show = true
                    // What was not asked for the longest goes until all fit; what nobody asked for in half a minute goes too.
                    for (other, entry) in sharp where other != name && Date().timeIntervalSince(entry.wanted) > 30 { sharp[other] = nil }
                    let keep = PictureKeeping.sharpToKeep(sharp.map { (name: $0.key, wanted: $0.value.wanted) })
                    for other in Array(sharp.keys) where other != name && !keep.contains(other) { sharp[other] = nil }
                    while sharp.values.reduce(0, { $0 + $1.cost }) > PictureKeeping.sharpRoom,
                          let oldest = sharp.filter({ $0.key != name }).min(by: { $0.value.wanted < $1.value.wanted }) {
                        sharp[oldest.key] = nil
                    }
                }
            }
            let trim = show && !sharpTrimming
            if trim { sharpTrimming = true }
            lock.unlock()
            if show { DispatchQueue.main.async { self.arrived.send() } }
            if trim { trimSharpLater() }
        }
        return nil
    }

    /// A full picture nobody asked for in half a minute (the board was zoomed out again, or closed) goes.
    private func trimSharpLater() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 35) { [self] in
            lock.lock()
            for (name, entry) in sharp where Date().timeIntervalSince(entry.wanted) > 30 { sharp[name] = nil }
            let more = !sharp.isEmpty
            if !more { sharpTrimming = false }
            lock.unlock()
            if more { trimSharpLater() }
        }
    }

    /// Memory is short: the full pictures go (the memory copies are let go by the system itself).
    func letSharpGo() {
        lock.lock(); sharp = [:]; lock.unlock()
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

    /// A picture file from an export comes back under its own name, byte for byte as it is. One that is already
    /// here — on the device, or in iCloud's folder — stays as it is: a picture file is written once and never
    /// changed (rule: `PictureFiles.adopt`). Call it off the main thread.
    func adopt(_ data: Data, named name: String) -> Bool {
        switch PictureFiles.adopt(data, named: name, device: local, cloud: cloud, isPicture: Self.opensAsPicture) {
        case .refused: return false
        case .here: return true
        case .written:
            sendUp(name)
            return true
        }
    }

    /// Asks iCloud for these files (the export could not pack them: they are not on this device yet).
    func askFor(_ names: [String]) {
        for name in names { ask(name) }
    }

    /// Reads the file from the device's folder, else from iCloud's when it has been downloaded, and unpacks it:
    /// as the board's memory copy (`side`), or whole (nil).
    private func read(_ name: String, side: Int?) -> (image: CGImage, whole: Bool)? {
        guard let data = fileBytes(name) else { return nil }
        return Self.picture(from: data, side: side)
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

    /// At the start (and when iCloud's folder is found later): every picture on this device is looked at. One that
    /// iCloud's folder does not hold at all (a write that failed) is put there again; one that is there but not
    /// sent yet is watched.
    private func lookAtUploads() {
        guard let cloud else { return }
        let local = self.local
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            var waiting: Set<String> = []
            for url in (try? fm.contentsOfDirectory(at: local, includingPropertiesForKeys: nil)) ?? [] {
                let name = url.lastPathComponent
                guard PictureKeeping.isPlainName(name), name.lowercased().hasSuffix(".jpg") else { continue }
                switch self.uploadState(name, in: cloud) {
                case .sent: break
                case .waiting: waiting.insert(name)
                case .missing:
                    _ = self.putInCloud(name, in: cloud)
                    waiting.insert(name)
                }
            }
            if !waiting.isEmpty { self.watchUpload(waiting) }
        }
    }

    /// How this picture stands with iCloud (rule: `PictureKeeping.upload`). A file that is not in iCloud's folder
    /// is never counted as sent.
    private func uploadState(_ name: String, in cloud: URL) -> PictureKeeping.Upload {
        let fm = FileManager.default
        let there = cloud.appendingPathComponent(name)
        let inFolder = fm.fileExists(atPath: there.path)
        let stub = fm.fileExists(atPath: cloud.appendingPathComponent(".\(name).icloud").path)
        let values = inFolder ? try? there.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey]) : nil
        return PictureKeeping.upload(cloudOn: cloudOn, inFolder: inFolder, stub: stub,
                                     known: values?.isUbiquitousItem, uploaded: values?.ubiquitousItemIsUploaded)
    }

    /// These files were just handed to iCloud: they count as "not in iCloud yet" until it has taken them.
    private func watchUpload(_ names: Set<String>) {
        lock.lock(); goingUp.formUnion(names); let now = goingUp; lock.unlock()
        DispatchQueue.main.async {
            AppModel.shared.picturesNotInCloud = now
            self.upLooks = 0
            guard self.upTimer == nil else { return }
            self.upTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.checkUploads() }
        }
    }

    /// Every 3 seconds for the first minute, then every 30: has iCloud taken them? A file that is not in iCloud's
    /// folder (the write failed, or the folder was not known) is written again.
    private func checkUploads() {
        upLooks += 1
        guard PictureKeeping.watchLooks(at: upLooks) else { return }
        lock.lock(); let waiting = goingUp; lock.unlock()
        let local = self.local
        DispatchQueue.global(qos: .utility).async {
            var done: Set<String> = []
            if !self.cloudOn {
                done = waiting   // iCloud was switched off: nothing waits for ever
            } else if let cloud = self.cloudNow() {
                for name in waiting {
                    switch self.uploadState(name, in: cloud) {
                    case .sent: done.insert(name)
                    case .waiting: break
                    case .missing:
                        // No such file on the device any more: nothing to send.
                        if !FileManager.default.fileExists(atPath: local.appendingPathComponent(name).path) { done.insert(name) } else { _ = self.putInCloud(name, in: cloud) }
                    }
                }
            }
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
            // No pass while a board still waits for its turn with iCloud (the pass works on the boards' iCloud
            // line, their saves would wait behind it). Looked at again every five minutes, for half an hour.
            for round in 0..<7 {
                if AppModel.shared.notInCloud.isEmpty { break }
                if round == 6 { return }
                try? await Task.sleep(nanoseconds: 300_000_000_000)
            }
            // Named by a board, or by a starter (a starter keeps a board of its own).
            var named = Set(AppModel.shared.boards.flatMap { $0.pictureNames })
            for entry in AppModel.shared.shelf.entries.values { named.formUnion(entry.board?.pictureNames ?? []) }
            let folders = [self.local] + [self.cloud].compactMap { $0 }
            _ = await AppModel.shared.store.kept { places in
                Self.tidy(pictures: folders, places: places, named: named)
            }
        }
    }

    /// When each picture file was first found unnamed (this device only): a file goes only when it was unnamed
    /// at two passes at least a week apart.
    private static let seenKey = "picturesUnnamedSince"

    private static func unnamedSince() -> [String: Date] {
        ((UserDefaults.standard.dictionary(forKey: seenKey) as? [String: Double]) ?? [:]).mapValues { Date(timeIntervalSince1970: $0) }
    }

    /// The pass itself. Returns how many files went.
    @discardableResult
    static func tidy(pictures folders: [URL], places: KeptPlaces, named inUse: Set<String>, now: Date = Date()) -> Int {
        let seen = unnamedSince()
        let (gone, next) = tidy(pictures: folders, places: places, named: inUse, seen: seen, now: now)
        if next != seen { UserDefaults.standard.set(next.mapValues(\.timeIntervalSince1970), forKey: seenKey) }
        return gone
    }

    /// The pass with what it remembers handed in and out (`seen`: when each file was first found unnamed).
    static func tidy(pictures folders: [URL], places: KeptPlaces, named inUse: Set<String>, seen: [String: Date],
                     now: Date = Date()) -> (gone: Int, seen: [String: Date]) {
        let fm = FileManager.default
        var candidates: [(name: String, date: Date?)] = []
        var complete = true
        for folder in folders {
            for url in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                let name = url.lastPathComponent
                // Still only in iCloud: do not guess. Any other hidden file (the Finder's own) says nothing.
                if PictureKeeping.stillInCloud(name) { complete = false; continue }
                if name.hasPrefix(".") { continue }
                candidates.append((name, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate))
            }
        }
        // First: is any file old enough and not named by a board that is shown? When none is, nothing is read.
        let old = Set(PictureKeeping.deletable(files: candidates, named: inUse, now: now))
        guard !old.isEmpty else { return (0, complete ? [:] : seen) }
        // Every file that can name a picture, read as plain bytes: boards, removed boards, safety copies, earlier versions.
        let (blobs, readAll) = keptBlobs(folders: folders, places: places)
        if !readAll { complete = false }
        var named = inUse
        // Only the files old enough are looked for in the copies.
        for file in candidates where old.contains(file.name) {
            guard let key = file.name.data(using: .utf8) else { continue }
            if blobs.contains(where: { $0.range(of: key) != nil }) { named.insert(file.name) }
        }
        // A file goes only when it was unnamed at two passes at least a week apart.
        let pass = PictureKeeping.tidy(files: candidates, named: named, seen: seen, now: now, complete: complete)
        let go = Set(pass.go)
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
        return (gone, pass.seen)
    }

    /// Every file that can name a picture, read as plain bytes: boards, removed boards, safety copies, earlier
    /// versions and the starters beside each Pictures folder. `complete` is false when anything could not be read
    /// (then nothing may be decided from the bytes).
    static func keptBlobs(folders: [URL], places: KeptPlaces) -> (blobs: [Data], complete: Bool) {
        let fm = FileManager.default
        var complete = true
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
        return (blobs, complete)
    }
}
