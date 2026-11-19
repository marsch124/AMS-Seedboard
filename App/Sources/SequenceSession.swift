import SwiftUI
import SeedboardCore

/// The "Who does what" board's side of the open board. The view's place is the session's ordinary
/// zoom and slide, so the top bar, Undo, the zoom buttons and "whole board" work as on any board.
/// The rules themselves are in SeedboardCore (Sequence.swift).
extension BoardSession {
    var sequenceLayout: SequenceLayout { board.sequenceLayout(SequenceLook.metrics) }

    /// The room the pinned names keep from the top edge, in screen points: more while a line of
    /// words lies over the top of the board.
    var sequencePinInset: CGFloat { linking || readOnly ? 52 : 8 }

    /// How far the names are moved down (in board points) so they stay in sight.
    func sequenceShift(_ layout: SequenceLayout) -> CGFloat {
        CGFloat(layout.pinShift(top: Double(toBoard(.zero).y), inset: Double(sequencePinInset / max(scale, 0.01))))
    }

    /// The room at the bottom that the tools, the zoom buttons and the chosen thing's buttons take.
    private var sequenceBottomRoom: CGFloat { viewSize.width < 520 ? 215 : 150 }

    /// Slides just enough to bring a step (or, sideways, a name) into sight.
    func sequenceReveal(_ id: UUID) {
        guard viewSize.width > 10 else { return }
        let layout = sequenceLayout
        let head = CGFloat(layout.boxBottom - layout.boxTop) * scale + sequencePinInset + 14
        var dx: CGFloat = 0, dy: CGFloat = 0
        func across(_ box: CGRect) {
            let r = toScreen(box)
            let left: CGFloat = 16, right = viewSize.width - 16
            if r.maxX > right { dx = right - r.maxX } else if r.minX < left { dx = left - r.minX }
        }
        if let row = layout.row(id) {
            across(row.box)
            let r = toScreen(CGRect(x: 0, y: row.top, width: 10, height: row.height))
            let bottom = viewSize.height - sequenceBottomRoom
            if r.minY < head { dy = head - r.minY } else if r.maxY > bottom { dy = bottom - r.maxY }
        } else if let box = layout.boxes[id] {
            across(box)
        }
        if dx != 0 || dy != 0 { pan(by: CGSize(width: dx, height: dy)) }
    }

    /// The place in the order for a new step: right under the chosen step, or under the last one.
    private var placeForNewStep: Int? {
        guard let item = single, item.kind.isStep else { return nil }
        return board.stepIndex(of: item.id).map { $0 + 1 }
    }

    private func made(_ id: UUID?) {
        guard let id else { return }
        beginEdit(id, isNew: true)
        sequenceReveal(id)
    }

    private func ready() -> Bool {
        guard !readOnly else { return false }
        if editing != nil { commitEdit() }
        linking = false
        linkFrom = nil
        return true
    }

    // MARK: Adding

    /// The Who tool: a new name at the right end of the row (or right after `after`), typed at once.
    func addWho(after: UUID? = nil) {
        guard ready() else { return }
        let place = after.flatMap { board.whoIndex(of: $0) }.map { $0 + 1 }
        var new: UUID?
        change { new = $0.addWho(at: place) }
        made(new)
    }

    /// Tab while a name is typed: the name is done and the next one begins right beside it.
    /// With nothing typed, the empty name goes away again and the typing ends.
    func nextWhoAfterTyping() {
        guard let id = editing, board.item(id)?.kind == .who else { return }
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cancelEdit()
            return
        }
        commitEdit()
        addWho(after: id)
    }

    /// A new message from one name to another (the same name: a message to itself), at a place in
    /// the order (nil: under the last step). It is an answer when the message right above it asks
    /// the other way. Its words are typed at once.
    func addMessage(from: UUID, to: UUID, at place: Int? = nil) {
        guard ready() else { return }
        var new: UUID?
        change { board in
            new = board.addMessage(from: from, to: to, at: place, answer: board.wouldAnswer(from: from, to: to, at: place))
        }
        made(new)
    }

    /// Return on a chosen message (or Tab while its words are typed): the next message right under
    /// it, going the other way.
    func addNextMessage(after id: UUID) {
        guard ready() else { return }
        var new: UUID?
        change { new = $0.addMessageAfter(id) }
        made(new)
    }

    /// The Note tool: a soft band across the lines, under the chosen step or at the end.
    func addBand() {
        let place = placeForNewStep
        guard ready() else { return }
        var new: UUID?
        change { new = $0.addBand(at: place) }
        made(new)
    }

    /// The Section tool: a heading line across the diagram, under the chosen step or at the end.
    func addSection() {
        let place = placeForNewStep
        guard ready() else { return }
        var new: UUID?
        change { new = $0.addSection(at: place) }
        made(new)
    }

    /// The Message tool and "Message to…": the next name pressed is where the message goes
    /// (the first one pressed is where it comes from, when none is given).
    func startMessage(from: UUID?) {
        guard !readOnly else { return }
        if editing != nil { commitEdit() }
        linking = true
        linkFrom = from
    }

    /// A name (or its dashed line) was pressed while a message is being made.
    func pressWhoForMessage(_ id: UUID) {
        guard linking else { return }
        if let from = linkFrom {
            addMessage(from: from, to: id)
        } else {
            linkFrom = id
        }
    }

    // MARK: The chosen things

    /// Removes what is chosen. A name takes its messages along; the line that says so has Undo.
    func sequenceRemove() {
        guard editing == nil, !selection.isEmpty else { return }
        let ids = selection
        let names = ids.compactMap { board.item($0) }.filter { $0.kind == .who }
        var along = 0
        change { along = $0.removeFromSequence(ids) }
        selection = []
        selectedLink = nil
        if let words = SequenceWords.removed(names: names, along: along) { tell(words) }
    }

    /// Copies the chosen steps right under themselves (a name right beside itself).
    func sequenceDuplicate() {
        guard editing == nil, !selection.isEmpty else { return }
        let ids = selection
        var copies: Set<UUID> = []
        change { copies = $0.duplicateInSequence(ids) }
        if !copies.isEmpty { selection = copies }
    }

    /// To do: only a message can become a task.
    func sequenceToggleTodo() {
        let ids = selection.filter { board.item($0)?.kind == .message }
        guard !ids.isEmpty else { return }
        let allOn = ids.allSatisfy { board.item($0)?.todo == true }
        if !allOn { Feel.todoOn(); TickSound.play() }
        change { board in
            for id in ids {
                if let i = board.index(of: id) { board.items[i].todo = !allOn }
            }
            // Taking the tick off forgets that it was sent, so ticking it again sends it again.
            if allOn { board.sentTodos.removeAll { ids.contains($0) } }
            if allOn { board.sentTasks.removeAll { ids.contains($0.id) && $0.place == SentTask.inbox } }
        }
    }

    /// Answer on or off for the chosen message: an answer is drawn with dashes.
    func toggleAnswer() {
        guard let item = single, item.kind == .message else { return }
        change { board in
            if let i = board.index(of: item.id) { board.items[i].isAnswer.toggle() }
        }
    }

    /// The chosen message now comes from the name it went to.
    func turnMessageRound() {
        guard let item = single, item.kind == .message else { return }
        change { $0.turnMessageRound(item.id) }
    }

    /// True when the chosen step can go one place up (-1) or down (1).
    func canShiftStep(by step: Int) -> Bool {
        guard let item = single, item.kind.isStep, let at = board.stepIndex(of: item.id) else { return false }
        return at + step >= 0 && at + step < board.steps.count
    }

    /// The chosen step goes one place up (-1) or down (1) in the order.
    func shiftStep(by step: Int) {
        guard canShiftStep(by: step), let item = single, let at = board.stepIndex(of: item.id) else { return }
        change { $0.moveStep(item.id, to: at + step) }
        sequenceReveal(item.id)
    }

    /// The chosen name goes one place to the left (-1) or to the right (1) in the row.
    func shiftWho(by step: Int) {
        guard let item = single, item.kind == .who, let at = board.whoIndex(of: item.id),
              at + step >= 0, at + step < board.whos.count else { return }
        change { $0.moveWho(item.id, to: at + step) }
        sequenceReveal(item.id)
    }

    /// Up and down arrow keys: the step above or below is chosen (from a name: the first step).
    func selectStep(by step: Int) {
        let steps = board.steps.filter { $0.kind != .message || board.isDrawnMessage($0) }
        guard !steps.isEmpty else { return }
        let here = single.flatMap { one in steps.firstIndex { $0.id == one.id } }
        let next = min(max((here ?? (step > 0 ? -1 : steps.count)) + step, 0), steps.count - 1)
        selection = [steps[next].id]
        selectedLink = nil
        sequenceReveal(steps[next].id)
    }

    /// Left and right arrow keys: the name before or after the chosen one is chosen.
    func selectWho(by step: Int) {
        let whos = board.whos
        guard !whos.isEmpty else { return }
        let here = single.flatMap { board.whoIndex(of: $0.id) }
        let next = min(max((here ?? (step > 0 ? -1 : whos.count)) + step, 0), whos.count - 1)
        selection = [whos[next].id]
        selectedLink = nil
        sequenceReveal(whos[next].id)
    }

    /// The chosen thing in words, for the screen tests: "Who: Alex", "1. Alex → Bank: Ask for loan".
    var sequenceChosenLine: String {
        guard let item = single else { return "" }
        return item.kind == .who ? "Who: " + item.nameLine : board.stepLine(item.id)
    }
}

/// The short lines a "Who does what" board says.
enum SequenceWords {
    static func linking(first: Bool) -> String {
        first ? "Press who it comes from, then who it goes to."
              : "Now press who it goes to. The same name again makes a message to itself."
    }

    /// "“Bank” went with its 2 messages." after a name was removed that had messages.
    static func removed(names: [Item], along: Int) -> String? {
        guard along > 0, !names.isEmpty else { return nil }
        let messages = along == 1 ? "1 message" : "\(along) messages"
        if names.count == 1 {
            let name = names[0].nameLine
            return "\(name.isEmpty ? "The name" : "“\(name)”") went with its \(messages)."
        }
        return "\(names.count) names went with their \(messages)."
    }

    static let sendNote = "The diagram's picture and its messages as a numbered list, with notes and sections in place. It goes to Resources, and one line in the Inbox points to it."
    static let sendProject = "The messages in their order. The ones you ticked To do become tasks; with nothing ticked, all of them do. It goes to Projects."
}
