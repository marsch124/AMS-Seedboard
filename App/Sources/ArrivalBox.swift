import Foundation
import Security
import SeedboardCore

// 0.5, pick 24: Share › Seedboard. This file is built into the app AND into the share page (the target
// AMSSeedboardShare), so both speak of the same place.
//
// The box is where shared things wait until the app lays them on their board. It has two homes:
//  1. A folder both can reach: PARAGON's shared folder (the app group), in its own corner `Seedboard/arrivals/`.
//     Words, links and pictures. Used whenever the system hands the folder out.
//  2. Otherwise the device's keychain, in a group both can reach. Words and links only: a keychain is no place
//     for pictures.
// The share page writes into the first home it can reach. The app empties EVERY home it can reach, so it does
// not matter which one the page found.

struct ArrivalBox: Sendable {
    enum Home: Equatable, Sendable {
        case folder(URL)
        case keychain
    }

    let home: Home

    // PARAGON's shared folder; the Mac spells it with the Team ID in front.
    #if os(macOS)
    static let group = "D24ENP83QQ.group.com.schabbauer.amspara"
    #else
    static let group = "group.com.schabbauer.amspara"
    #endif
    /// The keychain group: the app's own identity, so the app needs no extra permission for it.
    static let keychainGroup = "D24ENP83QQ.com.schabbauer.AMSSeedboard"
    private static let service = "com.schabbauer.AMSSeedboard.arrivals"
    private static let listName = "arrivals.jsonl"
    private static let boardsName = "boards.json"

    /// A box in a folder of one's own choosing (trying things out; tests).
    init(folder: URL) { home = .folder(folder) }
    private init(home: Home) { self.home = home }

    /// Pictures can wait here.
    var takesPictures: Bool {
        if case .folder = home { return true }
        return false
    }

    // MARK: Finding the homes

    /// The shared folder, when the system hands it out and it can be written.
    static var sharedFolder: ArrivalBox? {
        #if os(macOS)
        // Only the real, sandboxed app and share page. A Mac program that is not sandboxed (a builder's trial
        // build) would be handed PARAGON's real folder: it never gets a box there.
        guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil else { return nil }
        #endif
        let fm = FileManager.default
        guard let root = fm.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        let folder = root.appendingPathComponent("Seedboard", isDirectory: true).appendingPathComponent("arrivals", isDirectory: true)
        guard (try? fm.createDirectory(at: folder, withIntermediateDirectories: true)) != nil,
              fm.isWritableFile(atPath: folder.path) else { return nil }
        return ArrivalBox(folder: folder)
    }

    /// The keychain home, when this program may use the group.
    static var keychain: ArrivalBox? {
        let status = keychainRead(boardsName).status
        return status == errSecSuccess || status == errSecItemNotFound ? ArrivalBox(home: .keychain) : nil
    }

    /// Every home this program can reach (the app empties them all).
    static func homes() -> [ArrivalBox] { [sharedFolder, keychain].compactMap { $0 } }

    /// The home the share page writes into: the folder when it is there, else the keychain; nil when neither answers.
    static func forSharing() -> ArrivalBox? { sharedFolder ?? keychain }

    // MARK: The waiting list

    /// Everything that waits, in the order it came.
    func waiting() -> [Arrival] { ArrivalList.read(readText(ArrivalBox.listName)) }

    /// Adds arrivals at the end of the list. False when they could not be kept.
    func add(_ arrivals: [Arrival]) -> Bool {
        guard !arrivals.isEmpty else { return true }
        return change(ArrivalBox.listName) { ArrivalList.adding(arrivals, to: $0) }
    }

    /// Takes these arrivals off the list, and their pictures out of the waiting folder. Called by the app only
    /// AFTER the board they were laid on was saved.
    func remove(_ arrivals: [Arrival]) {
        guard !arrivals.isEmpty else { return }
        let ids = Set(arrivals.map(\.id))
        guard change(ArrivalBox.listName, { ArrivalList.text($0, without: ids) }) else { return }
        for name in arrivals.compactMap(\.picture) {
            if let file = pictureFile(name) { try? FileManager.default.removeItem(at: file) }
        }
    }

    // MARK: The boards the share page offers

    func boards() -> [ShareBoard] {
        guard let data = readData(ArrivalBox.boardsName) else { return [] }
        return ShareBoards.read(data)
    }

    @discardableResult
    func keep(boards list: [ShareBoard]) -> Bool { write(ShareBoards.data(of: list), ArrivalBox.boardsName) }

    // MARK: Pictures (the folder home only)

    private var pictures: URL? {
        guard case .folder(let folder) = home else { return nil }
        let pictures = folder.appendingPathComponent("pictures", isDirectory: true)
        try? FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
        return pictures
    }

    /// Where a waiting picture of this name lies, or is to be written. nil in the keychain home, and for a name
    /// that is not a plain file name.
    func pictureFile(_ name: String) -> URL? {
        guard PictureKeeping.isPlainName(name) else { return nil }
        return pictures?.appendingPathComponent(name)
    }

    func pictureBytes(_ name: String) -> Data? {
        guard let file = pictureFile(name) else { return nil }
        return try? Data(contentsOf: file)
    }

    /// Takes away waiting pictures that no line names and that are older than a day (a share that was begun and
    /// never sent or cancelled, because the page was closed by the system).
    func sweep(now: Date = Date()) {
        guard let pictures else { return }
        let fm = FileManager.default
        let named = Set(waiting().compactMap(\.picture))
        for file in (try? fm.contentsOfDirectory(at: pictures, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            guard !named.contains(file.lastPathComponent),
                  let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  now.timeIntervalSince(date) > 86_400 else { continue }
            try? fm.removeItem(at: file)
        }
    }

    // MARK: Reading and writing, in either home

    private func readData(_ name: String) -> Data? {
        switch home {
        case .keychain:
            return ArrivalBox.keychainRead(name).data
        case .folder(let folder):
            let file = folder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: file.path) else { return nil }
            var data: Data?
            var problem: NSError?
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { data = try? Data(contentsOf: $0) }
            return data
        }
    }

    private func readText(_ name: String) -> String {
        readData(name).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func write(_ data: Data, _ name: String) -> Bool {
        switch home {
        case .keychain:
            return ArrivalBox.keychainWrite(name, data)
        case .folder(let folder):
            let file = folder.appendingPathComponent(name)
            var done = false
            var problem: NSError?
            NSFileCoordinator().coordinate(writingItemAt: file, options: [], error: &problem) { url in
                done = (try? data.write(to: url, options: .atomic)) != nil
            }
            return done
        }
    }

    /// Reads the text, changes it and writes it back as ONE step: the app and the share page never write over
    /// each other's lines (in the folder home the system lets one of them in at a time).
    private func change(_ name: String, _ work: (String) -> String) -> Bool {
        switch home {
        case .keychain:
            let read = ArrivalBox.keychainRead(name)
            guard read.status == errSecSuccess || read.status == errSecItemNotFound else { return false }
            let old = read.data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return ArrivalBox.keychainWrite(name, Data(work(old).utf8))
        case .folder(let folder):
            let file = folder.appendingPathComponent(name)
            var done = false
            var problem: NSError?
            NSFileCoordinator().coordinate(writingItemAt: file, options: [], error: &problem) { url in
                let fm = FileManager.default
                var old = ""
                if fm.fileExists(atPath: url.path) {
                    // A list that is there but cannot be read is left alone rather than written over.
                    guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return }
                    old = text
                }
                let new = work(old)
                if new.isEmpty {
                    done = !fm.fileExists(atPath: url.path) || (try? fm.removeItem(at: url)) != nil
                } else {
                    done = (try? Data(new.utf8).write(to: url, options: .atomic)) != nil
                }
            }
            return done
        }
    }

    // MARK: The keychain

    private static func query(_ name: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: name,
         kSecAttrAccessGroup: keychainGroup,
         // The same kind of keychain on the Mac as on iPhone and iPad (groups work only there).
         kSecUseDataProtectionKeychain: true]
    }

    private static func keychainRead(_ name: String) -> (data: Data?, status: OSStatus) {
        var ask = query(name)
        ask[kSecReturnData] = true
        ask[kSecMatchLimit] = kSecMatchLimitOne
        var found: CFTypeRef?
        let status = SecItemCopyMatching(ask as CFDictionary, &found)
        return (status == errSecSuccess ? found as? Data : nil, status)
    }

    /// Writes the item; empty data takes it away.
    private static func keychainWrite(_ name: String, _ data: Data) -> Bool {
        if data.isEmpty {
            let status = SecItemDelete(query(name) as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
        let status = SecItemUpdate(query(name) as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var new = query(name)
        new[kSecValueData] = data
        // Readable after the first unlock: the share page may run while the device is locked again.
        new[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(new as CFDictionary, nil) == errSecSuccess
    }
}
