import Foundation

// 0.5, data safety (panel findings 4 and 7): a board that is no longer on screen never saves, and a step back
// never forgets what went to PARAGON.

public extension SafetyRules {
    /// May this opening of a board still save? Only while it is the one on screen. A board that was closed
    /// (another board was opened, or the same board was opened again) can still finish work that was on its way —
    /// photos that were loading, a drop — and must then not write its older state over the open board.
    static func maySave(asking: AnyObject?, shown: AnyObject?) -> Bool {
        guard let asking, let shown else { return false }
        return asking === shown
    }
}

public extension Board {
    /// Undo and Redo put an earlier (or later) state of the board back. What went to PARAGON meanwhile is not a
    /// change of the board that can be taken back: the board's own "sent" mark, the list of to-do boxes that are
    /// in the Inbox and the list of things that became tasks are carried over from the board as it is NOW
    /// (`present`), for every thing that is on this state too. So a step back after Send never lets the same
    /// task go twice.
    /// One exception keeps "taking the tick off forgets it was sent": a thing whose tick this very step takes
    /// off (ticked now, not ticked in this state) does not carry its mark over.
    func keepingSentMarks(of present: Board) -> Board {
        var back = self
        back.sent = present.sent ?? back.sent
        let mine = Dictionary(back.items.map { ($0.id, $0.todo) }, uniquingKeysWith: { a, _ in a })
        let now = Dictionary(present.items.map { ($0.id, $0.todo) }, uniquingKeysWith: { a, _ in a })
        func carried(_ id: UUID) -> Bool {
            guard let ticked = mine[id] else { return false }
            return ticked || now[id] != true
        }
        var todos = back.sentTodos
        for id in present.sentTodos where carried(id) && !todos.contains(id) { todos.append(id) }
        back.sentTodos = todos
        for task in present.sentTasks where carried(task.id) {
            back.sentTasks.removeAll { $0.id == task.id }
            back.sentTasks.append(task)
        }
        return back
    }
}
