import Foundation
import CoreGraphics

// Lanes in a frame (swimlanes): 2 to 5 named rows or columns that share the frame's room and
// stretch with it. And the rule by which a thing belongs to a frame and to a lane: its MIDDLE
// is inside. Nothing here knows about the screen.

public struct Lanes: Codable, Equatable, Sendable {
    public enum Way: String, Codable, CaseIterable, Sendable {
        case rows, columns

        public var word: String { self == .rows ? "Rows" : "Columns" }
    }

    public var way: Way
    /// One name per lane; an empty name is shown as "Lane 1", "Lane 2" …
    public var names: [String]
    /// Where each line between two lanes lies, as a part of the lanes' room (0 to 1), small first.
    /// One fewer than there are lanes.
    public var cuts: [Double]

    public static let fewest = 2
    public static let most = 5
    /// The frame's own name band, above the lanes.
    public static let titleBand: CGFloat = 30
    /// The narrow band that holds a lane's name: at the left of a row, at the top of a column.
    public static let header: CGFloat = 24
    /// No lane is made narrower than this by dragging a line or sizing the frame.
    public static let least: CGFloat = 60

    public init(way: Way, count: Int) {
        let n = min(max(count, Lanes.fewest), Lanes.most)
        self.way = way
        self.names = Array(repeating: "", count: n)
        self.cuts = Lanes.even(n)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case way
        case names
        case cuts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        way = Way(rawValue: (try? c.decode(String.self, forKey: .way)) ?? "") ?? .rows
        var read = (try? c.decode([String].self, forKey: .names)) ?? []
        while read.count < Lanes.fewest { read.append("") }
        names = read
        cuts = Lanes.sound((try? c.decode([Double].self, forKey: .cuts)) ?? [], count: read.count)
    }

    public var count: Int { names.count }

    /// The lines of lanes that all have the same size.
    public static func even(_ count: Int) -> [Double] {
        guard count > 1 else { return [] }
        return (1..<count).map { Double($0) / Double(count) }
    }

    /// The cuts as they are when they make sense (the right number, rising, inside 0 to 1); otherwise even ones.
    static func sound(_ cuts: [Double], count: Int) -> [Double] {
        guard cuts.count == count - 1 else { return even(count) }
        var before = 0.0
        for cut in cuts {
            guard cut > before, cut < 1 else { return even(count) }
            before = cut
        }
        return cuts
    }

    /// The name to show for a lane: its own, or "Lane 2".
    public func name(_ index: Int) -> String {
        let own = names.indices.contains(index) ? names[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return own.isEmpty ? "Lane \(index + 1)" : own
    }

    // MARK: Where the lanes lie

    /// The room the lanes share: the frame without its own name band.
    public static func room(in frame: CGRect) -> CGRect {
        let band = min(titleBand, frame.height / 2)
        return CGRect(x: frame.minX, y: frame.minY + band, width: frame.width, height: frame.height - band)
    }

    /// How long the room is in the direction the lanes are stacked.
    private func length(_ room: CGRect) -> CGFloat { way == .rows ? room.height : room.width }

    /// The lanes' rectangles, the first lane first.
    public func rects(in frame: CGRect) -> [CGRect] {
        let room = Lanes.room(in: frame)
        let edges = [0.0] + Lanes.sound(cuts, count: count) + [1.0]
        return (0..<count).map { i in
            // Both ends are worked out the same way, so two lanes always meet exactly on their line.
            switch way {
            case .rows:
                let from = room.minY + room.height * CGFloat(edges[i]), to = room.minY + room.height * CGFloat(edges[i + 1])
                return CGRect(x: room.minX, y: from, width: room.width, height: to - from)
            case .columns:
                let from = room.minX + room.width * CGFloat(edges[i]), to = room.minX + room.width * CGFloat(edges[i + 1])
                return CGRect(x: from, y: room.minY, width: to - from, height: room.height)
            }
        }
    }

    /// The name band of every lane: a strip at the left of a row, at the top of a column.
    public func headers(in frame: CGRect) -> [CGRect] {
        rects(in: frame).map { lane in
            switch way {
            case .rows: return CGRect(x: lane.minX, y: lane.minY, width: min(Lanes.header, lane.width), height: lane.height)
            case .columns: return CGRect(x: lane.minX, y: lane.minY, width: lane.width, height: min(Lanes.header, lane.height))
            }
        }
    }

    /// The lane that holds the point; nil outside the frame. A point in the frame's own name band
    /// counts for the first row (rows) or for the column under it (columns).
    public func index(at point: CGPoint, in frame: CGRect) -> Int? {
        guard frame.contains(point) else { return nil }
        let all = rects(in: frame)
        for (i, lane) in all.enumerated() {
            let inside = way == .rows ? point.y < lane.maxY : point.x < lane.maxX
            if inside { return i }
        }
        return all.count - 1
    }

    /// The line between lane `index` and the next one, from end to end.
    public func line(_ index: Int, in frame: CGRect) -> (from: CGPoint, to: CGPoint)? {
        let all = rects(in: frame)
        guard index >= 0, index < all.count - 1 else { return nil }
        let lane = all[index]
        switch way {
        case .rows: return (CGPoint(x: lane.minX, y: lane.maxY), CGPoint(x: lane.maxX, y: lane.maxY))
        case .columns: return (CGPoint(x: lane.maxX, y: lane.minY), CGPoint(x: lane.maxX, y: lane.maxY))
        }
    }

    // MARK: Changing

    /// Moves the line after lane `index` to a place on the board (its y for rows, its x for columns).
    /// The two lanes beside it stay at least `least` wide; when there is no room for that, nothing moves.
    public mutating func moveLine(_ index: Int, to place: CGFloat, in frame: CGRect) {
        let now = Lanes.sound(cuts, count: count)
        guard index >= 0, index < now.count else { return }
        let room = Lanes.room(in: frame)
        let long = length(room)
        guard long > 0 else { return }
        let start = way == .rows ? room.minY : room.minX
        let gap = Double(Lanes.least / long)
        let low = (index == 0 ? 0 : now[index - 1]) + gap
        let high = (index == now.count - 1 ? 1 : now[index + 1]) - gap
        guard low <= high else { return }
        var moved = now
        moved[index] = min(max(Double((place - start) / long), low), high)
        cuts = moved
    }

    /// The same lanes with another number of them: the names that fit stay, the lanes are even again.
    public func with(count: Int) -> Lanes {
        var out = Lanes(way: way, count: count)
        for i in out.names.indices where i < names.count { out.names[i] = names[i] }
        return out
    }

    /// The smallest the lanes' room may be along their direction so that every lane keeps `least`.
    public var leastLength: CGFloat {
        let edges = [0.0] + Lanes.sound(cuts, count: count) + [1.0]
        let narrowest = (0..<count).map { edges[$0 + 1] - edges[$0] }.min() ?? 1
        return narrowest > 0 ? (Lanes.least / CGFloat(narrowest) - 0.001).rounded(.up) : Lanes.least * CGFloat(count)
    }
}

/// A place in a frame: the frame, and the lane when the frame has lanes.
public struct FrameSpot: Hashable, Sendable {
    public var frame: UUID
    public var lane: Int?

    public init(frame: UUID, lane: Int? = nil) {
        self.frame = frame
        self.lane = lane
    }
}

public extension Item {
    /// The smallest a frame may be made: 120 × 80, and with lanes enough for every lane to keep its least size.
    var leastFrameSize: CGSize {
        var least = CGSize(width: 120, height: 80)
        guard kind == .frame, let lanes else { return least }
        switch lanes.way {
        case .rows: least.height = max(least.height, Lanes.titleBand + lanes.leastLength)
        case .columns: least.width = max(least.width, lanes.leastLength)
        }
        return least
    }

    /// The lane whose name band is under the point (a frame with lanes only).
    func laneName(at point: CGPoint) -> Int? {
        guard kind == .frame, let lanes else { return nil }
        return lanes.headers(in: frame).firstIndex { $0.contains(point) }
    }
}

public extension Board {
    // MARK: Belonging

    /// True when the thing belongs to the frame: its MIDDLE is inside. Another frame belongs only
    /// when it lies wholly inside (a big frame is never carried off by a small one under its middle).
    static func frame(_ frame: Item, holds inner: Item) -> Bool {
        guard frame.kind == .frame, inner.id != frame.id else { return false }
        return inner.kind == .frame ? frame.frame.contains(inner.frame) : frame.frame.contains(inner.centre)
    }

    /// The frame that holds the point — the smallest when frames lie in each other — and its lane.
    func spot(at point: CGPoint, without: Set<UUID> = []) -> FrameSpot? {
        var best: Item?
        for item in items where item.kind == .frame && !without.contains(item.id) && item.frame.contains(point) {
            if let b = best, b.w * b.h <= item.w * item.h { continue }
            best = item
        }
        guard let best else { return nil }
        return FrameSpot(frame: best.id, lane: best.lanes?.index(at: point, in: best.frame))
    }

    /// The frame and lane a thing belongs to: where its middle is. Frames and the ideas a mind map
    /// places (all but its centre) belong nowhere by themselves.
    func spot(of id: UUID) -> FrameSpot? {
        guard let item = item(id), item.kind != .frame, !(item.kind == .idea && item.parent != nil) else { return nil }
        return spot(at: item.centre)
    }

    /// The frames and lanes the dragged things would belong to where they are now (to light them up).
    /// A frame that is dragged along itself is left out.
    func spots(ofDragged ids: Set<UUID>) -> [FrameSpot] {
        var found: [FrameSpot] = []
        for id in items.map(\.id) where ids.contains(id) {
            guard let spot = spot(of: id), !ids.contains(spot.frame), !found.contains(spot) else { continue }
            found.append(spot)
        }
        return found
    }

    /// The things that belong to a frame, in reading order (left to right, then down) — or, for the
    /// lanes of columns, top to bottom, then right. Other frames and what is folded away are left out;
    /// of a mind map only its centre counts.
    func things(in frameID: UUID) -> [Item] {
        guard let frame = item(frameID), frame.kind == .frame else { return [] }
        let down = frame.lanes?.way == .columns
        return items
            .filter { $0.kind != .frame && !($0.kind == .idea && $0.parent != nil) && !isHidden($0.id) && Board.frame(frame, holds: $0) }
            .sorted { a, b in
                let ka = down ? (a.centre.y, a.centre.x) : (a.centre.x, a.centre.y)
                let kb = down ? (b.centre.y, b.centre.x) : (b.centre.x, b.centre.y)
                return ka < kb
            }
    }

    /// The things of a frame lane by lane (one list per lane, the first lane first).
    func thingsByLane(in frameID: UUID) -> [[Item]] {
        guard let frame = item(frameID), let lanes = frame.lanes else { return [] }
        var out = Array(repeating: [Item](), count: lanes.count)
        for thing in things(in: frameID) {
            if let lane = lanes.index(at: thing.centre, in: frame.frame), out.indices.contains(lane) { out[lane].append(thing) }
        }
        return out
    }

    // MARK: Changing a frame's lanes

    /// Gives a frame lanes, another number of them, another direction — or none (`way` nil).
    /// Names stay where they fit; the lanes are even again; a frame too small for its lanes grows.
    mutating func setLanes(_ id: UUID, way: Lanes.Way?, count: Int = 3) {
        guard let i = index(of: id), items[i].kind == .frame else { return }
        guard let way else { items[i].lanes = nil; return }
        var lanes = (items[i].lanes ?? Lanes(way: way, count: count)).with(count: count)
        lanes.way = way
        items[i].lanes = lanes
        let least = items[i].leastFrameSize
        items[i].w = max(items[i].w, Double(least.width))
        items[i].h = max(items[i].h, Double(least.height))
    }

    /// Names one lane.
    mutating func setLaneName(_ id: UUID, lane: Int, to name: String) {
        guard let i = index(of: id), var lanes = items[i].lanes, lanes.names.indices.contains(lane) else { return }
        lanes.names[lane] = name.trimmingCharacters(in: .whitespacesAndNewlines)
        items[i].lanes = lanes
    }

    /// Moves the line after a lane (see `Lanes.moveLine`). The things on the board stay where they are.
    mutating func moveLaneLine(_ id: UUID, line: Int, to place: CGFloat) {
        guard let i = index(of: id), var lanes = items[i].lanes else { return }
        lanes.moveLine(line, to: place, in: items[i].frame)
        items[i].lanes = lanes
    }
}
