import AppIntents
import Foundation
import SeedboardCore

// Pick 26: Seedboard can be reached from outside — the Shortcuts app, Siri, the Action button,
// Spotlight and Raycast (which runs Shortcuts). Three actions: "New board from text", "New board",
// "Open board". Each one runs inside the app and goes through the SAME model the screens use
// (`AppModel.add`, `AppModel.open`), so there is one writer of boards only.
// 0.5 (pick 23): "Add to board", "Board as text" and "Board as picture" are in IntentsAdd.swift; "Find boards"
// is the board query below; "New board" takes his own starters.

extension AppModel {
    /// The one model of the app. The window uses it, and so does an action that starts the app
    /// before any window is there.
    static let shared = AppModel()

    /// Waits until the boards are read (an action may arrive while the app is still starting).
    func whenLoaded() async {
        if loaded { return }
        for await ready in $loaded.values where ready { break }
    }
}

/// A board, as Shortcuts and Siri know it. Its name, the day it was changed, pinned and sent to PARAGON
/// can be asked for by "Find boards" (0.5).
struct BoardEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Board", numericFormat: "\(placeholder: .int) boards")
    static let defaultQuery = BoardQuery()

    let id: UUID
    let words: String

    @Property(title: "Name")
    var title: String
    @Property(title: "Changed")
    var changed: Date
    @Property(title: "Pinned")
    var pinned: Bool
    @Property(title: "Sent to PARAGON")
    var sent: Bool

    init(_ board: Board) {
        id = board.id
        words = board.countLine
        title = board.title
        changed = board.changed
        pinned = board.pinned
        sent = board.sent != nil
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(words)")
    }
}

/// The boards on offer, by name (newest change first, as in the app's list), and by what "Find boards" asks.
struct BoardQuery: EntityStringQuery, EntityPropertyQuery {
    @MainActor
    private func boards() async -> [Board] {
        let model = AppModel.shared
        await model.whenLoaded()
        return model.boards
    }

    func entities(for identifiers: [UUID]) async throws -> [BoardEntity] {
        let all = await boards()
        return identifiers.compactMap { id in all.first { $0.id == id } }.map(BoardEntity.init)
    }

    func entities(matching string: String) async throws -> [BoardEntity] {
        Outside.boards(named: string, in: await boards()).map(BoardEntity.init)
    }

    func suggestedEntities() async throws -> [BoardEntity] {
        await boards().map(BoardEntity.init)
    }

    // "Find boards" (0.5): the rule is `Outside.find` in SeedboardCore.

    static let findIntentDescription: IntentDescription? = IntentDescription("Finds your boards by name, by the day they were changed, and by whether they are pinned or were sent to PARAGON.")

    static var properties = QueryProperties {
        Property(\BoardEntity.$title) {
            EqualToComparator { Outside.BoardAsk.nameIs($0) }
            ContainsComparator { Outside.BoardAsk.nameHolds($0) }
            HasPrefixComparator { Outside.BoardAsk.nameBegins($0) }
        }
        Property(\BoardEntity.$changed) {
            GreaterThanComparator { Outside.BoardAsk.changedAfter($0) }
            LessThanComparator { Outside.BoardAsk.changedBefore($0) }
        }
        Property(\BoardEntity.$pinned) {
            EqualToComparator { Outside.BoardAsk.pinned($0) }
        }
        Property(\BoardEntity.$sent) {
            EqualToComparator { Outside.BoardAsk.sent($0) }
        }
    }

    static var sortingOptions = SortingOptions {
        SortableBy(\BoardEntity.$title)
        SortableBy(\BoardEntity.$changed)
    }

    func entities(matching comparators: [Outside.BoardAsk], mode: ComparatorMode, sortedBy: [Sort<BoardEntity>], limit: Int?) async throws -> [BoardEntity] {
        var order: Outside.BoardOrder?
        var ascending = true
        if let first = sortedBy.first {
            order = first.by == \BoardEntity.$title ? .name : .changed
            ascending = first.order == .ascending
        }
        return Outside.find(in: await boards(), asks: comparators, any: mode == .or, order: order, ascending: ascending, limit: limit)
            .map(BoardEntity.init)
    }
}

/// The ways a new board can begin, as Shortcuts and Siri know them: the starters of his own shelf (0.5),
/// the built-in ones and the ones he saved, in his order.
struct StarterEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Starter"
    static let defaultQuery = StarterQuery()

    let id: String
    let name: String
    let hint: String

    init(_ starter: ShelfStarter) {
        id = starter.id
        name = starter.name
        hint = starter.hint
    }

    var displayRepresentation: DisplayRepresentation {
        hint.isEmpty ? DisplayRepresentation(title: "\(name)") : DisplayRepresentation(title: "\(name)", subtitle: "\(hint)")
    }
}

struct StarterQuery: EntityStringQuery {
    /// The shelf is read once before the first answer (an action may arrive while the app is still starting).
    @MainActor
    private static var read = false

    /// The starters he sees on the Starters page, in his order.
    @MainActor
    static func shown() async -> [ShelfStarter] {
        let model = AppModel.shared
        await model.whenLoaded()
        if !read {
            await model.loadStarters()
            read = true
        }
        return model.shelf.shown
    }

    func entities(for identifiers: [String]) async throws -> [StarterEntity] {
        let all = await StarterQuery.shown()
        return identifiers.compactMap { id in all.first { $0.id == id } }.map(StarterEntity.init)
    }

    func entities(matching string: String) async throws -> [StarterEntity] {
        Outside.starters(named: string, in: await StarterQuery.shown()).map(StarterEntity.init)
    }

    func suggestedEntities() async throws -> [StarterEntity] {
        await StarterQuery.shown().map(StarterEntity.init)
    }
}

struct NewBoardFromTextIntent: AppIntent {
    static let title: LocalizedStringResource = "New board from text"
    static let description = IntentDescription("Makes a new board from words and opens it. A list becomes a mind map; anything else becomes one sticky note.")
    static let openAppWhenRun = true

    @Parameter(title: "Title")
    var title: String?

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("New board from \(\.$text)") {
            \.$title
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<BoardEntity> {
        let model = AppModel.shared
        await model.whenLoaded()
        let id = model.add(Outside.board(title: title, text: text))
        guard let board = model.boards.first(where: { $0.id == id }) else { throw OutsideProblem.notMade }
        return .result(value: BoardEntity(board))
    }
}

struct NewBoardIntent: AppIntent {
    static let title: LocalizedStringResource = "New board"
    static let description = IntentDescription("Makes a new board with the starter you choose — your own starters too — and opens it. With no starter it is a blank board.")
    static let openAppWhenRun = true

    @Parameter(title: "Start with")
    var starter: StarterEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("New board: \(\.$starter)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<BoardEntity> {
        let model = AppModel.shared
        await model.whenLoaded()
        // A starter of his shelf; none chosen, or one that was removed meanwhile, gives a blank board.
        let shown = await StarterQuery.shown()
        let id = starter.flatMap { asked in shown.first { $0.id == asked.id } }.map { model.newBoard(from: $0) } ?? model.newBoard(.blank)
        guard let board = model.boards.first(where: { $0.id == id }) else { throw OutsideProblem.notMade }
        return .result(value: BoardEntity(board))
    }
}

struct OpenBoardIntent: AppIntent {
    static let title: LocalizedStringResource = "Open board"
    static let description = IntentDescription("Opens one of your boards in Seedboard.")
    static let openAppWhenRun = true

    @Parameter(title: "Board")
    var board: BoardEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$board)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = AppModel.shared
        await model.whenLoaded()
        // The same way a link to a board is followed: a board that was removed meanwhile is said so in the app.
        if let url = URL(string: "seedboard://board/\(board.id.uuidString)") { model.open(url: url) }
        return .result()
    }
}

enum OutsideProblem: Error, CustomLocalizedStringResourceConvertible {
    case notMade
    /// A plain line that says what went wrong (0.5).
    case said(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notMade: return "The board could not be made."
        case .said(let line): return "\(line)"
        }
    }
}

/// The spoken and typed phrases. Each holds the app's name, as Siri asks for.
struct SeedboardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewBoardFromTextIntent(),
            phrases: [
                "New \(.applicationName) board from text",
                "Start a thought in \(.applicationName)",
            ],
            shortTitle: "New board from text",
            systemImageName: "text.badge.plus"
        )
        AppShortcut(
            intent: NewBoardIntent(),
            phrases: [
                "New \(.applicationName) board",
                "New board in \(.applicationName)",
                "New \(\.$starter) in \(.applicationName)",
            ],
            shortTitle: "New board",
            systemImageName: "plus.rectangle"
        )
        AppShortcut(
            intent: OpenBoardIntent(),
            phrases: [
                "Open a \(.applicationName) board",
                "Open \(\.$board) in \(.applicationName)",
            ],
            shortTitle: "Open board",
            systemImageName: "rectangle.stack"
        )
        // 0.5 (IntentsAdd.swift): these three leave Seedboard in the back.
        AppShortcut(
            intent: AddToBoardIntent(),
            phrases: [
                "Add to a \(.applicationName) board",
                "Add a thought in \(.applicationName)",
                "Add to \(\.$board) in \(.applicationName)",
            ],
            shortTitle: "Add to board",
            systemImageName: "plus.bubble"
        )
        AppShortcut(
            intent: BoardAsTextIntent(),
            phrases: [
                "Get a \(.applicationName) board as text",
                "Get \(\.$board) as text from \(.applicationName)",
            ],
            shortTitle: "Board as text",
            systemImageName: "text.alignleft"
        )
        AppShortcut(
            intent: BoardAsPictureIntent(),
            phrases: [
                "Get a \(.applicationName) board as a picture",
                "Get \(\.$board) as a picture from \(.applicationName)",
            ],
            shortTitle: "Board as picture",
            systemImageName: "photo"
        )
    }
}
