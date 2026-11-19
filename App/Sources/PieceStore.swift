import Foundation
import SeedboardCore

// 0.14 (idea 27): where the saved pieces live — one small file per piece, `Pieces/<id>.seedpiece`, beside
// `Starters` and `Boards`: on this device (Application Support) and in iCloud Documents, as the starters are.
// For the same id the newer `changed` wins; a removed piece keeps its file (`removed: true`) so it reaches every
// device, and goes 30 days later. A file in iCloud that has not arrived or cannot be read is never written over.
// Sample mode and unit tests never touch a file: the shelf lives in memory.
final class PieceStore: @unchecked Sendable {
    private static let container = "iCloud.com.schabbauer.AMSSeedboard"
    private let sample: Bool
    private let lines = StoreLines(label: "com.schabbauer.AMSSeedboard.pieces")
    private var memory: [String: PieceEntry] = [:]
    private var cloudRoot: URL?
    private var cloudAsked = Date.distantPast

    init(sample: Bool) {
        self.sample = sample || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: Public

    /// Everything stored, the newest copy of each piece; the device and iCloud are brought level.
    func loadAll(now: Date = Date()) async -> [PieceEntry] {
        await withCheckedContinuation { go in
            if sample {
                lines.device.async { go.resume(returning: Array(self.memory.values)) }
            } else {
                lines.inCloud { go.resume(returning: self.read(now: now)) }
            }
        }
    }

    func write(_ entry: PieceEntry) {
        lines.onDevice { self.putDevice(entry) }
        if !sample { lines.inCloud { self.putCloud(entry) } }
    }

    func flush() { lines.flush() }

    // MARK: Work

    private func putDevice(_ entry: PieceEntry) {
        if sample { memory[entry.id] = entry; return }
        guard let bytes = encode(entry) else { return }
        try? bytes.write(to: local.appendingPathComponent(file(entry.id)), options: .atomic)
    }

    private func putCloud(_ entry: PieceEntry) {
        guard let folder = cloudFolder() else { return }
        let target = folder.appendingPathComponent(file(entry.id))
        if exists(folder.appendingPathComponent(".\(file(entry.id)).icloud")) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: target)
            return
        }
        var out = entry
        if exists(target) {
            // One that cannot be read is never written over.
            guard let found = decode(cloudData(target)) else { return }
            out = PieceEntry.newer(found, entry)
            if out == found { return }
        }
        if let bytes = encode(out) { writeCloud(bytes, to: target) }
    }

    /// On the iCloud line.
    private func read(now: Date) -> [PieceEntry] {
        var best: [String: PieceEntry] = [:]
        var deviceHas: [String: PieceEntry] = [:]
        var cloudHas: [String: PieceEntry] = [:]
        var held = Set<String>()
        func take(_ e: PieceEntry) { best[e.id] = best[e.id].map { PieceEntry.newer($0, e) } ?? e }
        lines.device.sync {
            for url in files(in: local) {
                guard PieceFileName.id(of: url.lastPathComponent) != nil,
                      let e = decode(try? Data(contentsOf: url)) else { continue }
                deviceHas[e.id] = e
                take(e)
            }
        }
        let folder = cloudFolder()
        if let folder {
            for url in files(in: folder) {
                var name = url.lastPathComponent
                if name.hasPrefix("."), name.hasSuffix(".icloud") {
                    name = String(name.dropFirst().dropLast(".icloud".count))
                    if let id = PieceFileName.id(of: name) {
                        try? FileManager.default.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(name))
                        held.insert(id)
                    }
                    continue
                }
                guard let id = PieceFileName.id(of: name) else { continue }
                guard let e = decode(cloudData(url)) else { held.insert(id); continue }
                cloudHas[id] = e
                take(e)
            }
        }
        // Level: the device and iCloud both hold the best copy (iCloud's only where it could be read).
        for (id, e) in best {
            if deviceHas[id] != e { lines.device.sync { putDevice(e) } }
            if let folder, !held.contains(id), cloudHas[id] != e, let bytes = encode(e) {
                writeCloud(bytes, to: folder.appendingPathComponent(file(id)))
            }
        }
        // A piece removed more than 30 days ago: its files go.
        for id in PieceShelf(entries: Array(best.values)).purgeable(now: now) where !held.contains(id) {
            lines.device.sync { try? FileManager.default.removeItem(at: local.appendingPathComponent(file(id))) }
            if let folder { removeCloud(folder.appendingPathComponent(file(id))) }
            best[id] = nil
        }
        return Array(best.values)
    }

    // MARK: Places

    private func file(_ id: String) -> String { "\(id).\(PieceShelf.ending)" }

    private var local: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = support.appendingPathComponent("Pieces", isDirectory: true)
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
        let url = root.appendingPathComponent("Pieces", isDirectory: true)
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

    // MARK: Coding (times to the thousandth of a second, as the starters do)

    private static let fine: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    private func encode(_ entry: PieceEntry) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var box = encoder.singleValueContainer()
            try box.encode(Self.fine.string(from: date))
        }
        return try? encoder.encode(entry)
    }

    private func decode(_ data: Data?) -> PieceEntry? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.fine.date(from: text) ?? Self.plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not a date"))
        }
        return try? decoder.decode(PieceEntry.self, from: data)
    }
}
