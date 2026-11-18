import SwiftUI
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
    /// Where the board's zero point is on screen, and how big one board point is.
    @Published var offset: CGSize = .zero
    @Published var scale: CGFloat = 1
    /// The arrow tool is on: the next two shapes pressed are joined.
    @Published var linking = false
    @Published var linkFrom: UUID?
    @Published private(set) var undoCount = 0
    @Published private(set) var redoCount = 0

    var viewSize: CGSize = .zero
    private var placed = false
    private var undoStack: [Board] = []
    private var redoStack: [Board] = []
    private var liveBase: Board?
    private var editBase: Board?
    private var editIsNew = false

    /// Called with the board after every change that should be kept.
    var onChange: ((Board) -> Void)?

    init(board: Board) {
        var fitted = board
        Lettering.fit(&fitted, facts: MapFacts(board))
        self.board = fitted
        self.facts = MapFacts(fitted)
    }

    /// A board written by a newer version can be looked at, not changed.
    var readOnly: Bool { !board.canBeChanged }

    // MARK: Changing

    private func set(_ new: Board) {
        var fitted = new
        Lettering.fit(&fitted, facts: MapFacts(new))
        board = fitted
        facts = MapFacts(fitted)
    }

    private func pushUndo(_ old: Board) {
        undoStack.append(old)
        if undoStack.count > 120 { undoStack.removeFirst(undoStack.count - 120) }
        redoStack = []
        undoCount = undoStack.count
        redoCount = 0
    }

    /// One change that can be undone.
    func change(_ work: (inout Board) -> Void) {
        guard !readOnly else { return }
        let old = board
        var new = board
        work(&new)
        guard new != old else { return }
        new.touch()
        pushUndo(old)
        set(new)
        onChange?(board)
    }

    func undo() {
        guard editing == nil, let old = undoStack.popLast() else { return }
        redoStack.append(board)
        var back = old
        back.touch()
        set(back)
        tidySelection()
        undoCount = undoStack.count
        redoCount = redoStack.count
        onChange?(board)
    }

    func redo() {
        guard editing == nil, let next = redoStack.popLast() else { return }
        undoStack.append(board)
        var again = next
        again.touch()
        set(again)
        tidySelection()
        undoCount = undoStack.count
        redoCount = redoStack.count
        onChange?(board)
    }

    /// A newer version of this board arrived from another device.
    func replace(with newer: Board) {
        guard editing == nil, liveBase == nil else { return }
        set(newer)
        tidySelection()
    }

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
    }

    func liveEnd(keep: Bool) {
        guard let base = liveBase else { return }
        liveBase = nil
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

    func beginEdit(_ id: UUID, isNew: Bool = false) {
        guard !readOnly else { return }
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
        editing = id
    }

    enum After { case nothing, child, sister }

    /// What is typed goes straight onto the board, so shapes grow and maps make room as you type.
    /// A line break in an idea ends it and starts the next one.
    func typed(_ text: String) {
        guard let id = editing else { return }
        if let item = board.item(id), item.kind == .idea, text.contains("\n") {
            draft = text.replacingOccurrences(of: "\n", with: "")
            apply(draft, to: id)
            commitEdit(then: draft.isEmpty ? .nothing : .sister)
            return
        }
        draft = text
        apply(text, to: id)
    }

    private func apply(_ text: String, to id: UUID) {
        var new = board
        if let i = new.index(of: id) {
            new.items[i].text = text
        } else if let l = new.links.firstIndex(where: { $0.id == id }) {
            new.links[l].text = text
        }
        set(new)
    }

    func commitEdit(then after: After = .nothing) {
        guard let id = editing else { return }
        editing = nil
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
        if new != base {
            new.touch()
            pushUndo(base)
            set(new)
            onChange?(board)
        } else {
            set(new)
        }
        guard !removed else { return }
        switch after {
        case .nothing: break
        case .child: addChild(of: id)
        case .sister: addSister(of: id)
        }
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
        guard !readOnly else { return }
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
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let nodes = Outline.parse(clean)
        if selection.count == 1, let id = selection.first, board.item(id)?.kind == .idea, !nodes.isEmpty {
            change { $0.addIdeas(from: nodes, under: id) }
            return
        }
        var made: UUID?
        if Outline.isList(clean), !nodes.isEmpty {
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
    }

    func selectAll() {
        selectedLink = nil
        selection = Set(board.items.filter { !facts.hidden.contains($0.id) }.map(\.id))
    }

    func deleteSelection() {
        guard editing == nil else { return }
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
        var copies: Set<UUID> = []
        change { copies = $0.duplicate(self.selection) }
        if !copies.isEmpty { selection = copies }
    }

    func toggleTodo() {
        let ids = selection
        guard !ids.isEmpty else { return }
        let allOn = ids.allSatisfy { board.item($0)?.todo == true }
        change { board in
            for id in ids {
                if let i = board.index(of: id), board.items[i].kind != .frame { board.items[i].todo = !allOn }
            }
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
                } else {
                    board.items[i].colour = name
                }
            }
            if let link, let l = board.links.firstIndex(where: { $0.id == link }) { board.links[l].colour = name }
        }
    }

    func setKind(_ kind: ItemKind) {
        let ids = selection
        change { board in
            for id in ids {
                guard let i = board.index(of: id), board.items[i].kind.isShape, kind.isShape else { continue }
                let centre = board.items[i].centre
                board.items[i].kind = kind
                board.items[i].w = Double(kind.defaultSize.width)
                board.items[i].h = Double(kind.defaultSize.height)
                board.items[i].x = Double(centre.x) - board.items[i].w / 2
                board.items[i].y = Double(centre.y) - board.items[i].h / 2
            }
        }
    }

    func toggleFold() {
        guard let item = single, item.kind == .idea else { return }
        change { board in
            if let i = board.index(of: item.id) { board.items[i].folded.toggle() }
        }
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
            }
        }
    }

    func join(_ from: UUID, _ to: UUID) {
        var made: UUID?
        change { made = $0.link(from: from, to: to) }
        if let made {
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

    func toBoard(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - offset.width) / scale, y: (p.y - offset.height) / scale)
    }

    func toScreen(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * scale + offset.width, y: r.minY * scale + offset.height, width: r.width * scale, height: r.height * scale)
    }

    func toScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * scale + offset.width, y: p.y * scale + offset.height)
    }

    func pan(by delta: CGSize) {
        offset = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
    }

    /// Zooms so the board point under the screen point stays where it is.
    func zoom(to newScale: CGFloat, around point: CGPoint? = nil) {
        let anchor = point ?? CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let clamped = min(max(newScale, 0.2), 3)
        let under = toBoard(anchor)
        scale = clamped
        offset = CGSize(width: anchor.x - under.x * clamped, height: anchor.y - under.y * clamped)
    }

    /// Shows the whole board, never bigger than life size.
    func fit() {
        guard viewSize.width > 10, viewSize.height > 10 else { return }
        guard let all = board.bounds else {
            scale = 1
            offset = CGSize(width: viewSize.width / 2, height: viewSize.height / 2)
            return
        }
        let room = CGSize(width: max(viewSize.width - 80, 80), height: max(viewSize.height - 170, 80))
        let s = min(1, min(room.width / max(all.width, 1), room.height / max(all.height, 1)))
        scale = max(s, 0.2)
        offset = CGSize(width: viewSize.width / 2 - all.midX * scale, height: viewSize.height / 2 - all.midY * scale)
    }

    /// The first time the board's place on screen is known, it is shown whole.
    func placeIfNeeded(_ size: CGSize) {
        viewSize = size
        guard !placed, size.width > 10 else { return }
        placed = true
        fit()
    }

    /// Moves the view just enough to bring an item into sight.
    func reveal(_ id: UUID) {
        guard let item = board.item(id), viewSize.width > 10 else { return }
        let r = toScreen(item.frame)
        let safe = CGRect(x: 30, y: 70, width: viewSize.width - 60, height: viewSize.height - 190)
        var dx: CGFloat = 0, dy: CGFloat = 0
        if r.maxX > safe.maxX { dx = safe.maxX - r.maxX } else if r.minX < safe.minX { dx = safe.minX - r.minX }
        if r.maxY > safe.maxY { dy = safe.maxY - r.maxY } else if r.minY < safe.minY { dy = safe.minY - r.minY }
        if dx != 0 || dy != 0 { pan(by: CGSize(width: dx, height: dy)) }
    }

    // MARK: Board-wide

    func rename(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        change { $0.title = clean }
    }

    func markSent(_ info: SentInfo?, todos: [UUID]) {
        guard !readOnly else { return }
        var new = board
        if let info { new.sent = info }
        new.sentTodos = Array(Set(new.sentTodos).union(todos))
        new.touch()
        set(new)
        onChange?(board)
    }
}
