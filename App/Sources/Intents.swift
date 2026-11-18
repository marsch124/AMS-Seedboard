import AppIntents
import Foundation
import SeedboardCore

// Pick 26: Seedboard can be reached from outside — the Shortcuts app, Siri, the Action button,
// Spotlight and Raycast (which runs Shortcuts). Three actions: "New board from text", "New board",
// "Open board". Each one runs inside the app and goes through the SAME model the screens use
// (`AppModel.add`, `AppModel.open`), so there is one writer of boards only.

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

/// A board, as Shortcuts and Siri know it.
struct BoardEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Board"
    static let defaultQuery = BoardQuery()

    let id: UUID
    let title: String
    let words: String

    init(_ board: Board) {
        id = board.id
        title = board.title
        words = board.countLine
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(words)")
    }
}

/// The boards on offer, by name (newest change first, as in the app's list).
struct BoardQuery: EntityStringQuery {
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
}

/// The ways a new board can begin, as Shortcuts and Siri know them.
enum StarterChoice: String, AppEnum {
    case blank, mindMap, flow, prosCons, steps, timeline, sequence

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Starter"
    static let caseDisplayRepresentations: [StarterChoice: DisplayRepresentation] = [
        .blank: "Blank board",
        .mindMap: "Mind map",
        .flow: "Flow",
        .prosCons: "Pros and cons",
        .steps: "Plan in steps",
        .timeline: "Timeline",
        .sequence: "Who does what",
    ]

    var starter: Starter { Starter(rawValue: rawValue) ?? .blank }
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
    static let description = IntentDescription("Makes a new board with the starter you choose and opens it.")
    static let openAppWhenRun = true

    @Parameter(title: "Start with", default: .blank)
    var starter: StarterChoice

    static var parameterSummary: some ParameterSummary {
        Summary("New board: \(\.$starter)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<BoardEntity> {
        let model = AppModel.shared
        await model.whenLoaded()
        let id = model.newBoard(starter.starter)
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

    var localizedStringResource: LocalizedStringResource { "The board could not be made." }
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
    }
}
