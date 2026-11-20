import SwiftUI
import SeedboardCore
import AMSIcons

// 0.5, the flow of thinking (picks 10, 11 and 12). The rules are in SeedboardCore (Thinking.swift). Here:
// the next sticky note while typing (Tab, and "Next note" / "Next shape" above the screen keyboard), "Turn into",
// a note dropped on an idea, "Make a mind map" with its small question, "Break into notes", and sorting a pile
// (Colour for several, Tidy, By colour, Choose all of this colour). Each change is one step for Undo.
// Nothing of this shows on a board that places its things itself (a timeline, "Who does what").

/// What this part keeps between two steps (never stored).
@MainActor
final class ThinkDesk: ObservableObject {
    static let shared = ThinkDesk()

    /// The sticky note that "Next note" made and that is being typed in, and the note it came from.
    var chained: (note: UUID, from: UUID)?
    /// "Make a mind map" asks for the middle idea.
    @Published var askingMap = false
    /// The middle idea as it is typed (filled in with the board's name).
    @Published var middle = ""

    #if os(iOS)
    /// iPhone and iPad: sticky notes typed one after the other share one field, and so do shapes, so the
    /// screen keyboard stays up from one to the next (as it does for ideas).
    static let noteField = UUID()
    static let shapeField = UUID()
    #endif
}

// MARK: The session's part

extension BoardSession {
    private var thinkingIsOn: Bool { !readOnly && !board.placesItself }

    // Pick 10: the next note

    /// Tab while a sticky note is typed, and "Next note" above the screen keyboard: the words are kept, the next
    /// note appears right beside it and the typing goes on. False when no sticky note is being typed.
    @discardableResult
    func nextNote() -> Bool {
        guard thinkingIsOn, let id = editing, board.item(id)?.kind == .note else { return false }
        // Nothing typed yet: there is nothing to go on from, the typing just ends.
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            commitEdit()
            return true
        }
        commitEdit()
        var made: UUID?
        change { made = $0.addNextNote(after: id) }
        guard let made else { return true }
        ThinkDesk.shared.chained = (made, id)
        beginEdit(made, isNew: true)
        reveal(made)
        return true
    }

    /// The typing ends in a "next note" that is still empty: it was not meant. It goes again and leaves no
    /// trace (as Escape does); the note it came from is chosen. `commitEdit` asks this first.
    func dropsEmptyNextNote(_ id: UUID) -> Bool {
        guard let chain = ThinkDesk.shared.chained, chain.note == id else { return false }
        ThinkDesk.shared.chained = nil
        guard draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        cancelEdit()
        if board.item(chain.from) != nil { selection = [chain.from] }
        return true
    }

    /// "Next shape" above the screen keyboard: what Tab does on a real keyboard — the next shape with its arrow.
    func nextShape() {
        guard thinkingIsOn, let id = editing, board.item(id)?.kind.isShape == true else { return }
        addNext(from: id, direction: board.flowDirection(at: id))
    }

    #if os(iOS)
    /// The shared typing field of the thing being typed in, if its kind has one (see `ThinkDesk.noteField`).
    var chainField: UUID? {
        guard let kind = editing.flatMap({ board.item($0)?.kind }) else { return nil }
        if kind == .note { return ThinkDesk.noteField }
        return kind.isShape ? ThinkDesk.shapeField : nil
    }
    #endif

    // Pick 11: turn into, a note becomes an idea, make a mind map, break into notes

    /// "Turn into": the chosen things become sticky notes, boxes, texts or ideas. They stay chosen.
    func turnChosen(into kind: ItemKind) {
        guard thinkingIsOn else { return }
        if editing != nil { commitEdit() }
        let ids = selection
        change(widen: ids) { $0.turn(ids, into: kind) }
    }

    /// A sticky note, a box or a text was dropped on an idea: it becomes an idea under that one, and a line
    /// with Undo says so. False when the dropped thing is none of the three (an idea hangs by its own rule).
    func becomeIdea(_ id: UUID, under target: UUID) -> Bool {
        guard board.canBecomeIdea(id) else { return false }
        guard change({ $0.makeIdea(id, under: target) }) else { return true }
        selection = [id]
        selectedLink = nil
        Feel.setDown()
        tell("Now an idea")
        return true
    }

    /// How many of the chosen things a mind map can be made of (sticky notes and texts).
    var mapMakerCount: Int { selection.count > 1 && thinkingIsOn ? board.mapMakers(selection).count : 0 }

    /// "Make a mind map": opens the small question for the middle idea, filled in with the board's name.
    func askMakeMap() {
        guard mapMakerCount >= 2 else { return }
        if editing != nil { commitEdit() }
        ThinkDesk.shared.middle = board.title
        ThinkDesk.shared.askingMap = true
    }

    /// Save in that question: the chosen notes become one mind map round the middle idea, which is then chosen.
    func makeMap(middle: String) {
        let ids = selection
        var centre: UUID?
        change { centre = $0.makeMap(of: ids, middle: middle) }
        guard let centre else { return }
        selection = [centre]
        selectedLink = nil
        reveal(centre)
    }

    /// "Break into notes": the idea and those under it become a column of sticky notes, which are then chosen.
    func breakIntoNotes(_ id: UUID) {
        guard thinkingIsOn else { return }
        if editing != nil { commitEdit() }
        var notes: [UUID] = []
        change { board in
            notes = board.breakIntoNotes(id)
            // Each note takes the height its words need; then they stand 16 apart.
            Lettering.fit(&board, facts: MapFacts(board))
            board.stackColumn(notes)
        }
        guard let first = notes.first else { return }
        selection = Set(notes)
        selectedLink = nil
        reveal(first)
    }

    // Pick 12: sort a pile

    /// How many of the chosen things a grid can be made of (sticky notes, shapes and texts).
    var gridCount: Int { selection.count > 2 && thinkingIsOn ? board.gridable(selection).count : 0 }

    func tidyGrid() {
        let ids = selection
        guard editing == nil else { return }
        // 0.9: the grid is columns about the square root of the count, pinned things stay (Views09.swift).
        change { $0.tidyIntoGrid(ids) }
    }

    func tidyByColour() {
        let ids = selection
        guard editing == nil else { return }
        change { $0.tidyByColour(ids) }
    }

    /// One colour for everything chosen that carries a colour.
    func colourChosen(_ name: String) {
        let ids = selection
        RecentColours.used(name)   // 0.19 (10)
        change { $0.setColour(name, of: ids) }
    }

    /// "Choose all of this colour": every sticky note with the paper of this one.
    func chooseNotes(colouredLike id: UUID) {
        let all = board.notes(colouredLike: id)
        guard !all.isEmpty else { return }
        if editing != nil { commitEdit() }
        selectedLink = nil
        selection = all
    }
}

// MARK: The bar and the menus

extension BarActions {
    /// A button of the bar with this number (or more) for `drop` is never in the row: it lives behind "…".
    static let behind = 99

    private func think(_ key: String, _ word: String, _ glyph: Glyph, show: BarAction.Show = .icon, on: Bool = false,
                       drop: Int = 0, gap: Bool = false, _ run: @escaping () -> Void) -> BarAction {
        let session = session
        return BarAction(id: prefix + key, word: word, glyph: glyph, kind: .press { run(); session.takeKeys() },
                         show: show, on: on, drop: drop, gap: gap)
    }

    private static func mark(of kind: ItemKind) -> Glyph {
        switch kind {
        case .note: return .app(.seedNote)
        case .text: return .app(.seedText)
        case .idea: return .app(.seedMindMap)
        default: return .app(.seedBox)
        }
    }

    /// "Turn into" with its short list (Sticky note, Box, Text, Idea — without what the chosen things already
    /// are); nil when nothing chosen can be turned.
    private func turnInto(drop: Int = 0) -> BarAction? {
        let session = session
        let kinds = session.board.turnChoices(for: session.selection)
        guard !kinds.isEmpty else { return nil }
        let choices = kinds.map { kind in
            think("turn.\(kind.rawValue)", kind.word, Self.mark(of: kind)) { session.turnChosen(into: kind) }
        }
        return BarAction(id: prefix + "turn", word: "Turn into", glyph: .new(.turnInto), kind: .choices(choices), drop: drop)
    }

    /// The colours several chosen things can take together; the ring is on only when all show the same colour.
    func severalColours() -> [BarAction] {
        let session = session
        let paint = Paint(night: night)
        let ids = session.selection
        let paper = session.board.colourable(ids).allSatisfy { $0.kind == .note }
        let inUse = session.board.sharedColour(of: ids)
        return RecentColours.ordered(session.board.coloursOffered(for: ids)).map { name in   // 0.19 (10)
            var one = think(name.isEmpty ? "colour.none" : "colour.\(name)", name.isEmpty ? "No colour" : name.capitalized,
                            .control(.circle), on: inUse == name) { session.colourChosen(name) }
            one.swatch = name.isEmpty ? paint.plate : (paper ? paint.note(name) : paint.line(name))
            one.hollow = name.isEmpty
            return one
        }
    }

    /// The bar of ONE chosen thing: "Turn into" goes behind the "…", before the hairline of To do and Remove.
    func withTurnInto(_ actions: [BarAction]) -> [BarAction] {
        guard let turn = turnInto(drop: Self.behind) else { return actions }
        var all = actions
        all.insert(turn, at: all.firstIndex { $0.gap } ?? all.count)
        return all
    }

    /// The bar of SEVERAL chosen things: Tidy (from three notes or shapes), Colour, Make a mind map (from two
    /// notes); and behind the "…": Turn into, By colour.
    func severalBar() -> [BarAction] {
        let session = session
        var all: [BarAction] = []
        let pile = session.gridCount >= 3
        if pile { all.append(think("tidy", "Tidy into a grid", .new(.tidy), show: .wideWord, drop: 3) { session.tidyGrid() }) }
        if let dots, !session.board.coloursOffered(for: session.selection).isEmpty {
            all.append(think("colour", "Colour", .app(.palette), show: .wideWord, on: dots.shown, drop: 2, dots.toggle))
        }
        if session.mapMakerCount >= 2 {
            all.append(think("makeMap", "Make a mind map", .app(.seedMindMap), show: .wideWord, drop: 4) { session.askMakeMap() })
        }
        if let turn = turnInto(drop: Self.behind) { all.append(turn) }
        if pile { all.append(think("byColour", "By colour", .new(.byColour), drop: Self.behind) { session.tidyByColour() }) }
        return all
    }

    /// The menu of SEVERAL chosen things: Tidy and By colour go on from Line up, Even gaps and Same size
    /// (`first`: there are none of those, so these begin the group); then Colour, Turn into, Make a mind map.
    func severalMenu(first: Bool) -> [BarAction] {
        let session = session
        var sort: [BarAction] = []
        if session.gridCount >= 3 {
            sort.append(think("tidy", "Tidy into a grid", .new(.tidy)) { session.tidyGrid() })
            sort.append(think("byColour", "By colour", .new(.byColour)) { session.tidyByColour() })
        }
        if first, !sort.isEmpty { sort[0].gap = true }
        var more: [BarAction] = []
        let colours = severalColours()
        if !colours.isEmpty {
            more.append(BarAction(id: prefix + "colour", word: "Colour", glyph: .app(.palette), kind: .choices(colours)))
        }
        if let turn = turnInto() { more.append(turn) }
        if session.mapMakerCount >= 2 {
            more.append(think("makeMap", "Make a mind map", .app(.seedMindMap)) { session.askMakeMap() })
        }
        if !more.isEmpty { more[0].gap = true }
        return sort + more
    }

    /// The menu of ONE thing: Turn into; for a sticky note "Choose all of this colour"; for an idea "Break into notes".
    func singleMenu(_ item: Item) -> [BarAction] {
        let session = session
        guard !session.readOnly, !session.board.placesItself else { return [] }
        var all: [BarAction] = []
        if let turn = turnInto() { all.append(turn) }
        if item.kind == .note {
            all.append(think("sameColour", "Choose all of this colour", .app(.seedSelectAll)) { session.chooseNotes(colouredLike: item.id) })
        }
        if item.kind == .idea {
            all.append(think("breakNotes", "Break into notes", .new(.breakNotes)) { session.breakIntoNotes(item.id) })
        }
        return all
    }
}

// MARK: For pictures

extension BoardSession {
    /// For pictures: `-think <step>` does one step with what `-pick` / `-pickAll` chose, a moment after the board
    /// is shown: `tidy`, `byColour`, `map` (Make a mind map, the board's name in the middle), `note` / `box` /
    /// `text` / `idea` (Turn into), `break` (Break into notes), `sameColour` (Choose all of this colour),
    /// `next` (starts typing in the chosen sticky note and makes the next note).
    func thinkForPicture(_ step: String) {
        switch step {
        case "tidy": tidyGrid()
        case "byColour": tidyByColour()
        case "map": makeMap(middle: board.title)
        case "note": turnChosen(into: .note)
        case "box": turnChosen(into: .box)
        case "text": turnChosen(into: .text)
        case "idea": turnChosen(into: .idea)
        case "break": if let item = single { breakIntoNotes(item.id) }
        case "sameColour": if let item = single { chooseNotes(colouredLike: item.id) }
        case "next":
            if let item = single {
                beginEdit(item.id)
                nextNote()
            }
        default: break
        }
    }
}

// MARK: The small question of "Make a mind map"

/// Lies on the board's extras (`BoardExtras`): the question "The middle idea" with Cancel and Save.
/// For pictures: `-makeMap` (with `-pickAll <words>`) opens it a moment after the board is shown.
struct ThinkingHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = ThinkDesk.shared
    private static var launchUsed = false

    func body(content: Content) -> some View {
        content
            .alert("The middle idea", isPresented: $desk.askingMap) {
                TextField("The middle idea", text: $desk.middle)
                    .accessibilityIdentifier("makeMap.field")
                Button("Cancel", role: .cancel) { session.takeKeys() }
                Button("Save") {
                    session.makeMap(middle: desk.middle)
                    session.takeKeys()
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("The \(session.mapMakerCount) chosen notes become the branches of one mind map round it.")
            }
            .onAppear {
                guard !Self.launchUsed else { return }
                Self.launchUsed = true
                if LaunchOptions.arguments.contains("-makeMap") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { session.askMakeMap() }
                }
                if let step = LaunchOptions.value(for: "-think") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { session.thinkForPicture(step) }
                }
            }
            .onDisappear { desk.askingMap = false }
    }
}

// MARK: Above the screen keyboard

#if os(iOS)
/// The bar above the screen keyboard while a sticky note or a shape is typed: "Next note" (as Tab) or
/// "Next shape" (as Tab), in the colour of notes or shapes, with the look of the idea buttons.
struct ThinkKeyBar: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        if !session.readOnly, !session.board.placesItself, let kind = session.editing.flatMap({ session.board.item($0)?.kind }) {
            // Whole words where there is room (iPad), short ones on a narrow screen (iPhone).
            let wide = session.viewSize.width >= 520
            if kind == .note {
                button(.nextNote, wide ? "Next note" : "Next", name: "Next note", id: "board.key.nextNote", part: .notes) { session.nextNote() }
            } else if kind.isShape {
                button(.nextShape, wide ? "Next shape" : "Next", name: "Next shape", id: "board.key.nextShape", part: .shapes) { session.nextShape() }
            }
        }
    }

    private func button(_ mark: NewMark, _ words: String, name: String, id: String, part: Part, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                GlyphView(glyph: .new(mark), size: 17, colour: part.text)
                Text(words)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(part.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(name)
        .accessibilityIdentifier(id)
    }
}
#endif
