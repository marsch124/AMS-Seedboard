import Foundation
import CoreGraphics

// 0.19, "Who does what": a message dragged to another place (the rest make room, the blocks keep the right messages)
// and the grey note box beside a message.

/// The grey note box beside a message (`Item.note`): its size and where it stands. Not the "Note" band that goes across
/// the lines (`ItemKind.band`): that one is a step of its own; this one belongs to one message and has no number.
public enum SequenceNote {
    /// The box is at most this wide; longer words wrap.
    public static let width = 150.0
    /// The room round the words inside, the height of a line of caption words, a rough width of one letter.
    public static let pad = 7.0
    public static let lineHeight = 14.0
    public static let letter = 6.0
    /// The room between the message's line (or its words) and the box.
    public static let gap = 12.0

    /// The words of a note with nothing around them; nil when there are none.
    public static func words(_ note: String?) -> String? {
        guard let note else { return nil }
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    public static func has(_ item: Item) -> Bool { item.kind == .message && words(item.note) != nil }

    /// How many lines the words take in a box this wide (a rough count: letters per line).
    public static func lines(of text: String) -> Int {
        let perLine = max(1, Int((width - 2 * pad) / letter))
        return text.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { total, line in
            total + max(1, Int((Double(line.count) / Double(perLine)).rounded(.up)))
        }
    }

    public static func size(of note: String) -> CGSize {
        let text = words(note) ?? ""
        let longest = text.split(separator: "\n").map(\.count).max() ?? 0
        let wide = min(width, Double(longest) * letter + 2 * pad)
        return CGSize(width: max(54, wide), height: Double(lines(of: text)) * lineHeight + 2 * pad)
    }

    /// The left edge of the box: right of the message's lines and of its words (and its to-do ring).
    static func left(of message: Item, from: Double, to: Double, label: Double, m: SequenceMetrics) -> Double {
        let loop = message.from == message.to
        let start = loop ? from + m.loopWidth + 8 : (from + to) / 2 - label / 2
        let reach = loop ? start + label : max(max(from, to), start + label)
        return reach + (message.todo ? 22 : 0) + gap
    }

    /// Words for the menu line and the page.
    public static let menuWord = "Note…"
}

public extension Board {
    /// A message's note changed (empty words take it away). False when it is not a message or nothing changed.
    @discardableResult
    mutating func setNote(_ words: String, of id: UUID) -> Bool {
        guard let i = index(of: id), items[i].kind == .message else { return false }
        let new = SequenceNote.words(words)
        guard items[i].note != new else { return false }
        items[i].note = new
        return true
    }

    /// After message `moved` took another place: a block that held it keeps it only when it stands between the others
    /// the block held; a block with other messages that it now stands outside of lets it go (the block shrinks to what is
    /// left, from its new first to its new last). A block that held only it follows it.
    internal mutating func keepBlocksAfterMove(of moved: UUID, held: [UUID: [UUID]]) {
        let order = steps.map(\.id)
        var keep: [UUID: [UUID]] = [:]
        for (block, list) in held where list.contains(moved) {
            let rest = list.filter { $0 != moved }
            let places = rest.compactMap { order.firstIndex(of: $0) }
            guard let lo = places.min(), let hi = places.max(), let at = order.firstIndex(of: moved) else { continue }
            if at < lo || at > hi { keep[block] = rest }
        }
        if !keep.isEmpty { keepBlocks(held: keep) }
    }

    /// What dragging message `id` to place `slot` would do to the diagram: the diagram as it would stand, and for every
    /// step and block how far it moves from where it is now. `before` is the diagram as it stands.
    func sequenceRoom(moving id: UUID, to slot: Int, before: SequenceLayout) -> (after: SequenceLayout, room: SequenceRoom) {
        var preview = self
        preview.moveStep(id, to: slot)
        let after = preview.sequenceLayout(before.metrics)
        var room = SequenceRoom()
        for row in before.rows {
            guard let to = after.row(row.id) else { continue }
            room.rows[row.id] = to.top - row.top
        }
        for block in before.blocks {
            guard let to = after.blocks.first(where: { $0.id == block.id }) else { continue }
            room.blockTop[block.id] = Double(to.rect.minY - block.rect.minY)
            room.blockBottom[block.id] = Double(to.rect.maxY - block.rect.maxY)
        }
        return (after, room)
    }
}

/// How far each step and block moves (board points, down is positive) when a dragged message lands.
public struct SequenceRoom: Equatable, Sendable {
    public var rows: [UUID: Double] = [:]
    public var blockTop: [UUID: Double] = [:]
    public var blockBottom: [UUID: Double] = [:]
    public init() {}
}

public extension SequenceLayout {
    /// This diagram with every step moved down by `rows`, and every block's top and bottom edge by `blockTop` and
    /// `blockBottom`; a block takes its sides from `after` (the diagram as it will stand). What is not named stays.
    func shifted(rows dy: [UUID: Double], blockTop top: [UUID: Double], blockBottom bottom: [UUID: Double], after: SequenceLayout) -> SequenceLayout {
        var out = self
        for i in out.rows.indices {
            let d = dy[out.rows[i].id] ?? 0
            guard d != 0 else { continue }
            out.rows[i].top += d
            out.rows[i].lineY += d
            out.rows[i].words.origin.y += CGFloat(d)
            out.rows[i].box.origin.y += CGFloat(d)
            if out.rows[i].badge != nil { out.rows[i].badge!.y += CGFloat(d) }
            if let note = out.notes[out.rows[i].id] { out.notes[out.rows[i].id] = note.offsetBy(dx: 0, dy: CGFloat(d)) }
        }
        for i in out.blocks.indices {
            let id = out.blocks[i].id
            let old = out.blocks[i].rect
            let y0 = old.minY + CGFloat(top[id] ?? 0), y1 = old.maxY + CGFloat(bottom[id] ?? 0)
            let side = after.blocks.first { $0.id == id }?.rect ?? old
            out.blocks[i].rect = CGRect(x: side.minX, y: y0, width: side.width, height: max(0, y1 - y0))
        }
        return out
    }
}
