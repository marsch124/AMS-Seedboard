import SwiftUI
import SeedboardCore
import AMSIcons

// 0.5, pick 13: what doors add to the open board's screen — "‹ name" in the top bar to go back through the
// door he came through (the Mac and a keyboard: ⌘[), the page "Door to a board…", the question for the name
// of the new board when things move out — and a board dragged from the list.

/// Put on the open board once (BoardView.swift).
struct DoorHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var desk = DoorDesk.shared

    func body(content: Content) -> some View {
        content
            .toolbar {
                if let from = desk.backBoard, !session.starterDraft {
                    ToolbarItem(placement: Self.backPlace) { backButton(from) }
                }
            }
            .sheet(item: $desk.picking, onDismiss: { session.takeKeys() }) { ask in
                DoorPage(session: session, spot: ask.spot).environmentObject(model)
            }
            .alert("Name of the new board", isPresented: Binding(get: { desk.movingOut != nil }, set: { if !$0 { desk.movingOut = nil } })) {
                TextField("Name", text: $desk.moveName)
                    .accessibilityIdentifier("door.moveName")
                Button("Cancel", role: .cancel) {
                    desk.movingOut = nil
                    session.takeKeys()
                }
                Button("Save") {
                    if let ask = desk.movingOut { session.moveOut(ask.things, named: desk.moveName) }
                    desk.movingOut = nil
                    session.takeKeys()
                }
            } message: {
                let count = desk.movingOut?.count ?? 0
                Text(count == 1 ? "1 thing moves there. A door to it is left in its place."
                                : "\(count) things move there. A door to it is left in their place.")
            }
            // A small picture is ready, or a door's board turned out to be removed: the board is drawn again.
            .onReceive(DoorLook.shared.ready) { _ in session.objectWillChange.send() }
            // A board was renamed, removed or arrived: after the change has landed, the doors follow.
            .onReceive(model.$boards) { _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { desk.refresh(session) } }
            }
            .onAppear {
                desk.refresh(session)
                // For pictures: `-doorPage`, `-door <word>`, `-doorBack <word>`, a moment after the board is shown.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { MainActor.assumeIsolated { desk.launch(session) } }
            }
    }

    #if os(macOS)
    private static let backPlace = ToolbarItemPlacement.navigation
    #else
    private static let backPlace = ToolbarItemPlacement.topBarLeading
    #endif

    /// "‹ Summer cabin": back to the board he came from.
    private func backButton(_ from: Board) -> some View {
        Button {
            desk.goBack()
        } label: {
            HStack(spacing: 2) {
                ControlMarkView(.chevron, size: 16, colour: Part.boards.text)
                    .rotationEffect(.degrees(180))
                Text(from.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Part.boards.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 170, alignment: .leading)
            .padding(.vertical, 3)
            .padding(.trailing, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .keyboardShortcut("[", modifiers: .command)
        .help("Back to “\(from.title)” (⌘[)")
        .accessibilityLabel("Back to \(from.title)")
        .accessibilityIdentifier("board.back")
    }
}

/// "Door to a board…": the list of the other boards with a search field, "New board" at the top, Cancel
/// (Escape on the Mac). Pressing a board puts a door to it on the open board and closes the page.
struct DoorPage: View {
    @ObservedObject var session: BoardSession
    /// Where the door will lie (board points); nil: a free place in the middle of the view.
    let spot: CGPoint?

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var search = LaunchOptions.value(for: "-doorSearch") ?? ""
    @FocusState private var searching: Bool

    /// The other boards that hold the words, the pinned ones first, then the one changed last first.
    private var found: [Board] {
        let others = BoardSearch.find(search, in: model.boards).filter { $0.id != session.board.id }
        return others.filter(\.pinned) + others.filter { !$0.pinned }
    }

    private var typedName: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            Text("Door to a board")
                .font(Txt.big)
                .foregroundStyle(Part.boards.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("door.heading")
                .padding(.top, 12)
            Text("Press the board the door leads to.")
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            Button { newBoard() } label: {
                HStack(spacing: 6) {
                    ControlMarkView(.add, size: 15, colour: .white)
                    Text(typedName.isEmpty ? "New board" : "New board “\(typedName)”")
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(.boards))
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .accessibilityIdentifier("door.new")

            field
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(found) { board in row(board) }
                    if found.isEmpty {
                        Text(model.boards.count <= 1 ? "No other board yet. Press New board." : "No board has these words")
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .accessibilityIdentifier("door.noMatch")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .accessibilityIdentifier("door.list")

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("door.cancel")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        #if os(macOS)
        .frame(width: 380, height: 480)
        .onAppear { searching = true }
        #else
        .presentationDetents([.medium, .large])
        #endif
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("door.page")
    }

    /// The search field: the same look as the one over the boards list.
    private var field: some View {
        HStack(spacing: 6) {
            GlyphView(glyph: .new(.search), size: 16, colour: Part.boards.text)
            TextField("Search boards", text: $search)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($searching)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                #endif
                .accessibilityLabel("Search boards")
                .accessibilityIdentifier("door.search")
            if !search.isEmpty {
                Button { search = "" } label: {
                    ControlMarkView(.closeCircle, size: 17, colour: Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .help("Show every board again")
                .accessibilityLabel("Clear the search")
                .accessibilityIdentifier("door.searchClear")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func row(_ board: Board) -> some View {
        let paint = Paint(scheme)
        return Button { pick(board) } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(paint.line(board.colour))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 0) {
                    Text(board.title)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text("\(board.changedWords()) · \(board.countLine)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                RowPicture(board: board)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("door.row.\(board.title)")
    }

    private func pick(_ board: Board) {
        session.addDoor(to: board, at: spot)
        dismiss()
    }

    /// "New board": a new, empty board (named with the words in the search field, when there are some) joins
    /// the list, and the door leads to it. It is not opened: two presses on the door do that.
    private func newBoard() {
        guard !session.readOnly, !session.board.placesItself else {
            dismiss()
            return
        }
        let board = model.plantBoard(named: typedName.isEmpty ? "New board" : typedName)
        session.addDoor(to: board, at: spot)
        dismiss()
    }
}

/// A row of the boards list can be dragged (Mac and iPad): let go over the open board, it leaves a door to
/// that board there. What travels is the board's own link, so dropped into a note elsewhere it is that link.
struct DoorDrag: ViewModifier {
    let board: Board
    /// Off on the iPhone, where the list and a board are never on screen together.
    let on: Bool

    func body(content: Content) -> some View {
        if on {
            content.onDrag {
                NSItemProvider(object: ParagonExport.boardLink(board.id) as NSString)
            } preview: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Paint(night: false).line(board.colour))
                        .frame(width: 9, height: 9)
                    Text(board.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        } else {
            content
        }
    }
}
