import Foundation
import Combine
import CoreSpotlight
import UniformTypeIdentifiers
import SeedboardCore

// Pick 26: the device's own search (Spotlight) finds a board by its name and its first words, and
// opens it. Only on this device; with `-sampleData` nothing is told to the search.

/// Tells the device's search which boards there are. Cheap: it runs a moment after the boards were
/// saved, tells only what changed since last time, and does its work off the main thread.
@MainActor
final class SpotlightIndex {
    static let shared = SpotlightIndex()

    /// What the search was told last: each board's id with the time of its last change.
    private static let key = "seedboard.searchTold"
    private var watch: AnyCancellable?
    private var titles: [String] = []
    private var busy = false
    private var again: [Board]?

    func watch(_ model: AppModel) {
        guard watch == nil, !LaunchOptions.sampleData, CSSearchableIndex.isIndexingAvailable() else { return }
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
        let learn = boards.filter { plan.learn.contains($0.id) }
        let forget = plan.forget.map(\.uuidString)
        busy = true
        Task.detached(priority: .utility) {
            let index = CSSearchableIndex.default()
            var learned = false, forgotten = false
            if !learn.isEmpty {
                let items = learn.map { SpotlightIndex.item(for: $0) }
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

    /// One board as the search shows it: its name, and the first words on it.
    nonisolated private static func item(for board: Board) -> CSSearchableItem {
        let about = CSSearchableItemAttributeSet(contentType: .content)
        about.title = board.title
        about.displayName = board.title
        let words = Outside.searchWords(of: board)
        about.contentDescription = words.isEmpty ? board.countLine : words
        about.keywords = ["Seedboard", "board"]
        about.contentCreationDate = board.created
        about.contentModificationDate = board.changed
        let item = CSSearchableItem(uniqueIdentifier: board.id.uuidString, domainIdentifier: "board", attributeSet: about)
        // A board stays findable for as long as it is there (the default would drop it after a month).
        item.expirationDate = .distantFuture
        return item
    }
}
