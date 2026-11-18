import AppIntents
import Foundation
import UniformTypeIdentifiers
import SeedboardCore

// 0.5 (pick 23): three Shortcuts actions that leave Seedboard in the back — "Add to board", "Board as text"
// and "Board as picture". They run inside the app and go through the one model, like the other actions
// (Intents.swift). The rules are `Outside.add`, `Outside.refusal` and `Outside.boardForThought` in SeedboardCore;
// the carrying out is `AppModel.addFromOutside` (OutsideAdd.swift).

struct AddToBoardIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to board"
    static let description = IntentDescription("Adds a thought to one of your boards without opening Seedboard. One line becomes a sticky note, a list becomes a mind map, a picture becomes a picture. With no board chosen it goes to the board you changed last.")

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true), requestValueDialog: "What do you want to add?")
    var text: String

    @Parameter(title: "Picture", supportedTypeIdentifiers: ["public.image"])
    var picture: IntentFile?

    @Parameter(title: "Board")
    var board: BoardEntity?

    @Parameter(title: "Open the board afterwards", default: false)
    var openAfterwards: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to \(\.$board)") {
            \.$picture
            \.$openAfterwards
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<BoardEntity> & ProvidesDialog {
        let model = AppModel.shared
        await model.whenLoaded()
        switch await model.addFromOutside(text: text, picture: picture?.data, to: board?.id) {
        case .refused(let line):
            throw OutsideProblem.said(line)
        case .added(let board, let line):
            let entity = BoardEntity(board)
            // Opening afterwards needs iOS 18.2 / macOS 15.2; before that the board is simply not opened.
            if openAfterwards, #available(iOS 18.2, macOS 15.2, *) {
                let open = OpenBoardIntent()
                open.board = entity
                return .result(value: entity, opensIntent: open, dialog: "\(line)")
            }
            return .result(value: entity, dialog: "\(line)")
        }
    }
}

struct BoardAsTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Board as text"
    static let description = IntentDescription("Gives the words of a board as plain text, the same as “Copy the board as text”. Seedboard stays in the back.")

    @Parameter(title: "Board")
    var board: BoardEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$board) as text")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let model = AppModel.shared
        await model.whenLoaded()
        guard let found = model.boardNow(board.id) else { throw OutsideProblem.said(AppModel.goneLine) }
        return .result(value: found.outlineText)
    }
}

struct BoardAsPictureIntent: AppIntent {
    static let title: LocalizedStringResource = "Board as picture"
    static let description = IntentDescription("Gives a board as a picture, the same picture PARAGON gets. Seedboard stays in the back.")

    @Parameter(title: "Board")
    var board: BoardEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$board) as a picture")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let model = AppModel.shared
        await model.whenLoaded()
        guard let found = model.boardNow(board.id) else { throw OutsideProblem.said(AppModel.goneLine) }
        guard let png = await model.pictureNow(of: found) else {
            throw OutsideProblem.said("“\(found.title)” is empty, so there is no picture of it.")
        }
        return .result(value: IntentFile(data: png, filename: AppModel.fileName(for: found) + ".png", type: .png))
    }
}
