import Foundation
import CoreGraphics

// 0.14: blocks in a "Who does what" board — a thin frame round some messages with a word in a small
// tab ("repeat", "if", "maybe"), like the loop / alt / opt boxes of real sequence diagrams.
// A block is an `ItemKind.block` item: `text` is its word, `from` and `to` the first and the last
// message it holds, `colour` its colour. It has no place of its own: the layout puts it round the
// messages from its first to its last every time, so it follows them when they move.

/// A block resolved against the steps: the places of its first and last message in the order.
public struct SequenceBlockFrame: Equatable, Sendable {
    public var id: UUID
    /// The place (in `Board.steps`) of the upper and of the lower end.
    public var lo: Int
    public var hi: Int
    /// Where the block stands among the items: the one made first is the outer of two equal ones.
    public var position: Int
}

public extension Board {
    /// The words the Block menu offers, with the colour each starts in.
    static let blockWords: [(word: String, colour: String)] = [("repeat", "teal"), ("if", "orange"), ("maybe", "blue")]

    /// The blocks that can be drawn (both ends are messages on this board), the outer ones first:
    /// from the top, longer before shorter, the older before the newer.
    func sequenceBlockFrames() -> [SequenceBlockFrame] {
        var at: [UUID: Int] = [:]
        for (n, step) in steps.enumerated() where isDrawnMessage(step) { at[step.id] = n }
        var out: [SequenceBlockFrame] = []
        for (i, block) in items.enumerated() where block.kind == .block {
            guard let a = block.from.flatMap({ at[$0] }), let b = block.to.flatMap({ at[$0] }) else { continue }
            out.append(SequenceBlockFrame(id: block.id, lo: min(a, b), hi: max(a, b), position: i))
        }
        return out.sorted { ($0.lo, -$0.hi, $0.position) < ($1.lo, -$1.hi, $1.position) }
    }

    /// How deep each block lies inside others, counted from inside: a block with no block in it is
    /// 0, one that holds it is 1 …  (`frames` as `sequenceBlockFrames` gives them.)
    static func blockLevels(_ frames: [SequenceBlockFrame]) -> [UUID: Int] {
        var level: [UUID: Int] = [:]
        for i in frames.indices.reversed() {
            let inside = frames[(i + 1)...].filter { $0.hi <= frames[i].hi }.compactMap { level[$0.id] }
            level[frames[i].id] = (inside.max()).map { $0 + 1 } ?? 0
        }
        return level
    }

    /// The blocks of the board, in the order they were made.
    var blocks: [Item] { items.filter { $0.kind == .block } }

    /// The drawn messages a block holds, from its first to its last.
    func messages(in block: UUID) -> [UUID] {
        guard let frame = sequenceBlockFrames().first(where: { $0.id == block }) else { return [] }
        return steps.enumerated().filter { $0.offset >= frame.lo && $0.offset <= frame.hi && isDrawnMessage($0.element) }.map(\.element.id)
    }

    /// A block round the chosen messages, from the first to the last of them in the order (what lies
    /// between is held too). Only messages count; nil when none is chosen. Its word is `word`.
    @discardableResult
    mutating func addBlock(round ids: Set<UUID>, word: String, colour: String? = nil) -> UUID? {
        let chosen = steps.filter { ids.contains($0.id) && isDrawnMessage($0) }
        guard let first = chosen.first, let last = chosen.last else { return nil }
        var block = Item(kind: .block, text: word)
        block.from = first.id
        block.to = last.id
        block.colour = colour ?? Board.blockWords.first { $0.word == word.lowercased() }?.colour ?? ""
        items.append(block)
        return block.id
    }

    /// After messages went: a block that lost its first or its last message shrinks to what is left
    /// of it; a block with nothing left goes. `held` is what each block held before.
    mutating func keepBlocks(held: [UUID: [UUID]]) {
        let order = steps.map(\.id)
        for block in blocks {
            guard let before = held[block.id] else { continue }
            let left = order.filter { id in before.contains(id) && isDrawnMessage(item(id) ?? block) }
            guard let first = left.first, let last = left.last, let i = index(of: block.id) else {
                items.removeAll { $0.id == block.id }
                continue
            }
            items[i].from = first
            items[i].to = last
        }
    }

    /// The count in words for blocks ("2 blocks"), nil when there are none.
    var blockCountWords: String? {
        let n = blocks.count
        return n == 0 ? nil : (n == 1 ? "1 block" : "\(n) blocks")
    }
}

public extension ParagonExport {
    /// What a block's tab says: its word on one line, "block" when it has none.
    static func blockTabWord(_ block: Item) -> String {
        let words = oneLine(block.text)
        return words.isEmpty ? "block" : words
    }

    /// A block's word as the line that opens it: "Repeat:"; a block without a word says "Block:".
    static func blockHead(_ block: Item) -> String {
        let words = oneLine(block.text)
        guard let first = words.first else { return "Block:" }
        return first.uppercased() + words.dropFirst() + ":"
    }

    /// For the steps in order: the lines that open blocks right before a step ("Repeat:", each
    /// one three spaces deeper than the block it lies in), and how many blocks hold the step.
    static func blockWriting(_ board: Board) -> (heads: [Int: [String]], depth: [Int: Int]) {
        let frames = board.sequenceBlockFrames()
        var heads: [Int: [String]] = [:]
        var depth: [Int: Int] = [:]
        for (i, frame) in frames.enumerated() {
            let holders = frames[..<i].filter { $0.hi >= frame.hi }.count
            if let block = board.item(frame.id) {
                heads[frame.lo, default: []].append(String(repeating: "   ", count: holders) + blockHead(block))
            }
            for n in frame.lo...frame.hi { depth[n, default: 0] += 1 }
        }
        return (heads, depth)
    }
}
