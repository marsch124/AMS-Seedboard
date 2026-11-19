import SwiftUI
import SeedboardCore

// 0.5 (pick 16): the ONE drawing of the small to-do mark. The board, the timeline and "Who does what" all
// call it, so the four ways a to-do can stand look the same everywhere.
//
//   waiting    — a hollow purple ring: to do, not sent yet
//   inParagon  — a full purple ring with a white arrow up and out: it went on to PARAGON (0.14; a tick means done only)
//   done       — a full green ring with a white tick, the words greyed: ticked off in PARAGON
//   cancelled  — a full grey ring with a white dash, the words greyed: cancelled in PARAGON
//
// Hollow = still only here. Full = PARAGON has it, and the colour says how it stands there.

enum TodoMark {
    /// The ring's radius on the board; the timeline and "Who does what" use 7.
    static let radius: CGFloat = 7.5

    /// How a thing stands for the painter: what was handed in (`ParagonEcho.marks(for:)`), else "to do" = waiting.
    static func state(of item: Item, in states: [UUID: TodoState]) -> TodoState? {
        states[item.id] ?? (item.todo ? .waiting : nil)
    }

    /// The marks of a whole board, for a painter that is not handed them (the timeline, "Who does what"):
    /// what the board knows with what was read back from PARAGON laid over it. Worked out once per version of
    /// the board, not once per row.
    static func marks(for board: Board) -> [UUID: TodoState] {
        let read = ParagonEcho.shared.read[board.id] ?? [:]
        // What the marks depend on: which things are ticked "to do", and what was sent.
        var hasher = Hasher()
        for item in board.items where item.todo { hasher.combine(item.id) }
        hasher.combine(board.items.count)
        hasher.combine(board.sentTasks.count)
        hasher.combine(board.sentTodos.count)
        let stamp = hasher.finalize()
        lock.lock(); defer { lock.unlock() }
        if let kept, kept.board == board.id, kept.stamp == stamp, kept.read == read { return kept.marks }
        let marks = ParagonEcho.shared.marks(for: board)
        kept = (board.id, stamp, read, marks)
        return marks
    }

    private static let lock = NSLock()
    private static var kept: (board: UUID, stamp: Int, read: [UUID: TodoState], marks: [UUID: TodoState])?

    /// Whether the thing's words are greyed: it is finished with in PARAGON.
    static func greysWords(_ state: TodoState?) -> Bool { state == .done || state == .cancelled }

    /// PARAGON's purple: the strong shade by day, the lighter one by night for the hollow ring's line.
    private static func purple(_ paint: Paint, line: Bool) -> Color {
        line && paint.night ? Color(red: 0xB5 / 255, green: 0x9C / 255, blue: 0xEB / 255) : Part.paragon.fill
    }

    /// The boards' green, a little deeper by night than the board's own "chosen" green so the white tick reads.
    private static func green(_ paint: Paint) -> Color {
        paint.night ? Color(red: 0x3F / 255, green: 0xA2 / 255, blue: 0x6C / 255) : Color(red: 0x2E / 255, green: 0x8B / 255, blue: 0x57 / 255)
    }

    private static func grey(_ paint: Paint) -> Color {
        paint.night ? Color(red: 0x7A / 255, green: 0x81 / 255, blue: 0x8C / 255) : Color(red: 0x8B / 255, green: 0x94 / 255, blue: 0xA1 / 255)
    }

    /// Draws the mark with its middle at `c`. `ground` is what lies behind it (the board, a plate, a patch):
    /// the hollow ring is filled with it, so a line running under the ring does not show through.
    static func draw(_ state: TodoState, at c: CGPoint, radius r: CGFloat = TodoMark.radius, paint: Paint, ground: Color,
                     _ ctx: inout GraphicsContext) {
        let k = r / 7.5
        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        func tick() {
            var mark = Path()
            mark.move(to: CGPoint(x: c.x - 3.4 * k, y: c.y + 0.2 * k))
            mark.addLine(to: CGPoint(x: c.x - 0.9 * k, y: c.y + 2.8 * k))
            mark.addLine(to: CGPoint(x: c.x + 3.6 * k, y: c.y - 2.6 * k))
            ctx.stroke(mark, with: .color(.white), style: StrokeStyle(lineWidth: 1.7 * k, lineCap: .round, lineJoin: .round))
        }
        switch state {
        case .waiting:
            ctx.fill(disc, with: .color(ground))
            let line: CGFloat = 1.8 * k
            let ring = Path(ellipseIn: CGRect(x: c.x - r + line / 2, y: c.y - r + line / 2, width: r * 2 - line, height: r * 2 - line))
            ctx.stroke(ring, with: .color(purple(paint, line: true)), lineWidth: line)
        case .inParagon:
            // 0.14 (mark check #2): a white arrow pointing up and out — "it went on to PARAGON". A tick means done only.
            ctx.fill(disc, with: .color(purple(paint, line: false)))
            var arrow = Path()
            arrow.move(to: CGPoint(x: c.x - 2.9 * k, y: c.y + 2.9 * k))
            arrow.addLine(to: CGPoint(x: c.x + 2.9 * k, y: c.y - 2.9 * k))
            arrow.move(to: CGPoint(x: c.x - 1.0 * k, y: c.y - 2.9 * k))
            arrow.addLine(to: CGPoint(x: c.x + 2.9 * k, y: c.y - 2.9 * k))
            arrow.addLine(to: CGPoint(x: c.x + 2.9 * k, y: c.y + 1.0 * k))
            ctx.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: 1.7 * k, lineCap: .round, lineJoin: .round))
        case .done:
            ctx.fill(disc, with: .color(green(paint)))
            tick()
        case .cancelled:
            ctx.fill(disc, with: .color(grey(paint)))
            var dash = Path()
            dash.move(to: CGPoint(x: c.x - 3.3 * k, y: c.y))
            dash.addLine(to: CGPoint(x: c.x + 3.3 * k, y: c.y))
            ctx.stroke(dash, with: .color(.white), style: StrokeStyle(lineWidth: 1.8 * k, lineCap: .round))
        }
    }
}
