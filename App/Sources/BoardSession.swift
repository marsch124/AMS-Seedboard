import SwiftUI
import Combine
import SeedboardCore

/// The board that is open: what is chosen, what is being typed, where the view stands,
/// and the steps that can be undone. Every change to the board goes through here.
@MainActor
final class BoardSession: ObservableObject {
    @Published private(set) var board: Board
    private(set) var facts: MapFacts

    @Published var selection: Set<UUID> = []
    @Published var selectedLink: UUID?
    /// The item or arrow being typed in.
    @Published private(set) var editing: UUID?
    @Published private(set) var draft = ""
    /// Where the board stands on screen, and whether the owner has moved it.
    @Published private(set) var place = Viewport()
    /// Where the board's zero point is on screen, and how big one board point is.
    var offset: CGSize {
        get { place.offset }
        // The timeline places its days itself (TimelineSession.swift).
        set { place.offset = newValue }
    }
    var scale: CGFloat { CGFloat(place.scale) }
    var viewSize: CGSize { place.size }
    /// The arrow tool is on: the next two shapes pressed are joined.
    @Published var linking = false
    @Published var linkFrom: UUID?
    /// iPhone and iPad: each press adds to what is chosen (the Mac holds Shift instead).
    @Published var choosingMore = false
    /// The picture whose "Crop the picture" page is open (CropPage.swift).
    @Published var cropping: UUID?
    /// The name of a frame's lane is being typed (LanesView.swift).
    @Published var laneTyping: LaneTyping?
    @Published private(set) var undoCount = 0
    @Published private(set) var redoCount = 0
    /// Timeline boards only: the scale of the days (see TimelineSession.swift).
    @Published var timeline = TimelineLook()
    /// Drawing by hand: the Draw tool, pen or rubber, thickness, colour, and the running line (InkDesk.swift).
    let ink = InkDesk()
    /// 0.5: the glide of the view and the things on their way (BoardGlide.swift, BoardMotion.swift).
    let motion = BoardMotion()
    /// 0.9: Focus on a frame, Show frames, the small map (ViewsDesk.swift).
    lazy var views = ViewsDesk { [weak self] in self?.objectWillChange.send() }

    /// A short line with an Undo button, after a step the owner may not have meant.
    struct Notice: Equatable {
        let id = UUID()
        let words: String
    }
    @Published private(set) var notice: Notice?
    private var noticeWork: DispatchWorkItem?

    /// The board asks for the keys back (after a button, a menu or a page).
    let keysWanted = PassthroughSubject<Void, Never>()
    func takeKeys() { keysWanted.send() }

    /// Shift and Return was pressed: the next line break typed is a new line, in an idea too.
    private var lineBreakWanted = false
    private var undoStack: [Board] = []
    private var redoStack: [Board] = []
    /// 0.9: when each step in `undoStack` / `redoStack` was taken (same order), for the Undo list.
    private var undoTimes: [Date] = []
    /// 0.11: a rough size of each step in `undoStack` (same order), see `UndoBudget`.
    private var undoWeights: [Int] = []
    /// 0.11: older steps were let go to save memory (the Undo list says so).
    @Published private(set) var undoLetGo = false
    private var redoTimes: [Date] = []
    /// 0.9: the Undo list page is open (UndoListPage in FindingViews.swift).
    @Published var showUndoList = false
    private var liveBase: Board?
    /// 0.14: a two-finger twist is going on (Tilt14.swift): the board rests meanwhile.
    var twisting = false
    var twistIDs: Set<UUID> = []
    var twistFrom: Double = 0
    private var editBase: Board?
    private var editIsNew = false

    /// This is the working copy of a starter being changed (StarterModel.swift), not one of the boards.
    var starterDraft = false

    /// Called with the board after every change that should be kept.
    var onChange: ((Board) -> Void)?
    /// 0.11: called with the lines for PARAGON's waiting list when a change ticked things that went to PARAGON.
    var onTicked: (([ParagonExport.DoneLine]) -> Void)?

    init(board: Board) {
        var fitted = board
        Lettering.fit(&fitted, facts: MapFacts(board))
        self.board = fitted
        self.facts = MapFacts(fitted)
    }

    /// A board written by a newer version can be looked at, not changed.
    var readOnly: Bool { !board.canBeChanged || HandoffDesk.shared.waiting == board.id }

    // MARK: Changing

    /// `room`: the board before the change — a map that grew since pushes aside what it would now cover.
    /// `widen`: shapes whose words were just typed or whose kind was changed; they may grow wider.
    private func set(_ new: Board, room old: Board? = nil, widen: Set<UUID> = []) {
        var fitted = new
        Lettering.fit(&fitted, facts: MapFacts(new), widen: widen)
        if let old { fitted.makeRoom(since: old) }
        noteMotion(to: fitted, live: liveBase != nil)
        board = fitted
        facts = MapFacts(fitted)
    }

    private func pushUndo(_ old: Board) {
        undoStack.append(old)
        undoTimes.append(Date())
        // 0.11: limited by size (about 40 MB) as well as by count (120); the Undo list says so when steps went.
        if undoWeights.count != undoStack.count - 1 { undoWeights = undoStack.dropLast().map(UndoBudget.weight) }
        undoWeights.append(UndoBudget.weight(of: old))
        let drop = UndoBudget.toLetGo(weights: undoWeights)
        if drop > 0 {
            undoStack.removeFirst(drop)
            undoTimes.removeFirst(min(drop, undoTimes.count))
            undoWeights.removeFirst(drop)
            undoLetGo = true
        }
        redoStack = []
        redoTimes = []
        undoCount = undoStack.count
        redoCount = 0
        clearNotice()
    }

    /// One change that can be undone. True when something changed.
    @discardableResult
    func change(widen: Set<UUID> = [], _ work: (inout Board) -> Void) -> Bool {
        guard !readOnly else { return false }
        let old = board
        var new = board
        work(&new)
        guard new != old else { return false }
        new.touch()
        pushUndo(old)
        set(new, room: old, widen: widen)
        onChange?(board)
        if let onTicked {
            let lines = board.doneLines(since: old, now: Date())
            if !lines.isEmpty { onTicked(lines) }
        }
        return true
    }

    /// A change that is NO step for Undo and leaves Undo and Redo as they are (0.5: the names on doors follow
    /// their boards, Doors.swift). Nothing happens while words are typed or a drag is going on.
    func quietly(_ work: (inout Board) -> Void) {
        guard !readOnly, !busy else { return }
        var new = board
        work(&new)
        guard new != board else { return }
        new.touch()
        set(new)
        onChange?(board)
    }

    /// Shows a short line with an Undo button for the step just taken. It goes by itself.
    func tell(_ words: String) {
        noticeWork?.cancel()
        let made = Notice(words: words)
        notice = made
        let work = DispatchWorkItem { [weak self] in
            if self?.notice == made { self?.notice = nil }
        }
        noticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func clearNotice() {
        noticeWork?.cancel()
        if notice != nil { notice = nil }
    }

    func undo() {
        clearNotice()
        guard editing == nil, let old = undoStack.popLast() else { return }
        redoStack.append(board)
        redoTimes.append(undoTimes.popLast() ?? Date())
        // What went to PARAGON meanwhile is not taken back with the step (0.5: no task goes twice).
        var back = old.keepingSentMarks(of: board)
        back.touch()
        set(back)
        tidySelection()
        undoCount = undoStack.count
        redoCount = redoStack.count
        onChange?(board)
    }

    /// 0.9: the last steps, newest first, each with a plain name and its time (the rule is `StepWords`).
    func undoSteps() -> [StepWords.Step] {
        StepWords.list(before: undoStack, now: board, times: undoTimes)
    }

    /// 0.9: goes back `steps` steps in one go (to just before the one pressed in the Undo list). Redo brings them back.
    func undo(steps: Int) {
        guard editing == nil else { return }
        for _ in 0..<max(0, min(steps, undoStack.count)) { undo() }
    }

    func redo() {
        guard editing == nil, let next = redoStack.popLast() else { return }
        undoStack.append(board)
        undoTimes.append(redoTimes.popLast() ?? Date())
        var again = next.keepingSentMarks(of: board)
        again.touch()
        set(again)
        tidySelection()
        undoCount = undoStack.count
        redoCount = redoStack.count
        onChange?(board)
    }

    /// A newer version of this board arrived from another device.
    func replace(with newer: Board) {
        guard !busy else { return }
        set(newer)
        tidySelection()
        // Steps taken before the other device's change must not be put back over it.
        undoStack = []
        undoWeights = []
        undoLetGo = false
        redoStack = []
        undoTimes = []
        redoTimes = []
        undoCount = 0
        redoCount = 0
        clearNotice()
    }

    /// In the middle of typing or dragging.
    var busy: Bool { editing != nil || liveBase != nil }

    private func tidySelection() {
        let ids = Set(board.items.map(\.id))
        selection = selection.intersection(ids)
        if let link = selectedLink, !board.links.contains(where: { $0.id == link }) { selectedLink = nil }
    }

    // MARK: Live changes (while a finger drags or a key is typed)

    func liveStart() {
        guard !readOnly else { return }
        liveBase = board
    }

    /// Applies the work to the board as it was when the drag began.
    func live(_ work: (inout Board) -> Void) {
        guard var new = liveBase else { return }
        work(&new)
        set(new)
        motionLift(since: liveBase)
    }

    func liveEnd(keep: Bool) {
        guard let base = liveBase else { return }
        liveBase = nil
        motionDrop()
        if keep, board != base {
            var kept = board
            kept.touch()
            pushUndo(base)
            set(kept)
            onChange?(board)
        } else {
            set(base)
        }
    }

    // MARK: Typing

    /// Two quick presses on a picture, or its Caption button: the caption is typed in place under the picture.
    func beginCaption(_ id: UUID) {
        guard board.item(id)?.kind == .picture else { return }
        beginEdit(id, caption: true)
    }

    func beginEdit(_ id: UUID, isNew: Bool = false, caption: Bool = false) {
        guard !readOnly else { return }
        // A drawing has no words; a picture has only its caption, which only the caption button and a double press start
        // (a letter key or Return on a chosen picture still does not start typing).
        // (A door shows its board's name: it has no words to type either.)
        guard board.item(id)?.kind != .drawing, board.item(id)?.kind != .door, caption || board.item(id)?.kind != .picture else { return }
        if editing != nil { commitEdit() }
        if let item = board.item(id) {
            draft = item.text
            selection = [id]
            selectedLink = nil
        } else if let link = board.links.first(where: { $0.id == id }) {
            draft = link.text
            selectedLink = id
            selection = []
        } else {
            return
        }
        editBase = board
        editIsNew = isNew
        lineBreakWanted = false
        editing = id
    }

    enum After { case nothing, child, sister }

    /// What is typed goes straight onto the board, so shapes grow and maps make room as you type.
    /// One new line break in an idea (the screen keyboard's Return) ends it and starts the next one —
    /// unless Shift and Return asked for a new line. Line breaks that are already there stay.
    func typed(_ text: String) {
        guard let id = editing else { return }
        if let clean = Typing.withoutNewBreak(old: draft, new: text) {
            if lineBreakWanted {
                lineBreakWanted = false
            } else if board.item(id)?.kind == .idea {
                draft = clean
                apply(clean, to: id)
                commitEdit(then: clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .nothing : .sister)
                return
            }
        }
        draft = text
        apply(text, to: id)
        // Kept as it is typed, so leaving the app in the middle of a sentence loses nothing.
        onChange?(board)
    }

    /// Shift (or Option) with Return while typing: a new line, in an idea too. The field makes the
    /// line where the cursor stands; if it does not, the line goes at the end of the words.
    func wantLineBreak() {
        guard editing != nil else { return }
        lineBreakWanted = true
        let words = draft
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.lineBreakWanted else { return }
            if self.editing != nil, self.draft == words { self.typed(words + "\n") }
            self.lineBreakWanted = false
        }
    }

    /// Shift (or Option) with Return, the line break already put into the words at the cursor: the typing
    /// goes on, in an idea too (where a new line break otherwise means "this idea is done").
    func typeLineBreak(_ text: String) {
        guard editing != nil else { return }
        lineBreakWanted = true
        typed(text)
        lineBreakWanted = false
    }

    private func apply(_ text: String, to id: UUID) {
        var new = board
        new.touch()
        if let i = new.index(of: id) {
            new.items[i].text = text
        } else if let l = new.links.firstIndex(where: { $0.id == id }) {
            new.links[l].text = text
        }
        set(new, room: board, widen: [id])
    }

    func commitEdit(then after: After = .nothing) {
        guard let id = editing else { return }
        // 0.5: a "next note" left empty was not meant: it goes again and leaves no trace (Thinking.swift).
        if editIsNew, dropsEmptyNextNote(id) { return }
        editing = nil
        lineBreakWanted = false
        var new = board
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        var removed = false
        if let i = new.index(of: id) {
            new.items[i].text = trimmed
            let item = new.items[i]
            // A new idea left empty was not meant: it goes again.
            if item.kind == .idea, trimmed.isEmpty, editIsNew, item.parent != nil, new.children(of: id).isEmpty {
                let parent = item.parent
                new.remove([id])
                removed = true
                selection = parent.map { [$0] } ?? []
            }
            // A board still called "New board" takes the name of its first idea.
            if !removed, !trimmed.isEmpty, new.title == "New board",
               new.items.filter({ !$0.text.isEmpty }).count == 1 {
                new.title = String(trimmed.split(separator: "\n").first ?? "").prefix(40).description
            }
        } else if let l = new.links.firstIndex(where: { $0.id == id }) {
            new.links[l].text = trimmed
        }
        let base = editBase ?? board
        editBase = nil
        draft = ""
        new.touch()
        if new.items != base.items || new.links != base.links || new.title != base.title {
            pushUndo(base)
        }
        set(new, room: board)
        onChange?(board)
        guard !removed else { return }
        switch after {
        case .nothing: break
        case .child: addChild(of: id)
        case .sister: addSister(of: id)
        }
    }

    /// Escape: the words go back to what they were, and a thing just made goes away again.
    func cancelEdit() {
        guard let id = editing else { return }
        editing = nil
        lineBreakWanted = false
        draft = ""
        var back = editBase ?? board
        editBase = nil
        back.touch()
        set(back)
        if editIsNew, let item = board.item(id), let before = undoStack.popLast() {
            _ = undoTimes.popLast()
            // The step that made it is taken back, so it leaves no trace.
            let parent = item.parent
            var old = before
            old.touch()
            set(old)
            undoCount = undoStack.count
            selection = parent.map { [$0] } ?? []
        }
        onChange?(board)
    }

    // MARK: Adding

    /// The middle of what can be seen, in board points.
    var visibleCentre: CGPoint { toBoard(CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)) }

    /// A free place for something of this size near the point.
    func freeSpot(near point: CGPoint, size: CGSize) -> CGPoint {
        var p = point
        var tries = 0
        func taken(_ p: CGPoint) -> Bool {
            let box = CGRect(x: p.x - size.width / 2, y: p.y - size.height / 2, width: size.width, height: size.height).insetBy(dx: -6, dy: -6)
            return board.items.contains { $0.kind != .frame && !facts.hidden.contains($0.id) && $0.frame.intersects(box) }
        }
        while tries < 14, taken(p) {
            p.x += 34
            p.y += 34
            tries += 1
        }
        return p
    }

    /// A tool was pressed: the new thing appears in the middle of the view, ready to type in.
    func add(_ kind: ItemKind, at point: CGPoint? = nil) {
        // A timeline and a "Who does what" board take only their own things, by their own tools.
        guard !readOnly, !board.placesItself else { return }
        if editing != nil { commitEdit() }
        linking = false
        var made: UUID?
        let size = kind == .idea ? CGSize(width: 150, height: 46) : kind.defaultSize
        let spot = point ?? freeSpot(near: visibleCentre, size: kind == .frame ? CGSize(width: 10, height: 10) : size)
        change { board in
            made = board.add(kind, centre: spot)
        }
        if let made { beginEdit(made, isNew: true) }
    }

    func addChild(of id: UUID) {
        guard !readOnly else { return }
        if editing != nil { commitEdit() }
        var made: UUID?
        change { made = $0.addChild(of: id) }
        if let made { beginEdit(made, isNew: true); reveal(made) }
    }

    func addSister(of id: UUID) {
        guard !readOnly else { return }
        if editing != nil { commitEdit() }
        var made: UUID?
        change { made = $0.addSister(of: id) }
        if let made { beginEdit(made, isNew: true); reveal(made) }
    }

    /// Shift and Tab: the idea moves out one level and becomes the next sister of the idea it hung
    /// under. It stays chosen, and typing in it goes on.
    func moveOut(_ id: UUID) {
        guard !readOnly else { return }
        if editing == id {
            var new = board
            guard new.moveOut(id) else { return }
            new.touch()
            set(new, room: board)
            onChange?(board)
        } else {
            guard change({ $0.moveOut(id) }) else { return }
        }
        reveal(id)
    }

    /// ⌘↑ / ⌘↓ and Move up / Move down: the idea goes one place up or down among its sisters
    /// (a main branch round the middle idea, see `Board.shiftIdea`). It stays chosen, and typing
    /// in it goes on. One step for Undo.
    func shiftIdea(_ id: UUID, down: Bool) {
        guard !readOnly else { return }
        if editing == id {
            var new = board
            guard new.shiftIdea(id, down: down) else { return }
            new.touch()
            set(new, room: board)
            onChange?(board)
        } else {
            if editing != nil { commitEdit() }
            guard change({ $0.shiftIdea(id, down: down) }) else { return }
        }
        reveal(id)
    }

    /// An idea dropped on another idea hangs under it, with everything below it. The middle of a
    /// map can be dropped on an idea of another map: the two maps become one.
    func hang(_ id: UUID, under target: UUID) {
        let wasMap = board.isCentre(id)
        guard change({ $0.reparent(id, under: target) }) else { return }
        selection = [id]
        if wasMap { tell("Joined to the other map") }
    }

    /// An idea dragged far out onto empty board becomes the middle of a map of its own.
    func detach(_ id: UUID, at point: CGPoint) {
        guard change({ $0.detach(id, at: point) }) else { return }
        selection = [id]
        tell("Made its own map")
    }

    func addNext(from id: UUID, direction: Direction) {
        guard !readOnly else { return }
        if editing != nil { commitEdit() }
        var made: UUID?
        change { made = $0.addNext(from: id, direction: direction) }
        if let made { beginEdit(made, isNew: true); reveal(made) }
    }

    /// A list becomes a mind map (or hangs under the chosen idea); one line becomes a sticky note.
    func paste(_ text: String) {
        guard !readOnly, editing == nil else { return }
        // On a timeline a list becomes bars (TimelineOfIt.swift).
        if board.isTimeline { timelinePaste(text); return }
        if board.isSequence { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let nodes = Outline.parse(clean)
        if selection.count == 1, let id = selection.first, board.item(id)?.kind == .idea, !nodes.isEmpty {
            change { $0.addIdeas(from: nodes, under: id) }
            return
        }
        var made: UUID?
        // 0.5: this is "Paste a list as a mind map" — two lines or more always make a map, paragraphs too.
        if Outline.hasSeveralLines(clean), !nodes.isEmpty {
            let spot = freeSpot(near: visibleCentre, size: CGSize(width: 300, height: 200))
            change { made = $0.addMap(from: nodes, title: nil, at: spot) }
        } else {
            let spot = freeSpot(near: visibleCentre, size: ItemKind.note.defaultSize)
            change { made = $0.add(.note, centre: spot, text: clean) }
        }
        if let made {
            selection = [made]
            selectedLink = nil
        }
    }

    // MARK: The chosen things

    var single: Item? { selection.count == 1 ? selection.first.flatMap { board.item($0) } : nil }

    func select(_ id: UUID, adding: Bool = false) {
        selectedLink = nil
        if adding {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }

    func clearSelection() {
        selection = []
        selectedLink = nil
        linkFrom = nil
        choosingMore = false
    }

    func selectAll() {
        selectedLink = nil
        selection = Set(board.items.filter { !facts.hidden.contains($0.id) && (!board.isSequence || $0.kind != .message || board.isDrawnMessage($0)) }.map(\.id))
    }

    func deleteSelection() {
        guard editing == nil else { return }
        if board.isSequence { sequenceRemove(); return }
        let ids = selection
        let link = selectedLink
        guard !ids.isEmpty || link != nil else { return }
        // After removing an idea, its parent is chosen, so typing can go on.
        let next = ids.count == 1 ? ids.first.flatMap { board.item($0)?.parent } : nil
        change { board in
            var gone = ids
            if let link { gone.insert(link) }
            board.remove(gone)
        }
        selection = next.map { [$0] } ?? []
        selectedLink = nil
    }

    func duplicateSelection() {
        guard editing == nil, !selection.isEmpty else { return }
        if board.isTimeline { timelineDuplicate(); return }
        if board.isSequence { sequenceDuplicate(); return }
        var copies: Set<UUID> = []
        change { copies = $0.duplicate(self.selection) }
        if !copies.isEmpty { selection = copies }
    }

    func toggleTodo() {
        if board.isSequence { sequenceToggleTodo(); return }
        // A drawing carries no tick, nor does a timeline's phase heading.
        let ids = selection.filter { board.item($0)?.kind != .drawing && board.item($0)?.kind != .picture && board.item($0)?.kind != .phase && board.item($0)?.kind != .door }
        guard !ids.isEmpty else { return }
        let allOn = ids.allSatisfy { board.item($0)?.todo == true }
        if !allOn { Feel.todoOn(); TickSound.play() }
        change { board in
            for id in ids {
                if let i = board.index(of: id), board.items[i].kind != .frame { board.items[i].todo = !allOn }
            }
            // Taking the tick off forgets that it was sent, so ticking it again sends it again.
            if allOn { board.sentTodos.removeAll { ids.contains($0) } }
            if allOn { board.sentTasks.removeAll { ids.contains($0.id) && $0.place == SentTask.inbox } }
        }
    }

    func setColour(_ name: String) {
        let ids = selection
        let link = selectedLink
        change { board in
            for id in ids {
                guard let i = board.index(of: id) else { continue }
                // In a mind map the colour belongs to the whole branch.
                if board.items[i].kind == .idea {
                    if let branch = board.mainBranch(of: id), let b = board.index(of: branch) { board.items[b].colour = name }
                } else if board.items[i].kind == .drawing {
                    // 0.9: the colour of a chosen sketch (chosen by the lasso, say) is the colour of its lines.
                    board.recolourSketch(id, to: name)
                } else if board.items[i].kind != .picture {
                    board.items[i].colour = name
                }
            }
            if let link, let l = board.links.firstIndex(where: { $0.id == link }) { board.links[l].colour = name }
        }
    }

    /// Another kind of shape. The size the owner gave it stays; long words make it wider first, then taller.
    func setKind(_ kind: ItemKind) {
        let ids = selection
        change(widen: ids) { board in
            for id in ids { board.setKind(id, to: kind) }
        }
    }

    func toggleFold() {
        guard let item = single, item.kind == .idea else { return }
        change { board in
            if let i = board.index(of: item.id) { board.items[i].folded.toggle() }
        }
    }

    /// 0.9: opens one folded idea (a press on its "+5" badge).
    func unfold(_ id: UUID) {
        guard board.item(id)?.folded == true else { return }
        change { board in
            if let i = board.index(of: id) { board.items[i].folded = false }
        }
    }

    /// 0.9: opens every folded idea of the board.
    func unfoldAll() {
        guard !readOnly, !board.placesItself else { return }
        change { $0.unfoldAll() }
    }

    /// 0.9: the folded idea whose "+N" badge lies under this board point (a press there opens it).
    func foldBadge(at p: CGPoint) -> UUID? {
        guard !readOnly, !board.placesItself, editing == nil else { return nil }
        let slack = max(8, 14 / scale)
        for item in board.items where item.kind == .idea && item.folded && !facts.hidden.contains(item.id) {
            guard let count = facts.below[item.id], count > 0 else { continue }
            let right = (facts.side[item.id] ?? .right) == .right || (facts.depth[item.id] ?? 0) == 0
            if MindMap.badge(for: item.frame, right: right, count: count).insetBy(dx: -slack, dy: -slack).contains(p) { return item.id }
        }
        return nil
    }

    /// 0.9: "Balance" on a map's centre: both sides on, the main branches spread evenly by size.
    func balanceMap() {
        guard let item = single, item.kind == .idea, item.parent == nil else { return }
        change { $0.balanceMap(item.id) }
    }

    /// 0.9: the board numbers the steps of its flowchart (More ▸ Number the steps).
    func toggleNumberSteps() {
        guard !board.placesItself else { return }
        change { $0.numberSteps = $0.numberSteps == true ? nil : true }
    }

    func toggleBothSides() {
        guard let item = single, item.kind == .idea else { return }
        let centre = board.centre(of: item.id)
        change { board in
            if let i = board.index(of: centre) { board.items[i].bothSides.toggle() }
        }
    }

    func setLinkStyle(_ style: LinkStyle) {
        guard let id = selectedLink else { return }
        change { board in
            if let l = board.links.firstIndex(where: { $0.id == id }) { board.links[l].style = style }
        }
    }

    func turnLinkRound() {
        guard let id = selectedLink else { return }
        change { board in
            if let l = board.links.firstIndex(where: { $0.id == id }) {
                let from = board.links[l].from
                board.links[l].from = board.links[l].to
                board.links[l].to = from
                (board.links[l].fromSide, board.links[l].toSide) = (board.links[l].toSide, board.links[l].fromSide)
            }
        }
    }

    func join(_ from: UUID, _ to: UUID) {
        var made: UUID?
        change { made = $0.link(from: from, to: to) }
        if let made {
            Feel.joined()
            selection = []
            selectedLink = made
        }
    }

    /// Arrow keys: walk a mind map, or nudge the chosen things.
    func arrow(_ step: Board.Step, big: Bool) {
        guard editing == nil else { return }
        if let item = single, item.kind == .idea {
            if let next = board.idea(from: item.id, step: step) {
                selection = [next]
                reveal(next)
            }
            return
        }
        guard !selection.isEmpty else { return }
        let d: CGFloat = big ? 40 : 10
        let delta: CGSize
        switch step {
        case .up: delta = CGSize(width: 0, height: -d)
        case .down: delta = CGSize(width: 0, height: d)
        case .left: delta = CGSize(width: -d, height: 0)
        case .right: delta = CGSize(width: d, height: 0)
        }
        let ids = board.carried(by: selection)
        change { $0.move(ids, by: delta) }
    }

    // MARK: The view

    func toBoard(_ p: CGPoint) -> CGPoint { place.toBoard(p) }

    func toScreen(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * scale + offset.width, y: r.minY * scale + offset.height, width: r.width * scale, height: r.height * scale)
    }

    func toScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * scale + offset.width, y: p.y * scale + offset.height)
    }

    /// Every way of moving the view goes through `place`, which remembers that the owner moved it.
    func pan(by delta: CGSize) {
        stopGlide()
        place.pan(by: delta)
        if board.isTimeline { clampTimeline() }
    }

    /// A finger slide on empty board: the view as it stood when the slide began, moved by the finger's way.
    func slide(from start: CGSize, by way: CGSize) {
        stopGlide()
        place.slide(from: start, by: way)
        if board.isTimeline { clampTimeline() }
    }

    /// Zooms so the board point under the screen point stays where it is.
    func zoom(to newScale: CGFloat, around point: CGPoint? = nil) {
        stopGlide()
        if board.isTimeline {
            let anchor = point ?? CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            timelineZoom(by: newScale / max(scale, 0.01), around: anchor)
            return
        }
        place.zoom(to: Double(newScale), around: point)
    }

    /// Two fingers (iPhone, iPad): the board slides with the point between them and zooms round it, in one step.
    func pinch(from old: CGPoint, to new: CGPoint, by factor: CGFloat) { stopGlide(); place.pinch(from: old, to: new, by: Double(factor)) }

    /// One step of a glide (BoardGlide.swift): only where the view stands, nothing about who moved it.
    func stand(at offset: CGSize, scale: Double) {
        var next = place
        next.offset = offset
        next.scale = scale
        place = next
    }

    /// The thing last typed in while the iPhone's view was zoomed in for typing.
    private var typedIn: UUID?

    /// iPhone: while words are typed the view is at least life size round them; afterwards it goes
    /// back to the zoom before. Ideas typed one after the other do not zoom out in between.
    func typingJump(in id: UUID?) {
        guard Finger.phone else { return }
        func box(_ id: UUID) -> CGRect? {
            if let item = board.item(id) { return item.frame }
            guard let link = board.links.first(where: { $0.id == id }),
                  let a = board.item(link.from), let b = board.item(link.to) else { return nil }
            return CGRect(origin: Route.path(from: a.frame, to: b.frame, style: link.style).label, size: .zero)
        }
        if let id {
            guard let round = box(id) else { return }
            typedIn = id
            if place.typingBegan(round: round) { reveal(id) }
        } else {
            let last = typedIn
            typedIn = nil
            guard place.typingEnded(round: last.flatMap(box)) else { return }
            if let last { reveal(last) }
            // Not moved by the owner: the board opens again as it stood.
            placeIfNeeded(viewSize)
        }
    }

    /// Shows the whole board, never bigger than life size.
    func fit() {
        if board.isTimeline { timelineFit(); return }
        glide(Glide.wholeBoard) { place.fit(board.bounds) }
    }

    // MARK: 0.14 look lane

    /// 19: the board glides so the chosen things fill the screen, with a margin. Not on a timeline or "Who does what".
    var canZoomToChosen: Bool {
        !board.placesItself && board.bounds != nil && selection.contains { board.item($0) != nil }
    }

    func zoomToChosen() {
        guard canZoomToChosen else { return }
        var box: CGRect?
        for id in selection {
            guard let f = board.item(id)?.frame else { continue }
            box = box.map { $0.union(f) } ?? f
        }
        guard let box else { return }
        glide(Glide.wholeBoard) { place.fitChosen(box) }
    }

    /// 26: set by the typing field while words are typed (puts words where the cursor stands); nil when none is typing.
    var insertAtCaret: ((String) -> Void)?

    /// 26: "19 Nov 2026" goes where the cursor stands.
    func insertToday() {
        guard editing != nil else { return }
        let words = DateWords.short(Date())
        if let insertAtCaret { insertAtCaret(words) } else { typed(draft + words) }
    }

    /// The board is reopened: the zoom and the spot the owner left it at come back (pick 26).
    func comeBack(to left: LeftView) { place.comeBack(to: left) }

    /// The first time the board's place on screen is known, it is shown whole — and again whenever its
    /// room changes (a window still settling, a page opening over it), until the owner has moved or zoomed it.
    func placeIfNeeded(_ size: CGSize) {
        settleGlide()
        if board.isTimeline {
            // A timeline is placed by its days, not by where its things lie.
            place.size = size
            if !place.movedByOwner, size.width > 10 { timelineFit(opening: true) }
            return
        }
        // The iPhone opens a board readable (75 % or more, on the main idea) instead of whole and tiny.
        place.resized(to: size, showing: board.bounds, readableAround: Finger.phone ? (board.isSequence ? board.sequenceMainFrame : board.mainThing?.frame) : nil)
    }

    /// The room for the board changed (the window, or the keyboard coming up): what is typed stays in sight.
    func resized(_ size: CGSize) {
        retarget {
            placeIfNeeded(size)
            if let id = editing { reveal(id) }
        }
    }

    /// Moves the view just enough to bring an item into sight.
    func reveal(_ id: UUID) {
        if board.isTimeline { timelineReveal(id); return }
        if board.isSequence { sequenceReveal(id); return }
        guard let item = board.item(id), viewSize.width > 10 else { return }
        let r = toScreen(item.frame)
        let safe = CGRect(x: 30, y: 70, width: viewSize.width - 60, height: viewSize.height - 190)
        var dx: CGFloat = 0, dy: CGFloat = 0
        if r.maxX > safe.maxX { dx = safe.maxX - r.maxX } else if r.minX < safe.minX { dx = safe.minX - r.minX }
        if r.maxY > safe.maxY { dy = safe.maxY - r.maxY } else if r.minY < safe.minY { dy = safe.minY - r.minY }
        if dx != 0 || dy != 0 { glide(Glide.intoSight) { pan(by: CGSize(width: dx, height: dy)) } }
    }

    // MARK: Board-wide

    func rename(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        change { $0.title = clean }
    }

    /// `tasks`: every thing that became a task in PARAGON, with the words that were sent; `place`: where
    /// they went (`SentTask.note` or `SentTask.inbox`).
    func markSent(_ info: SentInfo?, todos: [UUID], tasks: [MadeTask] = [], place: String = SentTask.note) {
        guard !readOnly else { return }
        var new = board
        if let info { new.sent = info }
        new.sentTodos = Array(Set(new.sentTodos).union(todos))
        new.noteSent(tasks, place: place)
        new.touch()
        set(new)
        onChange?(board)
    }
}
