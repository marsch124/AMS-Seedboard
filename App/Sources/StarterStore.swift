import Foundation
import SeedboardCore

/// Where the starters live: one small file per starter that was ever changed or made,
/// `Starters/<id>.seedstarter`, beside `Boards` — on this device (Application Support) and in iCloud
/// Documents. A removal keeps its file (`removed: true`), so it reaches every device; a removed own
/// starter's file goes 30 days later. For the same id the newer `changed` wins (0.5: the board by its own stamp).
/// 0.5 (data safety): the boards' rules for iCloud — a file that has not arrived is never written over, a parked
/// version or an "… 2" copy is cleared only once it was read and joined, a replaced version with another board is
/// kept in SafetyCopies — and a working copy `<id>.working` (this device only) while a starter is being changed.
/// Sample mode (`-sampleData`) and unit tests never touch a file: the shelf lives in memory.
final class StarterStore: @unchecked Sendable {
    /// The same iCloud container the boards use (`BoardDisk.container`, which is private to BoardStore.swift).
    private static let container = "iCloud.com.schabbauer.AMSSeedboard"
    private static let ending = StarterFileName.ending

    private let sample: Bool
    /// 0.5: two lines of work, as the boards have. The device's files never wait behind iCloud, and leaving
    /// the app waits for the device line only (two seconds at most).
    private let lines = StoreLines(label: "com.schabbauer.AMSSeedboard.starters")
    /// Sample mode only (on the device line).
    private var memory: [String: StarterEntry]
    // Only on the iCloud line:
    private var cloudRoot: URL?
    private var cloudAsked = Date.distantPast
    /// The version of each starter this device last read or wrote: a version in iCloud that is NOT this one
    /// was written by another device and is kept aside before it is written over.
    private var seen: [String: StarterEntry] = [:]

    init(sample: Bool) {
        self.sample = sample || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        memory = self.sample ? Dictionary(uniqueKeysWithValues: StarterSample.entries().map { ($0.id, $0) }) : [:]
    }

    // MARK: Public

    /// Everything stored, the newest copy of each starter. Also brings the device and iCloud level with each other.
    func loadAll(now: Date = Date()) async -> [StarterEntry] {
        await withCheckedContinuation { go in
            if sample {
                lines.device.async { go.resume(returning: Array(self.memory.values)) }
            } else {
                lines.inCloud { go.resume(returning: self.read(now: now)) }
            }
        }
    }

    /// The device's file at once, on its own line; iCloud's follows on the other.
    func write(_ entry: StarterEntry) {
        lines.onDevice { self.putDevice(entry) }
        if !sample { lines.inCloud { self.putCloud(entry) } }
    }

    /// Waits until everything handed to `write` is on the device (when the app is left): two seconds at most,
    /// and not at all when nothing was written since the last time.
    func flush() { lines.flush() }

    // MARK: A starter that is being changed (its working copy, this device only)

    func keepWorking(_ work: StarterWorking) {
        guard !sample else { return }
        lines.onDevice { work.write(in: self.local) }
    }

    func clearWorking() {
        guard !sample else { return }
        lines.onDevice { StarterWorking.clear(in: self.local) }
    }

    /// The working copy that was left behind when the app was stopped; nil when there is none.
    func waitingWork() async -> StarterWorking? {
        guard !sample else { return nil }
        return await withCheckedContinuation { go in
            lines.device.async { go.resume(returning: StarterWorking.waiting(in: self.local)) }
        }
    }

    // MARK: Work

    /// On the device line.
    private func putDevice(_ entry: StarterEntry) {
        if sample { memory[entry.id] = entry; return }
        guard let bytes = encode(entry) else { return }
        try? bytes.write(to: local.appendingPathComponent(file(entry.id)), options: .atomic)
    }

    /// On the iCloud line. iCloud's file is read first: one that has not arrived or cannot be read is never
    /// written over, and what another device wrote meanwhile is joined in (the newer name and place, the newer
    /// board), its own bytes kept aside when its board differs.
    private func putCloud(_ entry: StarterEntry) {
        guard let folder = cloudFolder(), let mine = encode(entry).flatMap({ decode($0) }) else { return }
        let target = folder.appendingPathComponent(file(entry.id))
        if exists(folder.appendingPathComponent(".\(file(entry.id)).icloud")) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: target)
            return
        }
        var there: StarterEntry?
        var thereBytes: Data?
        if exists(target) {
            thereBytes = cloudData(target)
            guard let found = decode(thereBytes) else { return }
            there = found
        }
        let out = there.map { StarterEntry.newer($0, mine) } ?? mine
        guard out != there, let bytes = encode(out) else {
            seen[entry.id] = out
            return
        }
        if let there, there != seen[entry.id], StarterKept.keepAside(stored: there, new: out), let thereBytes {
            setAside(thereBytes, id: entry.id)
        }
        if writeCloud(bytes, to: target) { seen[entry.id] = out }
    }

    /// One of iCloud's files that was read and is not the starter's own: a copy iCloud made ("<id> 2.seedstarter")
    /// or a version it parked.
    private struct Extra {
        var entry: StarterEntry
        var bytes: Data
        var copy: URL?
        var parked: NSFileVersion?
    }

    /// On the iCloud line.
    private func read(now: Date) -> [StarterEntry] {
        var device: [String: StarterEntry] = [:]
        var deviceBytes: [String: Data] = [:]
        lines.device.sync {
            for url in files(in: local) where url.pathExtension == Self.ending {
                guard let data = try? Data(contentsOf: url), let e = decode(data) else { continue }
                device[e.id] = e
                deviceBytes[e.id] = data
            }
        }
        var cloudMain: [String: StarterEntry] = [:]
        var cloudBytes: [String: Data] = [:]
        var extras: [Extra] = []
        // Starters of which something in iCloud could not be read: nothing of theirs is written to iCloud.
        var held = Set<String>()
        let folder = cloudFolder()
        if let folder {
            for url in files(in: folder) {
                guard let name = StarterFileName(url.lastPathComponent) else { continue }
                let real = folder.appendingPathComponent(name.name)
                // A file still on its way from iCloud is shown as ".name.seedstarter.icloud": ask for it, and
                // never write over it (0.5; the boards' rule).
                if name.waiting {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: real)
                    held.insert(name.id)
                    continue
                }
                var data: Data?
                var problem: NSError?
                NSFileCoordinator().coordinate(readingItemAt: real, options: [], error: &problem) { place in
                    data = try? Data(contentsOf: place)
                    // What iCloud parked when two devices wrote at the same moment. A version that cannot be
                    // read stays where it is for the next look.
                    for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: place) ?? [] {
                        if let bytes = try? Data(contentsOf: version.url), let other = self.decode(bytes) {
                            extras.append(Extra(entry: other, bytes: bytes, parked: version))
                        } else {
                            held.insert(name.id)
                        }
                    }
                }
                guard let data, let found = decode(data) else {
                    held.insert(name.id)
                    continue
                }
                if name.copy == nil {
                    cloudMain[found.id] = found
                    cloudBytes[found.id] = data
                } else {
                    extras.append(Extra(entry: found, bytes: data, copy: real))
                }
            }
        }
        let plan = StarterLevelling.plan(device: device, cloudMain: cloudMain, cloudOthers: extras.map(\.entry),
                                         held: held, cloudOn: folder != nil)
        var best = plan.best
        // The two places are made level. A version that is replaced by one with another board is kept aside first.
        lines.device.sync {
            for id in plan.toDevice {
                guard let entry = best[id], let bytes = encode(entry) else { continue }
                let target = local.appendingPathComponent(file(id))
                // A change was saved here while iCloud was being read: the device's file stays, the next look levels it.
                guard (try? Data(contentsOf: target)) == deviceBytes[id] else { continue }
                if StarterKept.keepAside(stored: device[id], new: entry), let old = deviceBytes[id] { setAside(old, id: id) }
                try? bytes.write(to: target, options: .atomic)
            }
        }
        if let folder {
            // The starters whose own iCloud file holds the best version now.
            var settled = Set<String>()
            for (id, entry) in best where !held.contains(id) {
                if plan.toCloud.contains(id) {
                    guard let bytes = encode(entry) else { continue }
                    if let old = cloudMain[id], old != seen[id], StarterKept.keepAside(stored: old, new: entry), let oldBytes = cloudBytes[id] {
                        setAside(oldBytes, id: id)
                    }
                    guard writeCloud(bytes, to: folder.appendingPathComponent(file(id))) else { continue }
                }
                settled.insert(id)
                seen[id] = entry
            }
            // iCloud's own copies and parked versions go only once their content is in the starter's own file
            // (or, when it lost with another board, in SafetyCopies).
            for extra in extras where settled.contains(extra.entry.id) {
                if let entry = best[extra.entry.id], StarterKept.keepAside(stored: extra.entry, new: entry) { setAside(extra.bytes, id: extra.entry.id) }
                if let copy = extra.copy { removeCloud(copy) }
                if let version = extra.parked {
                    version.isResolved = true
                    try? version.remove()
                }
            }
        }
        // A removed own starter's file goes after 30 days.
        for id in StarterShelf(entries: Array(best.values)).purgeable(now: now) where !held.contains(id) {
            lines.device.sync { try? FileManager.default.removeItem(at: local.appendingPathComponent(file(id))) }
            if let folder { removeCloud(folder.appendingPathComponent(file(id))) }
            best[id] = nil
            seen[id] = nil
        }
        return Array(best.values)
    }

    /// Keeps these bytes in SafetyCopies as `starter-<id>-<time>-<6 letters>.seedstarter` (30 days; the same
    /// tidy as the boards' set-aside versions). The same bytes are not kept twice.
    private func setAside(_ bytes: Data, id: String) {
        let fm = FileManager.default
        let safety = support.appendingPathComponent("SafetyCopies", isDirectory: true)
        try? fm.createDirectory(at: safety, withIntermediateDirectories: true)
        for url in files(in: safety) where url.lastPathComponent.hasPrefix("starter-\(id)-") {
            if (try? Data(contentsOf: url)) == bytes { return }
        }
        try? bytes.write(to: safety.appendingPathComponent(StarterKept.name(id: id, at: Date())), options: .atomic)
    }

    // MARK: Places

    private func file(_ id: String) -> String { "\(id).\(Self.ending)" }

    private var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var local: URL {
        let url = support.appendingPathComponent("Starters", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Only on the iCloud line.
    private func cloudFolder() -> URL? {
        guard FileManager.default.ubiquityIdentityToken != nil else { return nil }
        if cloudRoot == nil, Date().timeIntervalSince(cloudAsked) > 30 {
            cloudAsked = Date()
            cloudRoot = FileManager.default.url(forUbiquityContainerIdentifier: Self.container)?.appendingPathComponent("Documents", isDirectory: true)
        }
        guard let root = cloudRoot else { return nil }
        let url = root.appendingPathComponent("Starters", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func files(in folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    }

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    private func cloudData(_ file: URL) -> Data? {
        var data: Data?
        var problem: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { data = try? Data(contentsOf: $0) }
        return data
    }

    /// False when the write failed.
    @discardableResult
    private func writeCloud(_ bytes: Data, to file: URL) -> Bool {
        var ok = false
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &problem) { url in
            ok = (try? bytes.write(to: url, options: .atomic)) != nil
        }
        return ok && problem == nil
    }

    private func removeCloud(_ file: URL) {
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forDeleting, error: &problem) { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: Coding (times to the thousandth of a second, as the boards do)

    private static let fine: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    private func encode(_ entry: StarterEntry) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var box = encoder.singleValueContainer()
            try box.encode(Self.fine.string(from: date))
        }
        return try? encoder.encode(entry)
    }

    private func decode(_ data: Data?) -> StarterEntry? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.fine.date(from: text) ?? Self.plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not a date"))
        }
        return try? decoder.decode(StarterEntry.self, from: data)
    }
}

/// The two own starters of sample mode (`-sampleData`), made in code.
enum StarterSample {
    static let weekly = "00000000-0000-0000-0000-0000000000A1"
    static let trip = "00000000-0000-0000-0000-0000000000A2"

    static func entries() -> [StarterEntry] {
        let now = Date()
        var review = Starter.prosCons.board(title: "Friday look-back", now: now)
        var frames = ["Went well", "Needs work"], notes = ["Shipped the plan", "Quiet mornings", "Too many meetings", "Late lunches"]
        for i in review.items.indices {
            switch review.items[i].kind {
            case .text: review.items[i].text = "How was the week?"
            case .frame where !frames.isEmpty: review.items[i].text = frames.removeFirst()
            case .note where !notes.isEmpty: review.items[i].text = notes.removeFirst()
            default: break
            }
        }
        var plan = Board.timelineStart(title: "Trip plan", now: now)
        let names = ["Book", "Pack", "Travel", "Arrive"]
        for (i, id) in plan.timelineRows.map(\.id).enumerated() where i < names.count {
            if let n = plan.index(of: id) { plan.items[n].text = names[i] }
        }
        return [
            StarterEntry(id: weekly, name: "Friday look-back", hint: "What went well, what did not", order: 10, board: review, changed: now),
            StarterEntry(id: trip, name: "Trip plan", hint: "Book, pack, travel, arrive", order: 11, board: plan, changed: now),
        ]
    }
}
