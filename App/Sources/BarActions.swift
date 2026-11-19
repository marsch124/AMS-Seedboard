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

    func act(_ key: String, _ word: String, _ glyph: Glyph, show: BarAction.Show = .icon, tone: BarAction.Tone = .plain,
                     on: Bool = false, enabled: Bool = true, drop: Int = 0, gap: Bool = false, exact: String? = nil,
                     _ run: @escaping () -> Void) -> BarAction {
        let session = session
        return BarAction(id: exact ?? prefix + key, word: word, glyph: glyph,
                         kind: .press { run(); session.takeKeys() },
                         show: show, tone: tone, on: on, enabled: enabled, drop: drop, gap: gap)
    }

    private func list(_ key: String, _ word: String, _ glyph: Glyph, show: BarAction.Show = .icon, on: Bool = false,
                      drop: Int = 0, _ choices: [BarAction]) -> BarAction {
        BarAction(id: prefix + key, word: word, glyph: glyph, kind: .choices(choices), show: show, on: on, drop: drop)
    }

    // MARK: Pieces both the bar and the menus use

    /// A picture's caption (0.4): typed in place under the picture.
    private func caption(_ id: UUID, drop: Int = 1) -> BarAction {
        let session = session
        return act("caption", "Caption", .new(.caption), show: .wideWord, drop: drop) { session.beginCaption(id) }
    }

    /// 0.11: "Copy words" and "Words to a note" for a picture whose found words are not empty.
    private func pictureWordsActions(_ item: Item) -> [BarAction] {
        let session = session, id = item.id, words = item.foundWords
        return [
            act("copywords", "Copy words", .new(.makeTyped), show: .wideWord, drop: 4) {
                AppModel.shared.copyText(words)
                AppModel.shared.say("Words copied", seconds: 2)
            },
            act("wordsnote", "Words to a note", .new(.readThis), show: .wideWord, drop: 5) {
                session.commitEdit()
                var made: UUID?
                session.change { made = $0.noteWithPictureWords(id) }
                if let made { session.selection = [made] }
            },
        ]
    }

    /// Crop a picture (0.4): opens "Crop the picture". Greyed while the picture's file is not here yet.
    private func crop(_ item: Item, drop: Int = 2) -> BarAction {
        let session = session, id = item.id
        let here = item.picture.map { PictureStore.shared.image($0) != nil } ?? false
        return act("crop", "Crop", .new(.crop), show: .wideWord, enabled: here, drop: drop) { session.commitEdit(); session.cropping = id }
    }

    /// "Make typed" (0.9): a chosen sketch's handwriting becomes a Text thing with the words (InkWords.swift).
    private func makeTyped(_ id: UUID, drop: Int = 1) -> BarAction {
        let session = session
        return act("totext", "Make typed", .new(.makeTyped), show: .wideWord, drop: drop, exact: "ink.totext") { session.makeTyped(id) }
    }

    /// "Read this" (0.11): the sketch's handwriting becomes a sticky note beside it; the sketch stays.
    private func readThis(_ id: UUID, drop: Int = 1) -> BarAction {
        let session = session
        return act("readthis", "Read this", .new(.readThis), show: .wideWord, drop: drop, exact: "ink.readthis") { session.readThis(id) }
    }

    /// "Draw on it" (0.9): the Draw tool opens with this picture as its target.
    private func drawOn(_ id: UUID, drop: Int = 1) -> BarAction {
        let session = session
        return act("draw", "Draw on it", .new(.drawOnIt), show: .wideWord, drop: drop, exact: "picture.draw") { session.drawOnPicture(id) }
    }

    private func words(_ id: UUID, show: BarAction.Show = .wideWord, drop: Int = 1) -> BarAction {
        let session = session
        return act("words", "Words", .control(.edit), show: show, drop: drop) { session.beginEdit(id) }
    }

    private func todo(on: Bool, show: BarAction.Show = .wideWord, gap: Bool = true) -> BarAction {
        let session = session
        return act("todo", "To do", .control(.circle), show: show, tone: .todo, on: on, gap: gap) { session.toggleTodo() }
    }

    /// 0.9 (pick 42): "Today's three" — up to three chosen things go to PARAGON's Inbox as tasks due today.
    /// Not there when more than three are chosen (or nothing chosen can be a task).
    private func todayThree(drop: Int = 6) -> [BarAction] {
        let session = session
        guard session.todayThreeOffered else { return [] }
        return [act("today.three", "Today's three", .new(.today), show: .wideWord, tone: .todo, drop: drop) { ParagonDesk.shared.askToday(session) }]
    }

    /// 0.9 (pick 40): "Send this frame to PARAGON…" — opens the Send page with only this frame's things.
    private func sendFrame(drop: Int = 3) -> [BarAction] {
        let session = session
        guard session.frameToSend != nil else { return [] }
        return [act("sendFrame", "Send this frame to PARAGON…", .app(.send), show: .wideWord, tone: .todo, drop: drop) { ParagonDesk.shared.sendFrame(session) }]
    }

    // MARK: 0.14 — a table

    /// "Add row", "Add column", "Remove row", "Remove column": they act on the row and the column of the cell typed in
    /// last, else on the last row and the last column. A table keeps at least one row and one column.
    private func tableLines(_ item: Item, menu: Bool = false) -> [BarAction] {
        let session = session, id = item.id
        let canRow = TableRules.canRemoveRow(TableRules.squared(item.cells)), canColumn = TableRules.canRemoveColumn(TableRules.squared(item.cells))
        var all = [
            act("table.addRow", "Add row", .control(.add), show: .word) { session.tableStep(id, .addRow) },
            act("table.addColumn", "Add column", .control(.add), show: .word) { session.tableStep(id, .addColumn) },
            act("table.removeRow", "Remove row", .control(.minusCircle), show: .wideWord, enabled: canRow, drop: 1) { session.tableStep(id, .removeRow) },
            act("table.removeColumn", "Remove column", .control(.minusCircle), show: .wideWord, enabled: canColumn, drop: 1) { session.tableStep(id, .removeColumn) },
        ]
        if !menu { all.append(words(id, show: .wideWord)) }
        return all
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

    // MARK: 0.9 marks — Vote, Pin in place, Tick list, Open link (MarksSession.swift)

    /// The lines for what is chosen. `full`: a menu (also "Remove a dot" and "Clear dots"); the bar has the short ones.
    private func marks(full: Bool) -> [BarAction] {
        let session = session
        guard session.marksOn, !session.selection.isEmpty else { return [] }
        let chosen = session.selection.compactMap { session.board.item($0) }
        var all: [BarAction] = []
        var first = true
        func put(_ action: BarAction) {
            var one = action
            if first { one.gap = true; first = false }
            all.append(one)
        }
        put(act("vote.add", "Vote", .new(.vote), show: .wideWord, drop: 6) { session.vote() })
        if full {
            let hasDots = chosen.contains { ($0.votes ?? 0) > 0 }
            put(act("vote.remove", "Remove a dot", .app(.minus), enabled: hasDots) { session.removeDot() })
            put(act("vote.clear", "Clear dots", .app(.minus), enabled: hasDots) { session.clearDots() })
        }
        let pinned = session.board.allPinned(session.selection)
        put(act("pin.toggle", pinned ? "Unpin" : "Pin in place", .app(.seedPin), show: .wideWord, on: pinned, drop: 6) { session.togglePinned() })
        if chosen.allSatisfy({ $0.kind == .note }) {
            let ticked = chosen.allSatisfy { TickList.hasTicks($0.text) }
            put(act("tick.list", "Tick list", .new(.tickList), show: .wideWord, on: ticked, drop: 6) { session.tickList() })
        }
        if chosen.count == 1, let item = chosen.first, WebAddress.first(in: item.text) != nil {
            let id = item.id
            put(act("link.open", "Open link", .app(.openLink), show: .wideWord, drop: 6) { session.openLink(id) })
        }
        return all
    }

    /// The marks go in just before "Remove" (which stays last).
    private func withMarks(_ list: [BarAction], full: Bool) -> [BarAction] {
        let extra = marks(full: full)
        guard !extra.isEmpty, !list.isEmpty else { return list }
        var all = list
        let at = all.lastIndex { $0.id == prefix + "remove" } ?? all.count
        all.insert(contentsOf: extra, at: at)
        return all
    }

    /// The colours a thing or an arrow can take, the one in use switched on.
    func colourChoices(for item: Item?, link: SeedboardCore.Link?) -> [BarAction] {
        let session = session
        let paint = Paint(night: night)
        let isNote = item?.kind == .note
        let names = isNote ? Palette.notes : Palette.names
        let plain = item.map { $0.kind.isShape || $0.kind == .drawing } ?? (link != nil)
        let inUse = (item?.id ?? link?.id).flatMap { session.board.colourInUse(of: $0) }
        var all: [BarAction] = []
        if plain {
            var none = act("colour.none", "No colour", .control(.circle), on: inUse == "") { session.setColour("") }
            none.swatch = paint.plate
            none.hollow = true
            all.append(none)
        }
        for name in names {
            // 0.11: a note's colour carries the legend's word when the board names it ("Question", not "Yellow").
            let word = (isNote ? session.board.legendWord(forColour: name) : nil) ?? name.capitalized
            var one = act("colour.\(name)", word, .control(.circle), on: inUse == name) { session.setColour(name) }
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
            return ChosenBarModel(part: BarActions.part(of: item.kind), label: nil, actions: withMarks(itemBar(item), full: false))
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
        // 0.5: Tidy, Colour, Make a mind map; behind "…": Turn into, By colour (Thinking.swift).
        actions += severalBar()
        actions.append(duplicate())
        actions += chooseMore(drop: 2)
        actions.append(todo(on: session.selection.allSatisfy { session.board.item($0)?.todo == true }))
        actions += todayThree()
        actions.append(remove())
        return ChosenBarModel(part: kinds.count == 1 ? kinds.first! : .boards, label: "\(session.selection.count) chosen", actions: withMarks(actions, full: false))
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
                if session.board.canBalance(item.id) {
                    all.append(act("balance", "Balance", .new(.balance), show: .wideWord, drop: 3) { session.balanceMap() })
                }
                // 0.11: one press folds the map to its main branches; pressed again it opens all (Extras11.swift).
                if let overview = mainBranchesAction(item) { all.append(overview) }
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
            all.append(focusAction(show: .word, drop: 2))
            all.append(colour(for: item, show: .word))
            all.append(words(item.id))
            all.append(duplicate())
            all += chooseMore()
            all += sendFrame()
            all.append(remove(gap: true))
            return all
        case .table:
            // 0.14: Add row, Add column, Remove row, Remove column, then Colour, Duplicate, Remove (no tick: a table is no to-do).
            all += tableLines(item)
            all.append(colour(for: item, show: .wideWord, drop: 2))
            all.append(duplicate())
            all += chooseMore()
            all.append(remove(gap: true))
            return all
        case .picture:
            // A picture has no words, no tick and no colour: a caption under it, a crop, copy it, line it up, remove it.
            all.append(drawOn(item.id, drop: 1))
            all.append(caption(item.id, drop: 2))
            all.append(crop(item, drop: 3))
            // 0.11: the words found inside the picture; only offered when there are some.
            if !item.foundWords.isEmpty { all += pictureWordsActions(item) }
            all.append(duplicate(drop: 0))
            all += chooseMore()
            all.append(remove(gap: true))
            return all
        case .drawing:
            // A sketch (0.9): its colour, its handwriting as typed words, copy it, remove it.
            all.append(colour(for: item, show: .wideWord, drop: 2))
            all.append(makeTyped(item.id, drop: 1))
            all.append(readThis(item.id, drop: 2))
            all.append(duplicate(drop: 0))
            all += chooseMore()
            all.append(remove(gap: true))
            return all
        case .door:
            // A door (0.5, Doors.swift): open its board; it has no words, no tick and no colour of its own.
            all += doorLines(item)
            all.append(duplicate(drop: 0))
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
        all += todayThree()
        all.append(remove())
        // 0.5: "Turn into" behind the "…" (Thinking.swift).
        return withTurnInto(all)
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
            all += todayThree()
            copy.gap = true
            all += [copy, cut, twin]
            var tidy: [BarAction] = []
            if session.tidyCount >= 2 { tidy.append(act("lineUp", "Line up", .new(.lineUp)) { session.lineUp() }) }
            if session.tidyCount >= 3 { tidy.append(act("evenGaps", "Even gaps", .new(.evenGaps)) { session.evenGaps() }) }
            if session.sizeCount >= 2 { tidy.append(act("sameSize", "Same size", .new(.sameSize)) { session.sameSize() }) }
            if !tidy.isEmpty { tidy[0].gap = true }
            all += tidy
            // 0.5: Tidy, By colour, Colour, Turn into, Make a mind map (Thinking.swift).
            all += severalMenu(first: tidy.isEmpty)
            all += moveOutLines()
            all.append(remove(gap: true))
            return withMarks(all, full: true)
        }
        // 0.14: a table has its own lines.
        if item.kind == .table { return withMarks(tableLines(item, menu: true) + [colour(for: item), copy, cut, twin, remove(gap: true)], full: true) }
        // A door has its own lines (0.5, Doors.swift).
        if item.kind == .door { return withMarks(doorMenu(item, [copy, cut, twin]) + [remove(gap: true)], full: true) }
        // (A sketch has no words and carries no tick.)
        if item.kind != .drawing && item.kind != .picture { all.append(words(item.id)) }
        if item.kind == .picture { all += [drawOn(item.id), caption(item.id), crop(item)] }
        if item.kind == .drawing { all.append(makeTyped(item.id)); all.append(readThis(item.id)) }
        let isBranch = item.kind == .idea && item.parent != nil
        if item.kind.isShape || item.kind == .note || item.kind == .frame || item.kind == .drawing || isBranch { all.append(colour(for: item)) }
        if item.kind != .frame && item.kind != .drawing && item.kind != .picture { all.append(todo(on: item.todo, gap: false)) }
        all += todayThree()
        all += sendFrame()
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
                more.append(act("fold", item.folded ? "Unfold branch" : "Fold branch", .control(.chevron)) { session.toggleFold() })
            }
            if session.board.hasFolded {
                more.append(act("unfoldAll", "Unfold all", .control(.chevron)) { session.unfoldAll() })
            }
            if item.parent == nil, session.board.canBalance(item.id) {
                more.append(act("balance", "Balance", .new(.balance)) { session.balanceMap() })
            }
        case .frame:
            more.append(list("lanes", "Lanes", .new(.lanes), on: item.lanes != nil, laneChoices(item)))
            more.append(focusAction())
        default:
            if item.kind.isShape {
                let kinds = ItemKind.flowShapes.map { kind in
                    act("shape.\(kind.rawValue)", kind.word, kind.mark, on: kind == item.kind) { session.setKind(kind) }
                }
                more.append(list("shape", "Shape", item.kind.mark, kinds))
            }
        }
        // 0.5: Turn into, Choose all of this colour, Break into notes (Thinking.swift).
        more += singleMenu(item)
        if !more.isEmpty { more[0].gap = true }
        all += more
        all += moveOutLines()
        all.append(remove(gap: true))
        return withMarks(all, full: true)
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

    /// 0.9: the right-click menu of a timeline (the Mac): Fold / Unfold for the phase under the pointer, then the board's.
    func timelineMenu(phase: Item?) -> [BarAction] {
        let session = session
        var all: [BarAction] = []
        if !session.readOnly {
            if let phase, session.board.canFold(phase.id) {
                all.append(act("fold", phase.folded ? "Unfold" : "Fold", .control(.chevron)) { session.toggleTimelineFold(phase.id) })
            }
            all.append(act("foldAll", "Fold all phases", .control(.chevron), enabled: session.board.canFoldAny, gap: !all.isEmpty) { session.foldAllTimelinePhases(true) })
            all.append(act("unfoldAll", "Unfold all", .control(.chevron), enabled: session.board.canUnfoldAny) { session.foldAllTimelinePhases(false) })
        }
        if session.canAddToCalendar {
            all.append(act("calendar", "Add to Calendar…", .new(.calendar), gap: !all.isEmpty) { AppModel.shared.showCalendar = true })
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
            all.append(act("picture", "Picture…", .new(.picture)) { PictureDesk.shared.ask.send(spot) })
            all.append(act("table", "New table here", .control(.add)) { session.add(.table, at: spot) })   // 0.14
            all += doorMenuLines(at: spot)
        }
        all.append(act("selectAll", "Select all", .app(.seedSelectAll), enabled: !session.board.isEmpty, gap: !all.isEmpty) { session.selectAll() })
        all.append(act("fit", "Show the whole board", .app(.seedFit)) { session.fit() })
        return all
    }
}
