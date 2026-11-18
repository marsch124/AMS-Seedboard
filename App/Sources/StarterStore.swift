import Foundation
import SeedboardCore

/// Where the starters live: one small file per starter that was ever changed or made,
/// `Starters/<id>.seedstarter`, beside `Boards` — on this device (Application Support) and in iCloud
/// Documents. A removal keeps its file (`removed: true`), so it reaches every device; a removed own
/// starter's file goes 30 days later. For the same id the newer `changed` wins.
/// Sample mode (`-sampleData`) and unit tests never touch a file: the shelf lives in memory.
final class StarterStore: @unchecked Sendable {
    /// The same iCloud container the boards use (`BoardDisk.container`, which is private to BoardStore.swift).
    private static let container = "iCloud.com.schabbauer.AMSSeedboard"
    private static let ending = "seedstarter"

    private let sample: Bool
    private let queue = DispatchQueue(label: "com.schabbauer.AMSSeedboard.starters")
    /// Sample mode only.
    private var memory: [String: StarterEntry]
    private var cloudRoot: URL?
    private var cloudAsked = Date.distantPast

    init(sample: Bool) {
        self.sample = sample || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        memory = self.sample ? Dictionary(uniqueKeysWithValues: StarterSample.entries().map { ($0.id, $0) }) : [:]
    }

    // MARK: Public

    /// Everything stored, the newest copy of each starter. Also brings the device and iCloud level with each other.
    func loadAll(now: Date = Date()) async -> [StarterEntry] {
        await withCheckedContinuation { go in
            queue.async { go.resume(returning: self.read(now: now)) }
        }
    }

    func write(_ entry: StarterEntry) {
        queue.async { self.put(entry) }
    }

    /// Waits until everything handed to `write` is on the device (when the app closes).
    func flush() { queue.sync {} }

    // MARK: Work (on the queue)

    private func put(_ entry: StarterEntry) {
        if sample { memory[entry.id] = entry; return }
        guard let bytes = encode(entry) else { return }
        try? bytes.write(to: local.appendingPathComponent(file(entry.id)), options: .atomic)
        if let cloud = cloudFolder() { writeCloud(bytes, to: cloud.appendingPathComponent(file(entry.id))) }
    }

    private func read(now: Date) -> [StarterEntry] {
        if sample { return Array(memory.values) }
        var best: [String: StarterEntry] = [:]
        var onDevice: [String: StarterEntry] = [:]
        var inCloud: [String: StarterEntry] = [:]
        for url in files(in: local) {
            if let e = decode(try? Data(contentsOf: url)) { onDevice[e.id] = e }
        }
        if let folder = cloudFolder() {
            for url in files(in: folder) {
                // A file still on its way from iCloud is shown as ".name.seedstarter.icloud": ask for it.
                let name = url.lastPathComponent
                if name.hasPrefix("."), name.hasSuffix(".icloud") {
                    let real = String(name.dropFirst().dropLast(".icloud".count))
                    try? FileManager.default.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(real))
                    continue
                }
                guard url.pathExtension == Self.ending else { continue }
                var found: StarterEntry?
                var problem: NSError?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &problem) { place in
                    found = self.decode(try? Data(contentsOf: place))
                    // What iCloud parked when two devices wrote at the same moment: the newer copy wins.
                    for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: place) ?? [] {
                        if let other = self.decode(try? Data(contentsOf: version.url)) {
                            found = found.map { StarterEntry.newer($0, other) } ?? other
                        }
                        version.isResolved = true
                        try? version.remove()
                    }
                }
                if let found { inCloud[found.id] = found }
            }
        }
        for id in Set(onDevice.keys).union(inCloud.keys) {
            switch (onDevice[id], inCloud[id]) {
            case let (a?, b?): best[id] = StarterEntry.newer(a, b)
            case let (a?, nil): best[id] = a
            case let (nil, b?): best[id] = b
            default: break
            }
        }
        // The two places are made level.
        for (id, entry) in best {
            if onDevice[id] != entry, let bytes = encode(entry) {
                try? bytes.write(to: local.appendingPathComponent(file(id)), options: .atomic)
            }
            if let folder = cloudFolder(), inCloud[id] != entry, let bytes = encode(entry) {
                writeCloud(bytes, to: folder.appendingPathComponent(file(id)))
            }
        }
        // A removed own starter's file goes after 30 days.
        for id in StarterShelf(entries: Array(best.values)).purgeable(now: now) {
            try? FileManager.default.removeItem(at: local.appendingPathComponent(file(id)))
            if let folder = cloudFolder() {
                let url = folder.appendingPathComponent(file(id))
                var problem: NSError?
                NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &problem) { try? FileManager.default.removeItem(at: $0) }
            }
            best[id] = nil
        }
        return Array(best.values)
    }

    // MARK: Places

    private func file(_ id: String) -> String { "\(id).\(Self.ending)" }

    private var local: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = support.appendingPathComponent("Starters", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

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

    private func writeCloud(_ bytes: Data, to file: URL) {
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &problem) { url in
            try? bytes.write(to: url, options: .atomic)
        }
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
        var review = Starter.prosCons.board(title: "Weekly review", now: now)
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
            StarterEntry(id: weekly, name: "Weekly review", hint: "What went well, what did not", order: 7, board: review, changed: now),
            StarterEntry(id: trip, name: "Trip plan", hint: "Book, pack, travel, arrive", order: 8, board: plan, changed: now),
        ]
    }
}
