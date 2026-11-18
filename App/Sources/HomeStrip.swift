import SwiftUI
import SeedboardCore
import AMSIcons

// 0.5 (pick 7), PICTURES FIRST: the home page with the owner's boards first. The starters are ONE strip that
// slides sideways; Pinned, Recent and Sent to PARAGON come right under it; the header loses its green button
// (the list's "New board" is the one green button again); a board card has the list's press-and-hold menu.
// Until the owner has picked it is behind the launch word `-homeStrip`; without it the home page is as in 0.4.

/// The new home page.
struct HomeStripPage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let search: String
    let open: (UUID) -> Void

    @State private var renaming: Board?
    @State private var newName = ""
    @State private var removing: Board?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 10, alignment: .top)]

    var body: some View {
        let found = BoardSearch.find(search, in: model.boards)
        let pinned = found.filter(\.pinned)
        let recent = found.filter { !$0.pinned && $0.sent == nil }
        let sent = found.filter { !$0.pinned && $0.sent != nil }
        return ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                header
                HStack {
                    Text("STARTERS")
                        .font(.caption.weight(.bold))
                        .kerning(0.5)
                        .foregroundStyle(Part.boards.text)
                    Spacer()
                    Button { model.ask(.page) } label: {
                        Text("Edit")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Part.boards.text)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .help("Rename, move, change and remove starters")
                    .accessibilityLabel("Edit the starters")
                    .accessibilityIdentifier("home.startersEdit")
                }
                .padding(.top, 6)
                // ONE strip: it slides sideways, a card that is cut off at the edge says there are more.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: StarterStripCard.gap) {
                        ForEach(model.shelf.shown) { starter in
                            StarterStripCard(starter: starter, pick: { open(model.newBoard(from: starter)) }, ask: { model.ask($0) })
                                .accessibilityIdentifier("home.starter.\(starter.id)")
                        }
                    }
                    // Room for the cards' faint shadow and edge.
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
                    .padding(.bottom, 3)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.starterStrip")

                section("Pinned", pinned)
                section("Recent", recent)
                section("Sent to PARAGON", sent, part: .paragon)

                if model.loaded, !model.boards.isEmpty, found.isEmpty {
                    Text("No board has these words")
                        .font(Txt.label)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                        .accessibilityIdentifier("home.noMatch")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Paint(scheme).canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.none")
        .alert("Name of the board", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                if let board = renaming { model.rename(board.id, to: newName) }
                renaming = nil
            }
        }
        .confirmationDialog("Remove “\(removing?.title ?? "")”?",
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible) {
            Button("Remove the board", role: .destructive) {
                if let board = removing { model.remove(board.id) }
                removing = nil
            }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: {
            Text("It is kept for 30 days in the Removed folder.")
        }
    }

    /// The sprout and "Plant a seed" — no button: the list's "New board" is the one green button.
    private var header: some View {
        HStack(spacing: 10) {
            AppMarkView(.seedSprout, size: 30, colour: Part.boards.text)
            VStack(alignment: .leading, spacing: 0) {
                Text("Plant a seed")
                    .font(Txt.big)
                Text("Every idea starts on a board.")
                    .font(Txt.label)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ boards: [Board], part: Part = .boards) -> some View {
        if !boards.isEmpty {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .kerning(0.5)
                .foregroundStyle(part.text)
                .padding(.top, 16)
                .padding(.bottom, 4)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(boards) { board in
                    BoardCard(board: board) { open(board.id) }
                        .accessibilityIdentifier("home.board.\(board.title)")
                        // The list's own press-and-hold menu (RootView.swift), word for word.
                        .contextMenu {
                            Button("Rename…") {
                                newName = board.title
                                renaming = board
                            }
                            Button(board.pinned ? "Unpin" : "Pin to the top") { model.togglePin(board.id) }
                            Button("Make a copy") { model.duplicate(board.id) }
                            if board.canBeChanged {
                                Button("Save as a starter…") { model.ask(.save(model.boardForStarter(board.id) ?? board)) }
                            }
                            Menu("Colour") {
                                ForEach(Palette.boards, id: \.self) { name in
                                    Button(name.capitalized) { model.setColour(board.id, name) }
                                }
                            }
                            if let sent = board.sent {
                                Button("Open in PARAGON") { model.openInParagon(sent) }
                            }
                            Divider()
                            Button("Remove…", role: .destructive) { removing = board }
                        }
                }
            }
        }
    }
}

/// One way to begin, in the strip: the starter's small drawing and its name. 132 wide, no grey line, no second line.
struct StarterStripCard: View {
    let starter: ShelfStarter
    let pick: () -> Void
    let ask: (StarterAsk) -> Void

    static let width: CGFloat = 132
    static let gap: CGFloat = 8

    var body: some View {
        Button(action: pick) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    BoardThumb(starter: starter)
                    if (starter.board ?? starter.builtin.map { Thumbs.board(of: $0) } ?? Board()).isEmpty {
                        // An empty sheet: a quiet plus in the middle says "start from nothing".
                        ControlMarkView(.add, size: 22, colour: Part.boards.text.opacity(0.75))
                    }
                }
                Text(starter.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.top, 3)
                    .padding(.bottom, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: StarterStripCard.width)
            .modifier(CardPlate())
        }
        .buttonStyle(PressStyle())
        .starterMenu(starter, ask: ask)
        .help(starter.hint)
        .accessibilityLabel("\(starter.name). \(starter.hint)")
    }
}
