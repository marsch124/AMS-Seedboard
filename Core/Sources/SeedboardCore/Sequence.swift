import Foundation
import CoreGraphics

// The "Who does what" board: a sequence diagram. The people (or systems) stand in a row at the top,
// each with a dashed line hanging down; a message is a level arrow from one line to another, and the
// messages follow each other from top to bottom, numbered 1, 2, 3 … A dashed arrow is an answer.
// A note is a soft band across the lines, a section is a heading line across the whole diagram.
// The owner never places anything: the row order of the names and the order of the steps is all that
// is kept; every place on screen comes from `SequenceLayout`. No screen in here: each rule has a data test.

// MARK: What is kept in the file

public extension ItemKind {
    /// A message, a note across the lines or a section heading: what stands in the order from top to bottom.
    var isStep: Bool { self == .message || self == .band || self == .section }
    /// A name with its line, or a step: the four things of a "Who does what" board.
    var isSequence: Bool { self == .who || isStep || self == .block }
}

public extension Item {
    /// A message that is an answer: drawn with dashes.
    var isAnswer: Bool {
        get { answer == true }
        set { answer = newValue ? true : nil }
    }

    /// A message from a name to itself: a small loop on its own line.
    var isToItself: Bool { kind == .message && from != nil && from == to }
}

// MARK: Sizes

/// The sizes a "Who does what" diagram is laid out with, in board points.
public struct SequenceMetrics: Equatable, Sendable {
    /// Empty room at the left and the right of the diagram.
    public var margin = 28.0
    /// Above the name boxes.
    public var top = 20.0
    /// A name box: the room round its name, and its least size.
    public var boxPadX = 14.0
    public var boxPadY = 8.0
    public var boxMinWidth = 92.0
    public var boxMinHeight = 34.0
    /// The least room between two name boxes.
    public var boxGap = 24.0
    /// The least distance between two dashed lines.
    public var laneGap = 150.0
    /// Between the name boxes and the first step.
    public var headGap = 12.0
    /// The round number before a message's words, and the room between the two.
    public var badge = 18.0
    public var badgeGap = 5.0
    /// The room a message's words keep from the two lines they stand between.
    public var wordsPad = 14.0
    /// A message: above its words, between the words and the arrow, under the arrow.
    public var rowTop = 9.0
    public var wordsGap = 4.0
    public var rowBottom = 9.0
    /// The height of one line of words.
    public var lineHeight = 17.0
    /// A message to itself: how far its loop goes out and how tall it is.
    public var loopWidth = 30.0
    public var loopHeight = 20.0
    /// A note across the lines: the room round its words, and the room above and under the band.
    public var bandPadX = 12.0
    public var bandPadY = 6.0
    public var bandGap = 6.0
    /// A section heading: the room above it (a new part begins) and under it.
    public var sectionTop = 14.0
    public var sectionBottom = 8.0
    /// How far the dashed lines go on under the last step: room to drop the next message.
    public var tail = 40.0
    /// 0.14, a block: the room above its first message (for its tab) and under its last, the room
    /// its frame keeps from the messages, and how much more each block it holds adds to that.
    public var blockHead = 20.0
    public var blockFoot = 8.0
    public var blockPad = 12.0
    public var blockNest = 8.0
    /// The dashed lines are never shorter than this.
    public var leastLine = 96.0
    /// Under the ends of the dashed lines.
    public var bottom = 16.0

    public init() {}
}

/// Where everything of a "Who does what" diagram is: the names from the left, the steps from the top.
/// The diagram's own box starts at (0, 0).
public struct SequenceLayout: Equatable, Sendable {
    /// One step with its place.
    public struct Row: Equatable, Sendable {
        public var id: UUID
        public var kind: ItemKind
        /// The top of the step and how tall it is.
        public var top: Double
        public var height: Double
        /// A message: the height of its arrow (the upper line of a loop), and where it starts and ends.
        /// A section: the height of its line.
        public var lineY: Double
        public var fromX: Double
        public var toX: Double
        /// 1, 2, 3 … for a message; nil for a note and a section.
        public var number: Int?
        /// Where the words stand.
        public var words: CGRect
        /// The middle of the round number; nil for a note and a section.
        public var badge: CGPoint?
        /// What a press must hit, and what a ring is drawn round: the number with the words (a message),
        /// the band (a note), the words (a section).
        public var box: CGRect
        /// A message from a name to itself.
        public var loop: Bool

        public var bottom: Double { top + height }
        public var middle: Double { top + height / 2 }
    }

    /// The names from the left.
    public var whos: [UUID] = []
    /// The dashed line of each name.
    public var x: [UUID: Double] = [:]
    /// The name boxes, where they stand when nothing is pinned.
    public var boxes: [UUID: CGRect] = [:]
    /// 0.14: a block's place round its messages.
    public struct Block: Equatable, Sendable {
        public var id: UUID
        public var rect: CGRect
        /// 0 for a block with no block in it, 1 for one that holds such a block …
        public var level: Int
    }

    /// The steps from the top (a message that has lost one of its names is left out).
    public var rows: [Row] = []
    /// The blocks, the outer ones first.
    public var blocks: [Block] = []
    /// The left and the right edge of what is drawn (inside the margins).
    public var left = 0.0
    public var right = 0.0
    /// The top and the bottom of the name boxes.
    public var boxTop = 0.0
    public var boxBottom = 0.0
    /// Where the first step begins.
    public var firstTop = 0.0
    /// Where the dashed lines end.
    public var lineBottom = 0.0
    public var size = CGSize.zero
    public var metrics = SequenceMetrics()

    public func row(_ id: UUID) -> Row? { rows.first { $0.id == id } }

    /// The place a step has now, 0 at the top.
    public func index(of id: UUID) -> Int? { rows.firstIndex { $0.id == id } }

    /// The new place in the order for a y: how many steps (other than the one being moved) have their
    /// middle above it. 0 = before the first, the count = after the last.
    public func slot(atY y: Double, moving: UUID? = nil) -> Int {
        rows.filter { $0.id != moving && $0.middle < y }.count
    }

    /// The height of the thin line that shows where a step will land for a place in the order.
    public func landingY(slot: Int, moving: UUID? = nil) -> Double {
        let others = rows.filter { $0.id != moving }
        guard let last = others.last else { return firstTop }
        return slot < others.count ? others[max(slot, 0)].top : last.bottom
    }

    /// The new place in the row for an x: how many names (other than the one being moved) have their
    /// line left of it.
    public func whoSlot(atX px: Double, moving: UUID? = nil) -> Int {
        whos.filter { $0 != moving && (x[$0] ?? 0) < px }.count
    }

    /// Where the thin upright line stands that shows the place a name will land in the row.
    public func whoLandingX(slot: Int, moving: UUID? = nil) -> Double {
        let others = whos.filter { $0 != moving }.compactMap { boxes[$0] }
        guard let first = others.first, let last = others.last else { return left }
        if slot <= 0 { return Double(first.minX) - metrics.boxGap / 2 }
        if slot >= others.count { return Double(last.maxX) + metrics.boxGap / 2 }
        return (Double(others[slot - 1].maxX) + Double(others[slot].minX)) / 2
    }

    /// The name whose dashed line is nearest to an x, when it is within reach.
    public func who(nearX px: Double, reach: Double) -> UUID? {
        let found = whos.compactMap { id in x[id].map { (id, abs($0 - px)) } }.min { $0.1 < $1.1 }
        guard let found, found.1 <= reach else { return nil }
        return found.0
    }

    /// How far the name boxes are moved down so they stay in sight when the diagram is slid up:
    /// `top` is the upper edge of what is seen, `inset` the room the names keep from it.
    public func pinShift(top: Double?, inset: Double = 8) -> Double {
        guard let top else { return 0 }
        return max(0, top + inset - boxTop)
    }
}

// MARK: The rules

public extension Board {
    /// What `kind` holds for a "Who does what" board.
    static let sequenceKind = "sequence"

    var isSequence: Bool { kind == Board.sequenceKind }

    /// A board that places its own things (a timeline, a "Who does what"): nothing on it is moved by hand.
    var placesItself: Bool { isTimeline || isSequence }

    /// The colours new names take, one after the other.
    static let whoColours = ["blue", "teal", "orange", "yellow", "green", "pink", "red"]   // 0.17: no purple (PARAGON)

    /// A new, empty "Who does what" board.
    static func sequence(title: String = "Who does what", created: Date = Date()) -> Board {
        var board = Board(title: title, created: created)
        board.kind = Board.sequenceKind
        return board
    }

    /// The starter: Alex asks the bank, the bank answers, Alex orders the build.
    static func sequenceStart(title: String = "Who does what", now: Date = Date()) -> Board {
        var board = Board.sequence(title: title, created: now)
        let anna = board.addWho("Alex")
        let bank = board.addWho("Bank")
        let builder = board.addWho("Builder")
        board.addMessage("Ask for loan", from: anna, to: bank)
        board.addMessage("Yes", from: bank, to: anna, answer: true)
        board.addMessage("Order the build", from: anna, to: builder)
        return board
    }

    // MARK: The order

    /// The names from the left (two with the same number stay in the order they were made).
    var whos: [Item] {
        items.enumerated().filter { $0.element.kind == .who }
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
            .map(\.element)
    }

    /// The steps from the top: messages, notes and sections.
    var steps: [Item] {
        items.enumerated().filter { $0.element.kind.isStep }
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
            .map(\.element)
    }

    /// True when a message stands between two names that are on this board. A message from a file
    /// made elsewhere may name someone who is not there: it is not drawn, so it is not counted or
    /// written out either (it stays in the file).
    func isDrawnMessage(_ step: Item) -> Bool {
        guard step.kind == .message, let from = step.from, let to = step.to else { return false }
        return item(from)?.kind == .who && item(to)?.kind == .who
    }

    /// The number of every message: 1, 2, 3 … from the top. Notes, sections and messages that cannot be
    /// drawn are not counted.
    var messageNumbers: [UUID: Int] {
        var numbers: [UUID: Int] = [:]
        for step in steps where isDrawnMessage(step) { numbers[step.id] = numbers.count + 1 }
        return numbers
    }

    /// The box a small screen opens a "Who does what" board on: the first name, where the layout puts it
    /// (the items' own places mean nothing here). nil when there is no name.
    var sequenceMainFrame: CGRect? {
        guard let first = whos.first else { return nil }
        return sequenceLayout().boxes[first.id]
    }

    /// The place a name has in the row, 0 at the left.
    func whoIndex(of id: UUID) -> Int? { whos.firstIndex { $0.id == id } }

    /// The place a step has in the order, 0 at the top.
    func stepIndex(of id: UUID) -> Int? { steps.firstIndex { $0.id == id } }

    private mutating func number(_ order: [UUID]) {
        for (n, id) in order.enumerated() {
            if let i = index(of: id) { items[i].order = Double(n + 1) }
        }
    }

    private mutating func insert(_ item: Item, among order: [UUID], at place: Int?) {
        var order = order
        order.insert(item.id, at: min(max(place ?? order.count, 0), order.count))
        items.append(item)
        number(order)
    }

    /// The room words take before the app has measured them: about 7.4 points a letter, one line.
    internal static func roughWords(_ text: String) -> (w: Double, h: Double) {
        let letters = ParagonExport.oneLine(text).count
        return (letters == 0 ? 0 : min(240, 7.4 * Double(letters) + 4), 17)
    }

    private static func sequenceItem(_ kind: ItemKind, _ text: String) -> Item {
        let room = roughWords(text)
        return Item(kind: kind, text: text, w: room.w, h: room.h)
    }

    // MARK: Adding

    /// A new name with its dashed line. Without a place it stands at the right end of the row.
    /// Without a colour it takes the first one no other name wears.
    @discardableResult
    mutating func addWho(_ name: String = "", at place: Int? = nil, colour: String = "") -> UUID {
        var item = Board.sequenceItem(.who, name)
        let worn = Set(whos.map(\.colour))
        item.colour = colour.isEmpty
            ? (Board.whoColours.first { !worn.contains($0) } ?? Board.whoColours[whos.count % Board.whoColours.count])
            : colour
        insert(item, among: whos.map(\.id), at: place)
        return item.id
    }

    /// A new message from one name to another (the same name twice: a message to itself). Without a
    /// place it goes under the last step. nil when one of the two is not a name on this board.
    @discardableResult
    mutating func addMessage(_ text: String = "", from: UUID, to: UUID, at place: Int? = nil, answer: Bool = false) -> UUID? {
        guard item(from)?.kind == .who, item(to)?.kind == .who else { return nil }
        var item = Board.sequenceItem(.message, text)
        item.from = from
        item.to = to
        item.isAnswer = answer
        insert(item, among: steps.map(\.id), at: place)
        return item.id
    }

    /// A new note: a soft band across the lines.
    @discardableResult
    mutating func addBand(_ text: String = "", at place: Int? = nil, colour: String = "") -> UUID {
        var item = Board.sequenceItem(.band, text)
        item.colour = colour
        insert(item, among: steps.map(\.id), at: place)
        return item.id
    }

    /// A new section: a heading line across the whole diagram.
    @discardableResult
    mutating func addSection(_ text: String = "", at place: Int? = nil) -> UUID {
        insert(Board.sequenceItem(.section, text), among: steps.map(\.id), at: place)
        return items[items.count - 1].id
    }

    /// True when a message put at this place would be an answer: the message right above it goes the
    /// other way between the same two names and is not an answer itself.
    func wouldAnswer(from: UUID, to: UUID, at place: Int? = nil) -> Bool {
        let all = steps
        let at = min(max(place ?? all.count, 0), all.count)
        guard from != to, at > 0, all[at - 1].kind == .message else { return false }
        let above = all[at - 1]
        return above.from == to && above.to == from && !above.isAnswer
    }

    /// Return on a chosen message: the next message right under it, going the other way — as an
    /// answer when the chosen one was a question, as a new question when it was an answer.
    @discardableResult
    mutating func addMessageAfter(_ id: UUID) -> UUID? {
        guard let source = item(id), source.kind == .message, let from = source.from, let to = source.to,
              let place = stepIndex(of: id) else { return nil }
        return addMessage(from: to, to: from, at: place + 1, answer: from != to && !source.isAnswer)
    }

    // MARK: Changing

    /// Puts a step at another place in the order (0 = the top, counted without the step itself).
    /// True when its place changed.
    @discardableResult
    mutating func moveStep(_ id: UUID, to place: Int) -> Bool {
        var order = steps.map(\.id)
        guard let from = order.firstIndex(of: id) else { return false }
        order.remove(at: from)
        let at = min(max(place, 0), order.count)
        order.insert(id, at: at)
        number(order)
        return at != from
    }

    /// Puts a name at another place in the row (0 = the left end, counted without the name itself).
    /// Its messages go with it. True when its place changed.
    @discardableResult
    mutating func moveWho(_ id: UUID, to place: Int) -> Bool {
        var order = whos.map(\.id)
        guard let from = order.firstIndex(of: id) else { return false }
        order.remove(at: from)
        let at = min(max(place, 0), order.count)
        order.insert(id, at: at)
        number(order)
        return at != from
    }

    /// Turns a message round: it now goes from the name it went to.
    mutating func turnMessageRound(_ id: UUID) {
        guard let i = index(of: id), items[i].kind == .message else { return }
        (items[i].from, items[i].to) = (items[i].to, items[i].from)
    }

    /// How many messages come from or go to a name.
    func messageCount(of who: UUID) -> Int {
        items.filter { $0.kind == .message && ($0.from == who || $0.to == who) }.count
    }

    /// Removes names and steps. A name takes every message from it and to it along; the number of
    /// messages that went this way (not chosen themselves) comes back.
    @discardableResult
    mutating func removeFromSequence(_ ids: Set<UUID>) -> Int {
        let names = Set(ids.filter { item($0)?.kind == .who })
        let held = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, messages(in: $0.id)) })
        let along = items.filter { item in
            item.kind == .message && !ids.contains(item.id)
                && (item.from.map(names.contains) == true || item.to.map(names.contains) == true)
        }.map(\.id)
        remove(ids.union(along))
        keepBlocks(held: held)
        number(whos.map(\.id))
        number(steps.map(\.id))
        return along.count
    }

    /// Copies steps right under themselves, and names right beside themselves (a copied name has no
    /// messages yet). Returns the copies.
    @discardableResult
    mutating func duplicateInSequence(_ ids: Set<UUID>) -> Set<UUID> {
        var copies: Set<UUID> = []
        for source in steps.reversed() where ids.contains(source.id) {
            guard let place = stepIndex(of: source.id) else { continue }
            var copy = source
            copy.id = UUID()
            insert(copy, among: steps.map(\.id), at: place + 1)
            copies.insert(copy.id)
        }
        for source in whos.reversed() where ids.contains(source.id) {
            guard let place = whoIndex(of: source.id) else { continue }
            var copy = source
            copy.id = UUID()
            insert(copy, among: whos.map(\.id), at: place + 1)
            copies.insert(copy.id)
        }
        return copies
    }

    // MARK: Where everything is

    /// The whole diagram laid out. Every item's `w` and `h` is the room its words take (the app
    /// measures them; before that it is an estimate).
    func sequenceLayout(_ m: SequenceMetrics = SequenceMetrics()) -> SequenceLayout {
        var layout = SequenceLayout()
        layout.metrics = m
        let people = whos
        let all = steps
        let place = people.enumerated().reduce(into: [UUID: Int]()) { $0[$1.element.id] = $1.offset }
        func label(_ item: Item) -> Double { m.badge + (item.w > 0 ? m.badgeGap + item.w : 0) }

        // The names: each box as wide as its name, all as tall as the tallest.
        let widths = people.map { max(m.boxMinWidth, $0.w + 2 * m.boxPadX) }
        let boxHeight = max(m.boxMinHeight, (people.map(\.h).max() ?? 0) + 2 * m.boxPadY)

        // The distance between two neighbours: even, and wider where the boxes or the words need it.
        var gaps = [Double](repeating: m.laneGap, count: max(people.count - 1, 0))
        for i in gaps.indices { gaps[i] = max(gaps[i], (widths[i] + widths[i + 1]) / 2 + m.boxGap) }
        var roomAfterLast = 0.0
        var spans: [(first: Int, last: Int, need: Double, at: Int)] = []
        for (n, step) in all.enumerated() where step.kind == .message {
            guard let a = step.from.flatMap({ place[$0] }), let b = step.to.flatMap({ place[$0] }) else { continue }
            if a == b {
                // A message to itself: its loop and its words stand right of its own line.
                let need = m.loopWidth + 8 + label(step) + m.wordsPad
                if a < gaps.count { gaps[a] = max(gaps[a], need) } else { roomAfterLast = max(roomAfterLast, need) }
            } else {
                spans.append((min(a, b), max(a, b), label(step) + 2 * m.wordsPad, n))
            }
        }
        // Neighbours first, then the longer ways: what is still missing is shared by the gaps on the way.
        for span in spans.sorted(by: { ($0.last - $0.first, $0.at) < ($1.last - $1.first, $1.at) }) {
            let have = gaps[span.first..<span.last].reduce(0, +)
            guard have < span.need else { continue }
            let more = (span.need - have) / Double(span.last - span.first)
            for i in span.first..<span.last { gaps[i] += more }
        }

        var x = m.margin + (widths.first ?? 0) / 2
        for (n, who) in people.enumerated() {
            if n > 0 { x += gaps[n - 1] }
            let line = x.rounded()
            layout.whos.append(who.id)
            layout.x[who.id] = line
            layout.boxes[who.id] = CGRect(x: line - widths[n] / 2, y: m.top, width: widths[n], height: boxHeight)
        }
        layout.left = m.margin
        var right = m.margin + 240
        if let last = people.last, let line = layout.x[last.id] {
            right = max(line + (widths.last ?? 0) / 2, line + roomAfterLast)
        }
        // A note's words never run over the edge.
        for step in all where step.kind != .message { right = max(right, m.margin + step.w + 2 * m.bandPadX) }
        layout.right = right
        layout.boxTop = m.top
        layout.boxBottom = m.top + boxHeight
        layout.firstTop = layout.boxBottom + m.headGap

        // The steps, one under the other. A block leaves room above its first message for its tab
        // and under its last for its frame.
        let frames = sequenceBlockFrames()
        var opens: [Int: Int] = [:], closes: [Int: Int] = [:]
        for frame in frames { opens[frame.lo, default: 0] += 1; closes[frame.hi, default: 0] += 1 }
        var rowOfStep: [Int: Int] = [:]
        var top = layout.firstTop
        var number = 0
        for (at, step) in all.enumerated() {
            top += Double(opens[at] ?? 0) * m.blockHead
            let high = max(step.h, m.lineHeight)
            switch step.kind {
            case .message:
                guard let from = step.from.flatMap({ layout.x[$0] }), let to = step.to.flatMap({ layout.x[$0] }) else { continue }
                number += 1
                let wide = label(step)
                if step.from == step.to {
                    let tall = max(high, m.loopHeight)
                    let lineY = top + m.rowTop + (tall - m.loopHeight) / 2
                    let middle = lineY + m.loopHeight / 2
                    let start = from + m.loopWidth + 8
                    layout.rows.append(.init(
                        id: step.id, kind: .message, top: top, height: m.rowTop + tall + m.rowBottom,
                        lineY: lineY, fromX: from, toX: to, number: number,
                        words: CGRect(x: start + m.badge + m.badgeGap, y: middle - high / 2, width: step.w, height: high),
                        badge: CGPoint(x: start + m.badge / 2, y: middle),
                        box: CGRect(x: start, y: middle - high / 2, width: wide, height: high), loop: true))
                } else {
                    let start = (from + to) / 2 - wide / 2
                    let wordsTop = top + m.rowTop
                    layout.rows.append(.init(
                        id: step.id, kind: .message, top: top, height: m.rowTop + high + m.wordsGap + m.rowBottom,
                        lineY: wordsTop + high + m.wordsGap, fromX: from, toX: to, number: number,
                        words: CGRect(x: start + m.badge + m.badgeGap, y: wordsTop, width: step.w, height: high),
                        badge: CGPoint(x: start + m.badge / 2, y: wordsTop + m.lineHeight / 2),
                        box: CGRect(x: start, y: wordsTop, width: wide, height: high), loop: false))
                }
            case .band:
                let band = CGRect(x: layout.left, y: top + m.bandGap, width: right - layout.left, height: high + 2 * m.bandPadY)
                layout.rows.append(.init(
                    id: step.id, kind: .band, top: top, height: Double(band.height) + 2 * m.bandGap,
                    lineY: Double(band.midY), fromX: layout.left, toX: right, number: nil,
                    words: CGRect(x: Double(band.midX) - step.w / 2, y: Double(band.minY) + m.bandPadY, width: step.w, height: high),
                    badge: nil, box: band, loop: false))
            case .section:
                let words = CGRect(x: layout.left + 10, y: top + m.sectionTop, width: step.w, height: high)
                layout.rows.append(.init(
                    id: step.id, kind: .section, top: top, height: m.sectionTop + high + m.sectionBottom,
                    lineY: Double(words.midY), fromX: 0, toX: right + m.margin, number: nil,
                    words: words, badge: nil, box: words.insetBy(dx: -6, dy: -3), loop: false))
            default:
                continue
            }
            rowOfStep[at] = layout.rows.count - 1
            top = layout.rows[layout.rows.count - 1].bottom + Double(closes[at] ?? 0) * m.blockFoot
        }

        // The blocks, each round its messages from the first to the last, across every name they touch.
        let levels = Board.blockLevels(frames)
        for (i, frame) in frames.enumerated() {
            guard let a = rowOfStep[frame.lo], let b = rowOfStep[frame.hi] else { continue }
            let held = layout.rows[a...b].filter { $0.kind == .message }
            guard !held.isEmpty else { continue }
            let level = levels[frame.id] ?? 0
            let pad = m.blockPad + m.blockNest * Double(level)
            let minX = held.map { min($0.fromX, $0.toX, Double($0.box.minX)) }.min() ?? 0
            let maxX = held.map { max($0.fromX, $0.toX, Double($0.box.maxX)) }.max() ?? 0
            let sameStart = frames.filter { $0.lo == frame.lo }
            let k = sameStart.firstIndex { $0.id == frame.id } ?? 0
            let inner = frames[(i + 1)...].filter { $0.hi == frame.hi }.count
            let y0 = layout.rows[a].top - m.blockHead * Double(sameStart.count - k) + 3
            let y1 = layout.rows[b].bottom + m.blockFoot * Double(inner) + 4
            layout.blocks.append(.init(id: frame.id, rect: CGRect(x: minX - pad, y: y0, width: maxX - minX + 2 * pad, height: y1 - y0), level: level))
            right = max(right, maxX + pad)
        }
        layout.right = max(layout.right, right)

        layout.lineBottom = max(top + m.tail, layout.boxBottom + m.leastLine)
        layout.size = CGSize(width: right + m.margin, height: layout.lineBottom + m.bottom)
        return layout
    }

    // MARK: In words

    /// Short words for the list: "3 people · 3 messages · 1 note".
    var sequenceCountLine: String {
        func count(_ kind: ItemKind, _ one: String, _ many: String) -> String? {
            let n = items.filter { $0.kind == kind && (kind != .message || isDrawnMessage($0)) }.count
            return n == 0 ? nil : (n == 1 ? "1 \(one)" : "\(n) \(many)")
        }
        let parts = [count(.who, "person", "people"), count(.message, "message", "messages"),
                     count(.band, "note", "notes"), count(.section, "section", "sections"),
                     count(.block, "block", "blocks")].compactMap { $0 }
        return parts.isEmpty ? "Empty" : parts.joined(separator: " · ")
    }

    /// One step in words: "2. Bank answers Alex: Yes", a note's or a section's own words.
    func stepLine(_ id: UUID) -> String {
        guard let step = item(id) else { return "" }
        if step.kind == .message, let n = messageNumbers[id] { return "\(n). " + ParagonExport.messageLine(step, in: self) }
        return ParagonExport.oneLine(step.text)
    }

    /// The diagram as plain text to copy: who is in it, then the steps in order.
    var sequenceText: String {
        var lines: [String] = []
        let names = whos.map { ParagonExport.whoName($0) }
        if !names.isEmpty { lines.append("Who: " + names.joined(separator: ", ")); lines.append("") }
        let numbers = messageNumbers
        let writing = ParagonExport.blockWriting(self)
        for (at, step) in steps.enumerated() {
            let words = ParagonExport.oneLine(step.text)
            lines.append(contentsOf: writing.heads[at] ?? [])
            let indent = String(repeating: "   ", count: writing.depth[at] ?? 0)
            switch step.kind {
            case .message:
                if let n = numbers[step.id] { lines.append(indent + "\(n). " + ParagonExport.messageLine(step, in: self)) }
            case .band:
                lines.append(indent + "   Note: " + (words.isEmpty ? "(empty)" : words))
            default:
                lines.append("")
                lines.append((words.isEmpty ? "Section" : words) + ":")
            }
        }
        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}

// MARK: The hand-over to PARAGON

public extension ParagonExport {
    internal static func whoName(_ item: Item?) -> String {
        let words = oneLine(item?.text ?? "")
        return words.isEmpty ? "(no name)" : words
    }

    /// One message in words: "Alex → Bank: Ask for loan", "Bank answers Alex: Yes",
    /// "Bank, by itself: Check the papers". A message without words ends after the names.
    static func messageLine(_ message: Item, in board: Board) -> String {
        let from = whoName(message.from.flatMap { board.item($0) })
        let to = whoName(message.to.flatMap { board.item($0) })
        let names = message.from == message.to ? "\(from), by itself"
            : (message.isAnswer ? "\(from) answers \(to)" : "\(from) → \(to)")
        let words = oneLine(message.text)
        return words.isEmpty ? names : "\(names): \(words)"
    }

    /// Blank lines stand between a list and what breaks it (a note, a heading); none at the ends, never two.
    internal static func tidy(_ lines: [String]) -> [String] {
        var out: [String] = []
        for line in lines where !(line.isEmpty && (out.isEmpty || out.last == "")) { out.append(line) }
        while out.last == "" { out.removeLast() }
        return out
    }

    /// The steps for a note: a numbered list "1. Alex → Bank: Ask for loan", a note as a quoted line
    /// and a section as a `###` heading, each in its place.
    static func sequenceList(_ board: Board) -> [String] {
        let numbers = board.messageNumbers
        var lines: [String] = []
        let writing = blockWriting(board)
        for (at, step) in board.steps.enumerated() {
            lines.append(contentsOf: writing.heads[at] ?? [])
            let indent = String(repeating: "   ", count: writing.depth[at] ?? 0)
            switch step.kind {
            case .message:
                if let n = numbers[step.id] { lines.append(indent + "\(n). " + messageLine(step, in: board)) }
            case .band:
                lines.append(contentsOf: ["", indent + "> " + label(step), ""])
            default:
                lines.append(contentsOf: ["", "### " + label(step), ""])
            }
        }
        return tidy(lines)
    }

    /// True when at least one message carries the To do tick: then only the ticked ones become tasks.
    static func sequenceTicksDecide(_ board: Board) -> Bool {
        board.items.contains { board.isDrawnMessage($0) && $0.todo }
    }

    /// The steps for a project: every message a line in its order, a section a `###` heading.
    /// With something ticked only the ticked messages are tasks and the others plain lines; with
    /// nothing ticked every message is a task. Notes are left to the project's own Notes.
    static func sequenceTaskLines(_ board: Board) -> (lines: [String], tasks: Int, plain: Int) {
        let ticks = sequenceTicksDecide(board)
        let numbers = board.messageNumbers
        var lines: [String] = []
        var tasks = 0, plain = 0
        for step in board.steps {
            switch step.kind {
            case .message:
                guard numbers[step.id] != nil else { continue }
                let task = !ticks || step.todo
                if task { tasks += 1 } else { plain += 1 }
                lines.append((task ? "- [ ] " : "- ") + messageLine(step, in: board))
            case .section:
                lines.append(contentsOf: ["", "### " + label(step), ""])
            default:
                continue
            }
        }
        return (tidy(lines), tasks, plain)
    }

    internal static func people(_ board: Board) -> [String] {
        let names = board.whos.map { whoName($0) }
        return names.isEmpty ? [] : [names.joined(separator: " · ")]
    }

    internal static func bandBullets(_ board: Board) -> [String] {
        board.steps.filter { $0.kind == .band && !oneLine($0.text).isEmpty }.map { "- " + oneLine($0.text) }
    }

    /// A "Who does what" board as a NOTE for Resources/: the picture, the way back, who is in it, the
    /// numbered steps with notes and sections in place, and the ticked messages as tasks.
    static func sequenceNote(board: Board, title: String, picture: String?, now: Date) -> String {
        var out = frontMatter(title: title, type: "resource", status: nil, now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        section("Who", people(board), into: &out)
        section("Who does what", sequenceList(board), into: &out)
        let numbers = board.messageNumbers
        let tasks = board.steps.filter { $0.kind == .message && $0.todo && numbers[$0.id] != nil }
            .map { "- [ ] " + messageLine($0, in: board) }
        section("Tasks", tasks, into: &out)
        return out
    }

    /// A "Who does what" board as a PROJECT for Projects/: the messages in order under `## Tasks`
    /// (see `sequenceTaskLines`), sections as `###` headings, the notes under `## Notes`.
    static func sequenceProject(board: Board, title: String, picture: String?, now: Date) -> String {
        var out = frontMatter(title: title, type: "project", status: "active", now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        out += "## Outcome\n\n\(title)\n\n"
        out += "## Tasks\n\n"
        let tasks = sequenceTaskLines(board).lines
        if !tasks.isEmpty { out += tasks.joined(separator: "\n") + "\n\n" }
        out += "## Notes\n\n"
        let who = people(board)
        if !who.isEmpty { out += "Who: " + who[0] + "\n\n" }
        let notes = bandBullets(board)
        if !notes.isEmpty { out += notes.joined(separator: "\n") + "\n\n" }
        out += "## Log\n\n- \(stamp(now, "yyyy-MM-dd")): Project created from a Seedboard “Who does what” board\n"
        return out
    }

    /// One plain line for the Send page that says what "As a project" makes of the messages:
    /// "2 ticked messages become tasks, 7 stay as plain lines." or "Nothing is ticked: all 9 messages
    /// become tasks." nil when there is no message.
    static func sequenceProjectLine(_ board: Board) -> String? {
        let count = sequenceTaskLines(board)
        guard count.tasks + count.plain > 0 else { return nil }
        if sequenceTicksDecide(board) {
            var line = count.tasks == 1 ? "1 ticked message becomes a task" : "\(count.tasks) ticked messages become tasks"
            if count.plain == 1 { line += ", 1 stays as a plain line" }
            if count.plain > 1 { line += ", \(count.plain) stay as plain lines" }
            return line + "."
        }
        return count.tasks == 1 ? "Nothing is ticked: the 1 message becomes a task."
            : "Nothing is ticked: all \(count.tasks) messages become tasks."
    }
}
