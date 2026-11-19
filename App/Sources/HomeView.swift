import SwiftUI
import SeedboardCore
import AMSIcons

// The home page (Mac and iPad, when no board is open), the cards on it, the starter chooser made of
// the same cards, and the search field over the boards list. The strip's card is in HomeStrip.swift.

/// The home page (0.5: his boards first): the sprout and "Plant a seed", the starters as ONE strip that slides
/// sideways, then the boards as cards with their small pictures — Pinned, Recent, Sent to PARAGON.
/// It has the board's own background by day and by night.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var scheme
    /// The words in the search field over the list: the cards follow them.
    let search: String
    let open: (UUID) -> Void

    @State private var renaming: Board?
    @State private var newName = ""
    @State private var removing: Board?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 10, alignment: .top)]

    var body: some View {
        let found = BoardSearch.find(search, in: model.boards)
        let pinned = found.filter { $0.pinned && !$0.isPutAway }
        let recent = found.filter { !$0.pinned && $0.sent == nil && !$0.isPutAway }
        let sent = found.filter { !$0.pinned && $0.sent != nil && !$0.isPutAway }
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
                        // The Blank board always first: the sure way to a new board when the list is hidden.
                        ForEach(model.shelf.strip) { starter in
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
                // 0.9: a search also finds boards that were put away; they are marked.
                if !BoardSearch.words(search).isEmpty {
                    section("Put away", found.filter(\.isPutAway))
                } else {
                    PutAwayRow().padding(.top, 6)
                }

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
        // The same background as an open board, to every edge: no black beside a charcoal board at night.
        .background(Paint(scheme).canvas.ignoresSafeArea())
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
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
                .accessibilityIdentifier("home.heading.\(title)")
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(boards) { board in
                    BoardCard(board: board, search: search) { open(board.id) }
                        .accessibilityIdentifier("home.board.\(board.title)")
                        // The list's own press-and-hold menu (RootView.swift `row`), word for word.
                        .contextMenu {
                            Button("Rename…") {
                                newName = board.title
                                renaming = board
                            }
                            Button(board.pinned ? "Unpin" : "Pin to the top") { model.togglePin(board.id) }
                            Button("Make a copy") { model.duplicate(board.id) }
                            if board.canBeChanged && !board.isPutAway { Button("Put away") { model.putAway(board.id) } }
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

/// The plate of a card: the small picture on top, words below, a thin edge all round.
struct CardPlate: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    /// 0.5: the pointer is over the card (the Mac, an iPad's trackpad): a green edge and a deeper shadow.
    @State private var over = false

    func body(content: Content) -> some View {
        let paint = Paint(scheme)
        let outline = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return content
            .background(paint.plate)
            .clipShape(outline)
            .overlay(outline.stroke(over ? Part.boards.text.opacity(0.6) : paint.edge, lineWidth: 1))
            // The same faint shadow as a shape on the board, by day only.
            .shadow(color: .black.opacity(scheme == .dark ? 0 : (over ? 0.12 : 0.06)), radius: over ? 6 : 2, y: 1)
            .contentShape(outline)
            .modifier(CardPointer(over: $over, outline: outline))
    }
}

/// One way to begin: a real small drawing of the starter, its name and one line about it.
struct StarterCard: View {
    let starter: ShelfStarter
    let pick: () -> Void
    /// A question from the card's press-and-hold menu (Rename…, Change…, Remove, Edit starters…).
    let ask: (StarterAsk) -> Void
    @Environment(\.colorScheme) private var scheme

    /// The room the name and the two lines of the hint take, for sizing the chooser.
    #if os(macOS)
    static let wordsRoom: CGFloat = 58
    #else
    static let wordsRoom: CGFloat = 70
    #endif

    var body: some View {
        Button(action: pick) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    BoardThumb(starter: starter)
                    if (starter.board ?? starter.builtin.map { Thumbs.board(of: $0) } ?? Board()).isEmpty {
                        // An empty sheet: a quiet plus in the middle says "start from nothing".
                        ControlMarkView(.add, size: 26, colour: Part.boards.text.opacity(0.75))
                    }
                }
                Rectangle().fill(Paint(scheme).edge).frame(height: 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(starter.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(starter.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .modifier(CardPlate())
        }
        .buttonStyle(PressStyle(pressed: FeelRules.mainPressed, wash: nil))
        .starterMenu(starter, ask: ask)
        .accessibilityLabel("\(starter.name). \(starter.hint)")
    }
}

/// One board: its small picture, its colour dot and name, and when it was changed, in plain words.
struct BoardCard: View {
    let board: Board
    /// The words in the search field (marks "put away" and "in a picture" follow them).
    var search = ""
    let open: () -> Void
    @Environment(\.colorScheme) private var scheme
    /// 0.5: "5 of 13 done", read from PARAGON (EchoKeeper.swift).
    @ObservedObject private var echo = EchoKeeper.shared

    var body: some View {
        let paint = Paint(scheme)
        return Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    BoardThumb(board: board)
                    // 0.5: an empty board's card shows a faint sprout instead of the word "Empty".
                    if board.isEmpty { EmptySprout() }
                }
                Rectangle().fill(paint.edge).frame(height: 1)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(paint.line(board.colour))
                            .frame(width: 9, height: 9)
                        Text(board.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                    }
                    DoneWords(changed: board.changedWords(), tail: echo.doneTail(board))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 15)
                    // 0.9: one small line: "34 ideas · 12 done · 3 late".
                    Text(board.listLine(doneThings: echo.doneThings(board)) + FoundMarks.words(board, search: search))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 15)
                        .accessibilityIdentifier("home.line.\(board.title)")
                    DueWords(board: board)
                        .padding(.leading, 15)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .modifier(CardPlate())
        }
        .buttonStyle(PressStyle(pressed: FeelRules.mainPressed, wash: nil))
        .accessibilityLabel("\(board.title). \(board.changedWords())\(echo.doneTail(board))")
    }
}

/// The ways to begin a board, as the same cards with drawings as on the home page.
/// A small pop-up on the Mac and the iPad (three cards in a row), a page from the bottom on the iPhone (two in a row).
struct StarterPicker: View {
    @EnvironmentObject private var model: AppModel
    var wide = false
    let pick: (ShelfStarter) -> Void
    /// Closes the pop-up or page the picker is in (a question from a card's menu first closes it).
    var close: () -> Void = {}

    #if os(macOS)
    private static let cardWidth: CGFloat = 150
    #else
    private static let cardWidth: CGFloat = 160
    #endif
    private static let perRow = 3
    private static let gap: CGFloat = 8

    /// The pop-up's size: every card in sight without sliding, whatever the number of starters.
    private static func popSize(count: Int) -> CGSize {
        let rows = CGFloat((max(count, 1) + perRow - 1) / perRow)
        let card = (cardWidth / Thumbs.shape).rounded(.up) + 1 + StarterCard.wordsRoom
        return CGSize(width: CGFloat(perRow) * cardWidth + CGFloat(perRow - 1) * gap + 20,
                      height: rows * card + (rows - 1) * gap + 60)
    }

    /// The iPhone's page: most of the screen, so three rows of two are in sight; it can be pulled up all the way.
    static let sheetDetents: Set<PresentationDetent> = [.fraction(0.78), .large]

    var body: some View {
        let columns = wide
            ? [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: StarterPicker.gap, alignment: .top)]
            : Array(repeating: GridItem(.fixed(StarterPicker.cardWidth), spacing: StarterPicker.gap, alignment: .top), count: StarterPicker.perRow)
        return VStack(alignment: .leading, spacing: 6) {
            // The heading: large and in the middle; Edit stays small at the right.
            ZStack {
                Text("Starters")
                    .font(Txt.big)
                    .foregroundStyle(Part.boards.text)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("starters.heading")
                HStack {
                Spacer()
                Button {
                    close()
                    model.ask(.page)
                } label: {
                    Text("Edit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Part.boards.text)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Edit the starters")
                .accessibilityIdentifier("starters.edit")
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, wide ? 8 : 0)
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: StarterPicker.gap) {
                    ForEach(model.shelf.shown) { starter in
                        StarterCard(starter: starter, pick: { pick(starter) }, ask: { question in
                            close()
                            model.ask(question)
                        })
                        .accessibilityIdentifier("starter.\(starter.id)")
                    }
                }
                // Room for the cards' faint shadow and edge.
                .padding(.horizontal, 1)
                .padding(.bottom, 3)
            }
        }
        .padding(10)
        // A fixed size: on the iPhone a pop-up without one comes out empty.
        .frame(width: wide ? nil : StarterPicker.popSize(count: model.shelf.shown.count).width,
               height: wide ? nil : StarterPicker.popSize(count: model.shelf.shown.count).height, alignment: .top)
        .frame(maxWidth: wide ? .infinity : nil, maxHeight: wide ? .infinity : nil, alignment: .top)
    }
}

/// The search field over the boards list: finds boards by their name and by the words on them.
struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            GlyphView(glyph: .new(.search), size: 16, colour: Part.boards.text)
            TextField("Search boards", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                #else
                // Escape is Cancel: the search is emptied and every board is back.
                .onExitCommand { text = "" }
                #endif
                .accessibilityLabel("Search boards")
                .accessibilityIdentifier("boards.search")
            if !text.isEmpty {
                Button { text = "" } label: {
                    ControlMarkView(.closeCircle, size: 17, colour: Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .help("Show every board again")
                .accessibilityLabel("Clear the search")
                .accessibilityIdentifier("boards.searchClear")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// The board's small picture at the right of its row in the iPhone's list.
struct RowPicture: View {
    let board: Board
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return BoardThumb(board: board)
            .frame(width: 60)
            .clipShape(outline)
            .overlay(outline.stroke(Paint(scheme).edge, lineWidth: 1))
    }
}
