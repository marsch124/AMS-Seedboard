import Foundation
import CoreGraphics

// 0.5 groundwork: what the board knows about the things it handed to PARAGON, and where a thing that
// arrives from outside (Shortcuts, Share, a drop on a row) is laid.

/// How a thing marked "to do" stands. Drawn as three marks (CanvasDraw, TimelineDraw).
public enum TodoState: String, Equatable, Sendable, CaseIterable {
    /// To do, not sent yet: a hollow purple ring.
    case waiting
    /// A task in PARAGON (in the Inbox, or in the note or project the board became): a filled purple ring.
    case inParagon
    /// Ticked off in PARAGON: a green ring with a tick, the words greyed.
    case done
    /// Cancelled in PARAGON: a grey ring with a dash.
    case cancelled
}

public extension Board {
    /// The thing became a task in PARAGON: remembered with the words that were sent. One entry per thing; a
    /// later sending of the same thing replaces the earlier entry.
    mutating func noteSent(_ id: UUID, words: String, place: String) {
        sentTasks.removeAll { $0.id == id }
        sentTasks.append(SentTask(id: id, words: words, place: place))
    }

    /// The entry of a thing that became a task, if it did.
    func sentTask(_ id: UUID) -> SentTask? { sentTasks.first { $0.id == id } }

    /// Forgets the entries of things that are no longer on the board.
    mutating func dropSentTasksOfMissingThings() {
        let here = Set(items.map(\.id))
        sentTasks.removeAll { !here.contains($0.id) }
    }

    /// How a thing stands by what the BOARD knows: nil = not a to-do and never sent; `.waiting` = ticked "to do"
    /// and not sent; `.inParagon` = it went to PARAGON. What was read back from PARAGON (done, cancelled) is kept
    /// on the device only and laid over this by the app.
    func todoState(of id: UUID) -> TodoState? {
        if sentTask(id) != nil || sentTodos.contains(id) { return .inParagon }
        guard let item = items.first(where: { $0.id == id }), item.todo else { return nil }
        // 0.19: a pasted checklist's ticked line (an idea, note … marked To do with a done day) stands done.
        if !item.kind.isTimeline, !(item.doneDay ?? "").isEmpty { return .done }
        return .waiting
    }

    /// Where a thing of `size` that arrives from outside (Shortcuts, Share, a drop on a board's row) is laid so
    /// that it covers nothing: a free column 40 points to the right of everything on the board, its top at the top
    /// of what is there. `taken` = the frames of arrivals already laid in the same go and not yet on the board: the
    /// next one goes under them, 16 points apart. On an empty board the first lies in the middle.
    func arrivalSpot(size: CGSize, taken: [CGRect] = []) -> CGPoint {
        let low = taken.map(\.maxY).max()
        let onBoard = items.map(\.frame)
        guard let first = onBoard.first else {
            guard let low, let column = taken.first else {
                return CGPoint(x: -size.width / 2, y: -size.height / 2)
            }
            return CGPoint(x: column.minX, y: low + Board.arrivalStep)
        }
        let box = onBoard.dropFirst().reduce(first) { $0.union($1) }
        return CGPoint(x: box.maxX + Board.arrivalGap, y: low.map { $0 + Board.arrivalStep } ?? box.minY)
    }

    /// The air between the board's things and the column where arrivals are laid.
    static let arrivalGap: CGFloat = 40
    /// The air between two arrivals laid in one go.
    static let arrivalStep: CGFloat = 16
}
