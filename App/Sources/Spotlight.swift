import Foundation
import Combine
import CoreSpotlight
import UniformTypeIdentifiers
import ImageIO
import AppIntents
import SeedboardCore

// Pick 26: the device's own search (Spotlight) finds a board by its name and its first words, and
// opens it. Only on this device; with `-sampleData` nothing is told to the search.
// 0.5: the search knows EVERY word of a board (it knew only the first 300 letters), shows the board's small
// picture, and — on iOS 18 / macOS 15 and later — knows the board as a thing ("Open board" on the result).

/// Tells the device's search which boards there are. Cheap: it runs a moment after the boards were
/// saved, tells only what changed since last time, and does its work off the main thread.
@MainActor
final class SpotlightIndex {
    static let shared = SpotlightIndex()

    /// What the search was told last: each board's id with the time of its last change.
    /// 0.5 renamed the key once, so every board is told again — now with all its words and its picture.
    private static let key = "seedboard.searchTold.2"
    private static let oldKey = "seedboard.searchTold"
    private var watch: AnyCancellable?
    private var titles: [String] = []
    private var busy = false
    private var again: [Board]?

    func watch(_ model: AppModel) {
        guard watch == nil, !LaunchOptions.sampleData, CSSearchableIndex.isIndexingAvailable() else { return }
        UserDefaults.standard.removeObject(forKey: SpotlightIndex.oldKey)
        watch = model.$boards
            .combineLatest(model.$loaded)
            .filter { $0.1 }
            .map { $0.0 }
            // A board is saved half a second after a change; the search hears of it once typing rests.
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] boards in self?.tell(boards) }
    }

    private func told() -> [UUID: Date] {
        let stored = UserDefaults.standard.dictionary(forKey: SpotlightIndex.key) as? [String: Double] ?? [:]
        var out: [UUID: Date] = [:]
        for (word, stamp) in stored {
            if let id = UUID(uuidString: word) { out[id] = Date(timeIntervalSinceReferenceDate: stamp) }
        }
        return out
    }

    private func keep(_ told: [UUID: Date]) {
        var stored: [String: Double] = [:]
        for (id, stamp) in told { stored[id.uuidString] = stamp.timeIntervalSinceReferenceDate }
        UserDefaults.standard.set(stored, forKey: SpotlightIndex.key)
    }

    private func tell(_ boards: [Board]) {
        // The names Siri and Shortcuts offer for "Open board" follow the list.
        let names = boards.map(\.title)
        if names != titles {
            titles = names
            SeedboardShortcuts.updateAppShortcutParameters()
        }
        // One round at a time; what changed meanwhile is told in the next round.
        guard !busy else {
            again = boards
            return
        }
        let plan = Outside.searchPlan(known: told(), boards: Dictionary(boards.map { ($0.id, $0.changed) }, uniquingKeysWith: max))
        guard !plan.learn.isEmpty || !plan.forget.isEmpty else { return }
        // Never while he is typing or dragging: the small pictures are drawn on the main thread.
        if AppModel.shared.session?.busy == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.tell(AppModel.shared.boards) }
            return
        }
        let learn = boards.filter { plan.learn.contains($0.id) }
        let forget = plan.forget.map(\.uuidString)
        busy = true
        Task { @MainActor in
            // Only for boards that changed, one picture at a time, the screen gets its turn in between.
            var pictures: [UUID: Data] = [:]
            for board in learn where !board.isEmpty {
                pictures[board.id] = SpotlightIndex.smallPicture(of: board)
                await Task.yield()
            }
            self.index(learn, pictures: pictures, forget: forget, plan: plan)
        }
    }

    /// The board's small picture as the search shows it: the one the home page draws (by day), as a JPEG.
    private static func smallPicture(of board: Board) -> Data? {
        guard let image = Thumbs.picture(of: board, name: board.id.uuidString, night: false) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    private func index(_ learn: [Board], pictures: [UUID: Data], forget: [String], plan: (learn: Set<UUID>, forget: Set<UUID>)) {
        Task.detached(priority: .utility) {
            let index = CSSearchableIndex.default()
            var learned = false, forgotten = false
            if !learn.isEmpty {
                let items = learn.map { SpotlightIndex.item(for: $0, picture: pictures[$0.id]) }
                learned = (try? await index.indexSearchableItems(items)) != nil
            }
            if !forget.isEmpty {
                forgotten = (try? await index.deleteSearchableItems(withIdentifiers: forget)) != nil
            }
            let done = (learned, forgotten)
            await MainActor.run {
                // Only what the search really took is ticked off; the rest is told again next time.
                var known = self.told()
                if done.0 { for board in learn { known[board.id] = board.changed } }
                if done.1 { for id in plan.forget { known[id] = nil } }
                self.keep(known)
                self.busy = false
                if let next = self.again {
                    self.again = nil
                    self.tell(next)
                }
            }
        }
    }

    /// One board as the search shows it: its name, the first words on it and its small picture. Every word
    /// of the board is searched (never shown).
    nonisolated private static func item(for board: Board, picture: Data?) -> CSSearchableItem {
        let about = CSSearchableItemAttributeSet(contentType: .content)
        about.title = board.title
        about.displayName = board.title
        let words = Outside.searchWords(of: board)
        about.contentDescription = words.isEmpty ? board.countLine : words
        about.textContent = Outside.searchText(of: board)
        about.thumbnailData = picture
        about.keywords = ["Seedboard", "board"]
        about.contentCreationDate = board.created
        about.contentModificationDate = board.changed
        let item = CSSearchableItem(uniqueIdentifier: board.id.uuidString, domainIdentifier: "board", attributeSet: about)
        // A board stays findable for as long as it is there (the default would drop it after a month).
        item.expirationDate = .distantFuture
        // The result is also the board as Siri and Shortcuts know it.
        if #available(iOS 18.0, macOS 15.0, *) { item.associateAppEntity(BoardEntity(board)) }
        return item
    }
}

/// iOS 18 / macOS 15 and later: Siri and the device's search know a board as a thing, not only by a phrase.
@available(iOS 18.0, macOS 15.0, *)
extension BoardEntity: IndexedEntity {}
