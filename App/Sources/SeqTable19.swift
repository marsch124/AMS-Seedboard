import SwiftUI
import SeedboardCore

// 0.19, "Who does what" and tables: the SF Symbol names, the page for a message's note, the springs that make room
// while a message is dragged, and what a table remembers about its last sort. The rules are in Core
// (Sequence19.swift, Table19.swift).

/// Every SF Symbol this lane adds, in one place so the lead can swap a name.
enum SeqTable19Marks {
    /// "Note…" on a chosen message: the grey box beside it.
    static let note = "note.text"
    /// "Tick Column" on a chosen table.
    static let tickColumn = "checklist"
    /// The small chevron in a sorted column's heading: A to Z (up) and Z to A (down).
    static let sortUp = "chevron.up"
    static let sortDown = "chevron.down"
}

/// What the screens of this lane share: the note page that is open, and the sort each table was last given.
@MainActor
final class SeqTable19Desk: ObservableObject {
    static let shared = SeqTable19Desk()

    /// The message whose note is being written, and the words so far.
    @Published var noteFor: UUID?
    @Published var noteText = ""

    func askNote(for message: Item) {
        guard message.kind == .message else { return }
        noteText = message.note ?? ""
        noteFor = message.id
    }

}

/// Each table's last sort: column and way. It shows (the chevron, the next tap's way) only while the cells still stand
/// exactly that way, so any other change to the table forgets it. Kept apart from the screens: the painter reads it too.
final class TableSortMemory: @unchecked Sendable {
    static let shared = TableSortMemory()
    private let lock = NSLock()
    private var sorts: [UUID: (column: Int, ascending: Bool)] = [:]

    func remember(_ sort: (column: Int, ascending: Bool), of table: UUID) {
        lock.lock(); defer { lock.unlock() }
        sorts[table] = sort
    }

    func sortOf(_ table: Item) -> (column: Int, ascending: Bool)? {
        lock.lock()
        let last = sorts[table.id]
        lock.unlock()
        guard let last else { return nil }
        let cells = TableRules.squared(table.cells)
        return TableRules.sorted(cells, column: last.column, ascending: last.ascending) == cells ? last : nil
    }
}

/// "Note…": a page with one field, Cancel (Escape on the Mac) and Save. Empty words and Save take the note away.
struct SequenceNotePage: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = SeqTable19Desk.shared
    @FocusState private var focus: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Words beside the message", text: $desk.noteText, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($focus)
                        .accessibilityIdentifier("note.field")
                } footer: {
                    Text("A grey box beside the message. Leave it empty and press Save to take the note away.")
                }
            }
            .navigationTitle("Note")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { close() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("note.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("note.save")
                }
            }
            .onAppear { focus = true }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 200)
        #else
        .presentationDetents([.medium])
        #endif
    }

    private func close() {
        desk.noteFor = nil
        session.takeKeys()
    }

    private func save() {
        if let id = desk.noteFor { let words = desk.noteText; session.change { $0.setNote(words, of: id) } }
        close()
    }
}

/// The springs that move the steps and blocks of a diagram out of the way of a dragged message.
/// Each number is how far something is from its place (down is positive); it is pulled to its target.
final class SequenceRoomSprings {
    private(set) var room = SequenceRoom()
    private(set) var after = SequenceLayout()
    private(set) var before = SequenceLayout()
    private var rows: [UUID: Double] = [:], rowSpeed: [UUID: Double] = [:]
    private var tops: [UUID: Double] = [:], topSpeed: [UUID: Double] = [:]
    private var bottoms: [UUID: Double] = [:], bottomSpeed: [UUID: Double] = [:]
    private var last: Date?
    private(set) var slot: Int?
    /// With Reduce Motion on, everything goes straight to its place.
    var still = false

    /// The diagram as it stands, when a drag begins.
    func start(before: SequenceLayout) {
        self.before = before
        after = before
        room = SequenceRoom()
        rows = [:]; rowSpeed = [:]; tops = [:]; topSpeed = [:]; bottoms = [:]; bottomSpeed = [:]
        last = nil
        slot = nil
    }

    func end() { slot = nil; room = SequenceRoom(); after = before; rows = [:]; rowSpeed = [:]; tops = [:]; topSpeed = [:]; bottoms = [:]; bottomSpeed = [:] }

    /// The dragged message is now over this place in the order.
    func aim(_ slot: Int, board: Board, moving: UUID) {
        guard slot != self.slot else { return }
        self.slot = slot
        let result = slot == before.index(of: moving) ? (before, SequenceRoom()) : board.sequenceRoom(moving: moving, to: slot, before: before)
        after = result.0
        room = result.1
        if still { rows = room.rows; tops = room.blockTop; bottoms = room.blockBottom }
    }

    /// True while something is still on its way.
    var moving: Bool {
        func busy(_ now: [UUID: Double], _ target: [UUID: Double], _ speed: [UUID: Double]) -> Bool {
            Set(now.keys).union(target.keys).contains { abs((now[$0] ?? 0) - (target[$0] ?? 0)) > 0.05 || abs(speed[$0] ?? 0) > 0.5 }
        }
        return busy(rows, room.rows, rowSpeed) || busy(tops, room.blockTop, topSpeed) || busy(bottoms, room.blockBottom, bottomSpeed)
    }

    /// The diagram with everything where its spring has it at `now`.
    func layout(at now: Date) -> SequenceLayout {
        let dt = min(max(last.map { now.timeIntervalSince($0) } ?? 0, 0), 0.05)
        last = now
        func step(_ pos: inout [UUID: Double], _ speed: inout [UUID: Double], _ target: [UUID: Double]) {
            for id in Set(pos.keys).union(target.keys) {
                var x = pos[id] ?? 0, v = speed[id] ?? 0
                let goal = target[id] ?? 0
                // A soft spring: it settles in about a third of a second, with a small overshoot.
                var left = dt
                while left > 0 {
                    let h = min(left, 1.0 / 240)
                    v += (260 * (goal - x) - 24 * v) * h
                    x += v * h
                    left -= h
                }
                pos[id] = x; speed[id] = v
            }
        }
        if still {
            rows = room.rows; tops = room.blockTop; bottoms = room.blockBottom
        } else {
            step(&rows, &rowSpeed, room.rows)
            step(&tops, &topSpeed, room.blockTop)
            step(&bottoms, &bottomSpeed, room.blockBottom)
        }
        return before.shifted(rows: rows, blockTop: tops, blockBottom: bottoms, after: after)
    }
}

/// The tick box of a table's tick column, drawn in the one green that means "done" in the whole app.
enum TickBoxLook {
    static func green(_ paint: Paint) -> Color {
        paint.night ? Color(red: 0x3F / 255, green: 0xA2 / 255, blue: 0x6C / 255) : Color(red: 0x2E / 255, green: 0x8B / 255, blue: 0x57 / 255)
    }

    /// One box with its middle at `c`: hollow when not done, full green with a white tick when done.
    static func draw(ticked: Bool, at c: CGPoint, paint: Paint, _ ctx: inout GraphicsContext) {
        let box = CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)
        let shape = Path(roundedRect: box, cornerRadius: 4)
        if ticked {
            ctx.fill(shape, with: .color(green(paint)))
            var mark = Path()
            mark.move(to: CGPoint(x: c.x - 4, y: c.y + 0.3))
            mark.addLine(to: CGPoint(x: c.x - 1.2, y: c.y + 3.2))
            mark.addLine(to: CGPoint(x: c.x + 4.2, y: c.y - 3))
            ctx.stroke(mark, with: .color(.white), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
        } else {
            ctx.stroke(Path(roundedRect: box.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 3.5), with: .color(paint.faint), lineWidth: 1.5)
        }
    }
}
