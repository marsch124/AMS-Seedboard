import SwiftUI
import SeedboardCore
import AMSIcons

// What can be done with what is chosen — one list that the bar beside the chosen thing, its "…"
// list, the right-click menu of the Mac and the press-and-hold menu of iPhone and iPad are all
// made from (0.2, picks 7 and 18).

/// One thing that can be done: a button of the bar, a line of a menu.
struct BarAction: Identifiable {
    enum Tone {
        /// The colour of the chosen kind's part.
        case plain
        /// "To do": PARAGON's purple.
        case todo
        /// "Remove": red.
        case remove
    }

    /// How it shows in the bar.
    enum Show {
        /// Its mark and its word, on every device.
        case word
        /// Its mark and its word on the Mac and the iPad; only its mark on the iPhone.
        case wideWord
        /// Only its mark.
        case icon
    }

    indirect enum Kind {
        case press(() -> Void)
        /// Opens a short list to pick from ("Line", "Ends"; in a menu also the colours, the shapes, the lanes).
        case choices([BarAction])
        /// "Shape" in the bar of a chosen shape: opens the plate with all shapes.
        case shape(Item)
        /// "Lanes" in the bar of a chosen frame: opens the lanes plate.
        case lanes(Item)
    }

    /// The accessibility identifier ("sel.words", "menu.words").
    let id: String
    var word: String
    var glyph: Glyph
    var kind: Kind
    var show = Show.icon
    var tone = Tone.plain
    /// Switched on (To do, Dashed, Choose more) or the one in use (a colour, a line style).
    var on = false
    var enabled = true
    /// When the bar is too narrow for one row, the buttons with the highest number go into the
    /// "…" list first. 0: always in the bar.
    var drop = 0
    /// A thin line stands before it (in the bar: a hairline; in a menu: a separator).
    var gap = false
    /// A colour to pick: a dot of this colour stands in place of the mark.
    var swatch: Color?
    /// The colour "none": an empty ring.
    var hollow = false
}

/// The bar for what is chosen: its tint, an optional line of words in front, its buttons.
struct ChosenBarModel {
    var part: Part
    var label: String?
    var actions: [BarAction]
}

@MainActor
struct BarActions {
    let session: BoardSession
    /// "sel." in the bar, "menu." in the right-click and press-and-hold menu.
    var prefix = "sel."
    /// The bar shows the colours as a row of dots under itself: whether it is open, and how to open
    /// and close it. nil: a menu — the colours are a list to pick from.
    var dots: (shown: Bool, toggle: () -> Void)?
    var night = false

    /// The part of the app a kind of thing belongs to: its bar and its menu wear that colour.
    static func part(of kind: ItemKind) -> Part {
        switch kind {
        case .idea: return .mindMap
        case .note: return .notes
        case .text: return .text
        case .frame: return .frames
        case .bar, .milestone, .phase: return .timeline
        case .who, .message, .band, .section: return .sequence
        case .drawing: return .drawing
        case .picture: return .pictures
        default: return kind.isShape ? .shapes : .boards
        }
    }

    private func act(_ key: String, _ word: String, _ glyph: Glyph, show: BarAction.Show = .icon, tone: BarAction.Tone = .plain,
                     on: Bool = false, enabled: Bool = true, drop: Int = 0, gap: Bool = false, _ run: @escaping () -> Void) -> BarAction {
        let session = session
        return BarAction(id: prefix + key, word: word, glyph: glyph,
                         kind: .press { run(); session.takeKeys() },
                         show: show, tone: tone, on: on, enabled: enabled, drop: drop, gap: gap)
    }

    private func list(_ key: String, _ word: String, _ glyph: Glyph, show: BarAction.Show = .icon, on: Bool = false,
                      drop: Int = 0, _ choices: [BarAction]) -> BarAction {
        BarAction(id: prefix + key, word: word, glyph: glyph, kind: .choices(choices), show: show, on: on, drop: drop)
    }

    // MARK: Pieces both the bar and the menus use

    private func words(_ id: UUID, show: BarAction.Show = .wideWord, drop: Int = 1) -> BarAction {
        let session = session
        return act("words", "Words", .control(.edit), show: show, drop: drop) { session.beginEdit(id) }
    }

    private func todo(on: Bool, show: BarAction.Show = .wideWord, gap: Bool = true) -> BarAction {
        let session = session
        return act("todo", "To do", .control(.ticked), show: show, tone: .todo, on: on, gap: gap) { session.toggleTodo() }
    }

    private func duplicate(drop: Int = 4) -> BarAction {
        let session = session
        return act("copy", "Duplicate", .app(.duplicate), show: .wideWord, drop: drop) { session.duplicateSelection() }
    }

    private func remove(gap: Bool = false) -> BarAction {
        let session = session
        return act("remove", "Remove", .app(.bin), tone: .remove, gap: gap) { session.deleteSelection() }
    }

    /// iPhone and iPad: each press adds to what is chosen, and a finger drag on empty board draws the choosing box.
    private func chooseMore(drop: Int = 3) -> [BarAction] {
        #if os(macOS)
        return []
        #else
        let session = session
        return [act("more", "Choose more", .control(.addCircle), on: session.choosingMore, drop: drop) { session.choosingMore.toggle() }]
        #endif
    }

    /// The colours a thing or an arrow can take, the one in use switched on.
    func colourChoices(for item: Item?, link: SeedboardCore.Link?) -> [BarAction] {
        let session = session
        let paint = Paint(night: night)
        let isNote = item?.kind == .note
        let names = isNote ? Palette.notes : Palette.names
        let plain = item.map { $0.kind.isShape } ?? (link != nil)
        let inUse = (item?.id ?? link?.id).flatMap { session.board.colourInUse(of: $0) }
        var all: [BarAction] = []
        if plain {
            var none = act("colour.none", "No colour", .control(.circle), on: inUse == "") { session.setColour("") }
            none.swatch = paint.plate
            none.hollow = true
            all.append(none)
        }
        for name in names {
            var one = act("colour.\(name)", name.capitalized, .control(.circle), on: inUse == name) { session.setColour(name) }
            one.swatch = isNote ? paint.note(name) : paint.line(name)
            all.append(one)
        }
        return all
    }

    private func colour(for item: Item?, link: SeedboardCore.Link? = nil, show: BarAction.Show = .wideWord, drop: Int = 2) -> BarAction {
        if let dots {
            return act("colour", "Colour", .app(.palette), show: show, on: dots.shown, drop: drop, dots.toggle)
        }
        return list("colour", "Colour", .app(.palette), colourChoices(for: item, link: link))
    }

    /// The small drawing of an arrow's line: with right angles, straight or curved.
    static func mark(of style: LinkStyle) -> AppMark {
        switch style {
        case .elbow: return .seedLineElbow
        case .straight: return .seedLineStraight
        case .curve: return .seedLineCurved
        }
    }

    private func lineChoices(_ link: SeedboardCore.Link) -> [BarAction] {
        let session = session
        return LinkStyle.allCases.map { style in
            act("style.\(style.rawValue)", style.word, .app(Self.mark(of: style)), on: link.style == style) { session.setLinkStyle(style) }
        }
    }

    private func endChoices(_ link: SeedboardCore.Link) -> [BarAction] {
        let session = session
        return LinkEnds.allCases.map { ends in
            act("ends.\(ends.rawValue)", ends.word, .new(ends.mark), on: link.ends == ends) { session.setLinkEnds(ends) }
        }
    }

    // MARK: The bar

    /// The bar for what is chosen now; nil when nothing is chosen or the board cannot be changed.
    func bar() -> ChosenBarModel? {
        let session = session
        guard !session.readOnly, !session.board.placesItself else { return nil }
        if let item = session.single {
            return ChosenBarModel(part: BarActions.part(of: item.kind), label: nil, actions: itemBar(item))
        }
        if let id = session.selectedLink, let link = session.board.links.first(where: { $0.id == id }) {
            return ChosenBarModel(part: .arrows, label: nil, actions: linkBar(link))
        }
        guard !session.selection.isEmpty else { return nil }
        // Several things: the colour of their kind when they are all of one kind.
        let kinds = Set(session.selection.compactMap { session.board.item($0)?.kind }.map { BarActions.part(of: $0) })
        var actions: [BarAction] = []
        if session.tidyCount >= 2 { actions.append(act("lineUp", "Line up", .new(.lineUp), show: .wideWord, drop: 3) { session.lineUp() }) }
        if session.tidyCount >= 3 { actions.append(act("evenGaps", "Even gaps", .new(.evenGaps), show: .wideWord, drop: 3) { session.evenGaps() }) }
        if session.sizeCount >= 2 { actions.append(act("sameSize", "Same size", .new(.sameSize), show: .wideWord, drop: 3) { session.sameSize() }) }
        actions.append(duplicate())
        actions += chooseMore(drop: 2)
        actions.append(todo(on: session.selection.allSatisfy { session.board.item($0)?.todo == true }))
        actions.append(remove())
        return ChosenBarModel(part: kinds.count == 1 ? kinds.first! : .boards, label: "\(session.selection.count) chosen", actions: actions)
    }

    private func itemBar(_ item: Item) -> [BarAction] {
        let session = session
        var all: [BarAction] = []
        switch item.kind {
        case .idea:
            all.append(act("child", "Idea under", .new(.ideaUnder), show: .word) { session.addChild(of: item.id) })
            if item.parent != nil {
                all.append(act("sister", "Next idea", .new(.nextIdea), show: .word) { session.addSister(of: item.id) })
            }
            all.append(words(item.id))
            if (session.facts.children[item.id] ?? 0) > 0 {
                all.append(act("fold", item.folded ? "Unfold" : "Fold", .control(.chevron), show: .wideWord, drop: 3) { session.toggleFold() })
            }
            if item.parent == nil {
                all.append(act("sides", item.bothSides ? "One side" : "Both sides", .app(.seedMindMap), show: .wideWord, drop: 3) { session.toggleBothSides() })
            } else {
                all.append(colour(for: item))
                #if !os(macOS)
                // Another place among its sisters (the Mac has ⌘↑ and ⌘↓ and the Board menu).
                let up = session.board.canShiftIdea(item.id, down: false), down = session.board.canShiftIdea(item.id, down: true)
                all.append(act("moveUp", "Move up", .new(.moveUp), enabled: up, drop: 5) { session.shiftIdea(item.id, down: false) })
                all.append(act("moveDown", "Move down", .new(.moveDown), enabled: down, drop: 5) { session.shiftIdea(item.id, down: true) })
                #endif
            }
            all.append(duplicate())
            all += chooseMore(drop: 2)
            all.append(todo(on: item.todo))
        case .note:
            all.append(colour(for: item, show: .word))
            all.append(words(item.id, show: .word))
            all.append(duplicate())
            all += chooseMore()
            all.append(todo(on: item.todo))
        case .text:
            all.append(words(item.id, show: .word))
            all.append(duplicate())
            all += chooseMore()
            all.append(todo(on: item.todo))
        case .frame:
            all.append(BarAction(id: prefix + "lanes", word: "Lanes", glyph: .new(.lanes), kind: .lanes(item), show: .word, on: item.lanes != nil))
            all.append(colour(for: item, show: .word))
            all.append(words(item.id))
            all.append(duplicate())
            all += chooseMore()
            all.append(remove(gap: true))
            return all
        case .bar, .milestone, .phase:
            // A timeline's rows have their own bar (TimelineBars.swift).
            return []
        case .who, .message, .band, .section:
            // So have the things of a "Who does what" board (SequenceBars.swift).
            return []
        default:
            if item.kind.isShape {
                all.append(BarAction(id: prefix + "shape", word: "Shape", glyph: item.kind.mark, kind: .shape(item), show: .word))
                all.append(colour(for: item, show: .word))
                all.append(words(item.id))
                all.append(duplicate())
                all += chooseMore()
                all.append(todo(on: item.todo))
            } else {
                // A kind of thing that has no bar of its own yet: it can at least be copied and removed.
                all.append(duplicate(drop: 0))
                all += chooseMore()
                all.append(remove(gap: true))
                return all
            }
        }
        all.append(remove())
        return all
    }

    private func linkBar(_ link: SeedboardCore.Link) -> [BarAction] {
        let session = session
        var all: [BarAction] = [
            words(link.id, show: .word, drop: 0),
            list("line", "Line", .app(Self.mark(of: link.style)), show: .word, lineChoices(link)),
            list("ends", "Ends", .new(link.ends.mark), show: .word, endChoices(link)),
            act("dashed", "Dashed", .new(.dashed), show: .wideWord, on: link.isDashed, drop: 3) { session.toggleLinkDashed() },
            act("turn", "Turn round", .app(.repeat), show: .wideWord, drop: 3) { session.turnLinkRound() },
            colour(for: nil, link: link),
        ]
        all += chooseMore(drop: 4)
        all.append(remove(gap: true))
        return all
    }

    // MARK: The menus (right-click, press and hold)

    /// The menu of a thing: the pressed one, or everything chosen when it is one of several.
    func thingMenu() -> [BarAction] {
        let session = session
        var all: [BarAction] = []
        let canChange = !session.readOnly
        var copy = act("copy", "Copy", .app(.seedCopy), enabled: ClipBoard.canCopy(session)) { ClipBoard.copy(session) }
        guard canChange else { return [copy] }
        let cut = act("cut", "Cut", .new(.cut), enabled: ClipBoard.canCut(session)) { ClipBoard.cut(session) }
        let twin = act("duplicate", "Duplicate", .app(.duplicate)) { session.duplicateSelection() }
        guard let item = session.single else {
            // Several things.
            all.append(todo(on: session.selection.allSatisfy { session.board.item($0)?.todo == true }, gap: false))
            copy.gap = true
            all += [copy, cut, twin]
            var tidy: [BarAction] = []
            if session.tidyCount >= 2 { tidy.append(act("lineUp", "Line up", .new(.lineUp)) { session.lineUp() }) }
            if session.tidyCount >= 3 { tidy.append(act("evenGaps", "Even gaps", .new(.evenGaps)) { session.evenGaps() }) }
            if session.sizeCount >= 2 { tidy.append(act("sameSize", "Same size", .new(.sameSize)) { session.sameSize() }) }
            if !tidy.isEmpty { tidy[0].gap = true }
            all += tidy
            all.append(remove(gap: true))
            return all
        }
        // (A sketch has no words and carries no tick.)
        if item.kind != .drawing { all.append(words(item.id)) }
        let isBranch = item.kind == .idea && item.parent != nil
        if item.kind.isShape || item.kind == .note || item.kind == .frame || isBranch { all.append(colour(for: item)) }
        if item.kind != .frame && item.kind != .drawing { all.append(todo(on: item.todo, gap: false)) }
        copy.gap = true
        all += [copy, cut, twin]
        var more: [BarAction] = []
        if item.kind != .frame {
            more.append(act("arrow", "Arrow from here", .app(.seedArrow)) {
                session.commitEdit()
                session.linking = true
                session.linkFrom = item.id
            })
        }
        switch item.kind {
        case .idea:
            more.append(act("child", "Idea under", .new(.ideaUnder)) { session.addChild(of: item.id) })
            if item.parent != nil { more.append(act("sister", "Next idea", .new(.nextIdea)) { session.addSister(of: item.id) }) }
            if (session.facts.children[item.id] ?? 0) > 0 {
                more.append(act("fold", item.folded ? "Unfold" : "Fold", .control(.chevron)) { session.toggleFold() })
            }
        case .frame:
            more.append(list("lanes", "Lanes", .new(.lanes), on: item.lanes != nil, laneChoices(item)))
        default:
            if item.kind.isShape {
                let kinds = ItemKind.flowShapes.map { kind in
                    act("shape.\(kind.rawValue)", kind.word, kind.mark, on: kind == item.kind) { session.setKind(kind) }
                }
                more.append(list("shape", "Shape", item.kind.mark, kinds))
            }
        }
        if !more.isEmpty { more[0].gap = true }
        all += more
        all.append(remove(gap: true))
        return all
    }

    private func laneChoices(_ item: Item) -> [BarAction] {
        let session = session
        var all = [act("lanes.none", "No lanes", .app(.seedFrame), on: item.lanes == nil) { session.setLanes(nil) }]
        for way in Lanes.Way.allCases {
            let counts = (Lanes.fewest...Lanes.most).map { n in
                act("lanes.\(way.rawValue).\(n)", "\(n) \(way.word.lowercased())", .new(.lanes),
                    on: item.lanes?.way == way && item.lanes?.count == n) { session.setLanes(way, count: n) }
            }
            all.append(list("lanes.\(way.rawValue)", way.word, .new(.lanes), on: item.lanes?.way == way, counts))
        }
        return all
    }

    /// The menu of a chosen arrow.
    func arrowMenu(_ link: SeedboardCore.Link) -> [BarAction] {
        let session = session
        guard !session.readOnly else { return [] }
        return [
            words(link.id),
            list("line", "Line", .app(Self.mark(of: link.style)), lineChoices(link)),
            list("ends", "Ends", .new(link.ends.mark), endChoices(link)),
            act("dashed", "Dashed", .new(.dashed), on: link.isDashed) { session.toggleLinkDashed() },
            act("turn", "Turn round", .app(.repeat)) { session.turnLinkRound() },
            colour(for: nil, link: link),
            remove(gap: true),
        ]
    }

    /// The menu of empty board: everything acts at the pressed spot (board points).
    func emptyMenu(at spot: CGPoint) -> [BarAction] {
        let session = session
        var all: [BarAction] = []
        if !session.readOnly {
            all.append(act("paste", "Paste", .new(.paste), enabled: ClipBoard.canPaste(session)) { ClipBoard.paste(session, at: spot) })
            all.append(act("note", "New note here", .app(.seedNote), gap: true) { session.add(.note, at: spot) })
            all.append(act("box", "New box here", .app(.seedBox)) { session.add(.box, at: spot) })
            all.append(act("idea", "New idea here", .app(.seedMindMap)) { session.add(.idea, at: spot) })
        }
        all.append(act("selectAll", "Select all", .app(.seedSelectAll), enabled: !session.board.isEmpty, gap: !all.isEmpty) { session.selectAll() })
        all.append(act("fit", "Show the whole board", .app(.seedFit)) { withAnimation(.easeOut(duration: 0.2)) { session.fit() } })
        return all
    }
}
