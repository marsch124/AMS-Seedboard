import Foundation

// 0.5, data safety for pictures (panel findings 5, 8, 10 and 11). Plain rules; the files are `PictureStore`'s.

public extension PictureKeeping {
    // MARK: Is a picture in iCloud? (finding 5)

    enum Upload: Equatable, Sendable {
        /// iCloud has it (or iCloud is off: nothing waits for ever).
        case sent
        /// It lies in iCloud's folder and iCloud has not taken it yet.
        case waiting
        /// iCloud is on and its folder does not hold the file at all: the write failed. It is written again.
        case missing
    }

    /// How a picture file of this device stands with iCloud.
    /// - `cloudOn`: iCloud is switched on for this device.
    /// - `inFolder`: the file lies in iCloud's Pictures folder. `stub`: only its place holder does (iCloud has
    ///   the file and this device let its own copy go).
    /// - `known`: iCloud says the file is one of its own (nil: it could not be asked).
    /// - `uploaded`: iCloud says it has taken it.
    /// A file that is NOT in iCloud's folder is never counted as sent.
    static func upload(cloudOn: Bool, inFolder: Bool, stub: Bool = false, known: Bool?, uploaded: Bool?) -> Upload {
        guard cloudOn else { return .sent }
        if stub { return .sent }
        guard inFolder else { return .missing }
        guard let known else { return .waiting }
        guard known else { return .sent }
        return uploaded == true ? .sent : .waiting
    }

    /// The watch looks every 3 seconds for the first minute, then every 30 seconds (as the boards' watch does).
    /// `look`: 1 for the first look.
    static func watchLooks(at look: Int) -> Bool {
        look <= 20 || look % 10 == 0
    }

    // MARK: Pictures in memory (finding 8)

    /// The longest side of the copy a board keeps in memory, in pixels. The file itself keeps its 2048.
    static let memorySide = 1024
    /// The room all those copies may take together: 160 MB.
    static let memoryRoom = 160 * 1024 * 1024
    /// The room for the few pictures that are shown larger than their memory copy (zoomed in): 64 MB.
    static let sharpRoom = 64 * 1024 * 1024

    /// The size of the copy kept in memory for a picture of these pixels: its shape kept, the long side at most
    /// 1024, never made larger.
    static func memorySize(width: Int, height: Int) -> (width: Int, height: Int) {
        let long = max(width, height)
        guard long > memorySide, long > 0 else { return (max(width, 0), max(height, 0)) }
        let k = Double(memorySide) / Double(long)
        return (max(1, Int((Double(width) * k).rounded())), max(1, Int((Double(height) * k).rounded())))
    }

    /// What a picture of these pixels costs in memory: four bytes a pixel.
    static func memoryCost(width: Int, height: Int) -> Int { max(width, 0) * max(height, 0) * 4 }

    /// A picture is shown this many screen pixels long; its memory copy is `kept` pixels long. The file is read
    /// in full only when it is shown clearly larger than the copy (and the file has more to give).
    static func wantsSharp(shown: Double, kept: Int) -> Bool {
        kept >= memorySide && shown > Double(kept) * 1.2
    }

    // MARK: Letting a picture go (finding 11)

    /// A picture goes only when it was found unnamed at two passes at least this many days apart.
    static let unnamedDays: Double = 7

    /// Only a place holder of iCloud (".<name>.icloud") means "a file is still in iCloud only". Any other hidden
    /// file (the Finder's ".DS_Store") says nothing and is ignored.
    static func stillInCloud(_ fileName: String) -> Bool {
        fileName.hasPrefix(".") && fileName.hasSuffix(".icloud")
    }

    /// One tidy pass. `seen`: when each file was FIRST found unnamed (kept on the device between passes).
    /// Gives back the files that go now — unnamed, older than 30 days, and first found unnamed at least 7 days
    /// ago — and the list to remember. A file that is named again, or gone, is forgotten. A pass that is not
    /// `complete` (something could not be read) lets nothing go and remembers nothing new.
    static func tidy(files: [(name: String, date: Date?)], named: Set<String>, seen: [String: Date],
                     now: Date = Date(), complete: Bool = true) -> (go: [String], seen: [String: Date]) {
        guard complete else { return ([], seen) }
        var next: [String: Date] = [:]
        var go: [String] = []
        for name in deletable(files: files, named: named, now: now) {
            let first = min(seen[name] ?? now, now)
            next[name] = first
            if now.timeIntervalSince(first) >= unnamedDays * 86_400 { go.append(name) }
        }
        return (go, next)
    }
}

/// A picture file that comes back from an export (finding 10).
public enum PictureFiles {
    public enum Adopted: Equatable, Sendable {
        /// It is here already — on the device, or in iCloud's folder as a file or a place holder: nothing is written.
        case here
        /// It was written onto the device, byte for byte as it came.
        case written
        /// Not a plain `.jpg` name, not a picture, or it could not be written.
        case refused
    }

    /// Takes a picture file back under its own name. A picture file is written ONCE and never changed: one that
    /// is here already stays as it is, and a new one keeps its bytes exactly (it is not unpacked and saved again).
    /// `cloud`: iCloud's Pictures folder when there is one. `isPicture`: do the bytes open as a picture?
    public static func adopt(_ data: Data, named name: String, device: URL, cloud: URL?, isPicture: (Data) -> Bool) -> Adopted {
        guard PictureKeeping.isPlainName(name), name.lowercased().hasSuffix(".jpg") else { return .refused }
        let fm = FileManager.default
        if fm.fileExists(atPath: device.appendingPathComponent(name).path) { return .here }
        if let cloud, fm.fileExists(atPath: cloud.appendingPathComponent(name).path)
            || fm.fileExists(atPath: cloud.appendingPathComponent(".\(name).icloud").path) { return .here }
        guard isPicture(data) else { return .refused }
        try? fm.createDirectory(at: device, withIntermediateDirectories: true)
        return (try? data.write(to: device.appendingPathComponent(name), options: .atomic)) != nil ? .written : .refused
    }
}
