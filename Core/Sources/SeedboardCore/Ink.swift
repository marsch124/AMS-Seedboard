import Foundation
import CoreGraphics

// Drawing by hand (0.2). A "drawing" is a thing on the board like a note: it has a box, it is chosen,
// moved, copied, framed and removed like one. What it holds is strokes — the lines the Pencil, a
// finger or the mouse drew. A stroke keeps a colour NAME (so it follows day and night), one of three
// thicknesses, and its points measured from the drawing's corner, thinned and rounded so files stay
// small. A stroke made by the Pencil also keeps how hard it was pressed at each point.
//
// Stored names (they must never change): the kind `drawing`; the item field `strokes`; in a stroke
// `colour`, `width`, `points`, `pressure`.

/// The three thicknesses of a drawn line.
public enum InkWidth: String, CaseIterable, Sendable {
    case thin, medium, thick

    /// The line's width in board points (a Pencil's pressure makes it up to 35 % thinner or thicker).
    public var points: Double {
        switch self {
        case .thin: return 2
        case .medium: return 4
        case .thick: return 7.5
        }
    }

    public var word: String {
        switch self {
        case .thin: return "Thin"
        case .medium: return "Medium"
        case .thick: return "Thick"
        }
    }
}

/// One line drawn in one go, from touching down to lifting.
public struct Stroke: Codable, Equatable, Sendable {
    /// A colour name from `Palette`; empty = plain ink (dark by day, light by night).
    public var colour: String
    /// "thin", "medium" or "thick" (`InkWidth`). A word this version does not know is drawn medium and kept.
    public var width: String
    /// x0, y0, x1, y1 … measured from the drawing's corner, to a tenth of a point.
    public var points: [Double]
    /// How hard the Pencil was pressed at each point, 0 … 1, to a hundredth. nil: a finger or the mouse drew it.
    public var pressure: [Double]?
    /// 0.9 (format 6): the pen: "highlighter" (wide, see-through). nil = the ordinary pen.
    public var pen: String?
    /// Fields in the file this version does not know: carried through a load and a save untouched.
    public private(set) var extra: [String: JSONValue] = [:]

    public init(colour: String = "", width: InkWidth = .medium, points: [Double] = [], pressure: [Double]? = nil) {
        self.colour = colour
        self.width = width.rawValue
        self.points = points.count % 2 == 0 ? points : Array(points.dropLast())
        self.pressure = pressure?.count == self.points.count / 2 ? pressure : nil
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case colour, width, points, pressure
        case pen
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        colour = (try? c.decode(String.self, forKey: .colour)) ?? ""
        width = (try? c.decode(String.self, forKey: .width)) ?? InkWidth.medium.rawValue
        let read = (try? c.decode([Double].self, forKey: .points)) ?? []
        points = read.count % 2 == 0 ? read : Array(read.dropLast())
        let force = try? c.decode([Double].self, forKey: .pressure)
        pressure = force?.count == points.count / 2 ? force : nil
        pen = try? c.decode(String.self, forKey: .pen)
        extra = unknownFields(of: decoder, known: CodingKeys.allCases.map(\.rawValue))
    }

    public func encode(to encoder: Encoder) throws {
        try writeUnknownFields(extra, to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(colour, forKey: .colour)
        try c.encode(width, forKey: .width)
        try c.encode(points, forKey: .points)
        try c.encodeIfPresent(pressure, forKey: .pressure)
        try c.encodeIfPresent(pen, forKey: .pen)
    }

    public var thickness: InkWidth { InkWidth(rawValue: width) ?? .medium }

    /// How many points the stroke has.
    public var count: Int { points.count / 2 }

    /// The points as they lie when the drawing's corner is at `origin`.
    public func path(from origin: CGPoint = .zero) -> [CGPoint] {
        (0..<count).map { CGPoint(x: Double(origin.x) + points[$0 * 2], y: Double(origin.y) + points[$0 * 2 + 1]) }
    }
}

/// One stroke of one drawing, for the rubber.
public struct InkMark: Hashable, Sendable {
    public var drawing: UUID
    public var stroke: Int

    public init(drawing: UUID, stroke: Int) {
        self.drawing = drawing
        self.stroke = stroke
    }
}

/// A piece of a line as it is drawn: one width, and the way to go.
public struct InkRun: Equatable, Sendable {
    public var width: Double
    public var steps: [InkStep]
}

public enum InkStep: Equatable, Sendable {
    case move(CGPoint)
    case line(CGPoint)
    case curve(CGPoint, control: CGPoint)
}

/// The rules of drawing: all pure, all in board points unless a name says otherwise.
public enum Ink {
    /// The room between a drawing's lines and the edge of its box, so a thick line is never cut.
    public static let margin: Double = 6
    /// Strokes made within this many seconds of the last one …
    public static let joinSeconds: Double = 5
    /// … and no further than this from the drawing it went into join that drawing.
    public static let joinReach: Double = 40
    /// How near a line a mouse or the Pencil must press to mean the drawing, in SCREEN points
    /// (a finger: half of `Fingers.button`).
    public static let reach: Double = 6
    /// The rubber's reach round its middle, in SCREEN points.
    public static let rubber: Double = 10
    /// How much the Pencil's pressure changes a line's width: 35 % thinner to 35 % thicker.
    public static let sway: Double = 0.35
    /// How far a drawn curve may leave the points it was made from (see `runs`).
    public static let rounding: Double = 0.6
    /// A press that travels less than this (SCREEN points) and is over this soon is a tap, not a line.
    public static let tapWay: Double = 4
    public static let tapSeconds: Double = 0.35

    static func tenth(_ value: Double) -> Double { (value * 10).rounded() / 10 }
    static func hundredth(_ value: Double) -> Double { (value * 100).rounded() / 100 }

    // MARK: Thinning

    /// How much a line may be straightened when it is kept: 0.4 screen points, never more than half a board point.
    public static func tolerance(scale: Double) -> Double { min(0.5, 0.4 / max(scale, 0.01)) }

    /// Leaves out the points a line does not need (Ramer–Douglas–Peucker): every point left out lay
    /// within `tolerance` of the line between its kept neighbours. Pressure counts as a third
    /// direction (a tenth of full pressure weighs like 0.3 points), so a line that swells stays swelling.
    public static func thin(_ points: [CGPoint], pressure: [Double]? = nil, tolerance: Double) -> (points: [CGPoint], pressure: [Double]?) {
        let force = pressure?.count == points.count ? pressure : nil
        let n = points.count
        guard n > 2 else { return (points, force) }
        let weight = 3.0
        func far(_ i: Int, _ a: Int, _ b: Int) -> Double {
            let p = (Double(points[i].x), Double(points[i].y), (force?[i] ?? 0) * weight)
            let s = (Double(points[a].x), Double(points[a].y), (force?[a] ?? 0) * weight)
            let e = (Double(points[b].x), Double(points[b].y), (force?[b] ?? 0) * weight)
            let d = (e.0 - s.0, e.1 - s.1, e.2 - s.2)
            let length = d.0 * d.0 + d.1 * d.1 + d.2 * d.2
            var t = 0.0
            if length > 0 { t = min(max(((p.0 - s.0) * d.0 + (p.1 - s.1) * d.1 + (p.2 - s.2) * d.2) / length, 0), 1) }
            let q = (s.0 + d.0 * t - p.0, s.1 + d.1 * t - p.1, s.2 + d.2 * t - p.2)
            return (q.0 * q.0 + q.1 * q.1 + q.2 * q.2).squareRoot()
        }
        var keep = [Bool](repeating: false, count: n)
        keep[0] = true
        keep[n - 1] = true
        var open = [(0, n - 1)]
        while let (a, b) = open.popLast() {
            guard b > a + 1 else { continue }
            var worst = 0.0, at = a
            for i in (a + 1)..<b {
                let d = far(i, a, b)
                if d > worst { worst = d; at = i }
            }
            if worst > tolerance {
                keep[at] = true
                open.append((a, at))
                open.append((at, b))
            }
        }
        let kept = (0..<n).filter { keep[$0] }
        return (kept.map { points[$0] }, force.map { all in kept.map { all[$0] } })
    }

    // MARK: Boxes

    /// The smallest box round the points; nil for none.
    public static func bounds(of points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var lowX = first.x, highX = first.x, lowY = first.y, highY = first.y
        for p in points.dropFirst() {
            lowX = min(lowX, p.x); highX = max(highX, p.x)
            lowY = min(lowY, p.y); highY = max(highY, p.y)
        }
        return CGRect(x: lowX, y: lowY, width: highX - lowX, height: highY - lowY)
    }

    /// The empty room between two boxes; 0 when they touch or overlap.
    public static func gap(_ a: CGRect, _ b: CGRect) -> Double {
        let dx = max(0, Double(a.minX) - Double(b.maxX), Double(b.minX) - Double(a.maxX))
        let dy = max(0, Double(a.minY) - Double(b.maxY), Double(b.minY) - Double(a.maxY))
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Does a new stroke go into the drawing the last stroke went into? Yes when it began within
    /// `joinSeconds` of that stroke's end AND lies over the drawing or within `joinReach` of its box.
    public static func joins(_ stroke: CGRect, drawing: CGRect, after seconds: Double) -> Bool {
        seconds >= 0 && seconds <= joinSeconds && gap(stroke, drawing) <= joinReach
    }

    // MARK: Width and distance

    /// The width of a line where the Pencil pressed this hard (0 … 1 of all it can feel).
    /// Ordinary writing (about a quarter) gives the chosen width; a feather touch 35 % less,
    /// pressing hard (0.6 and more) 35 % more. No pressure (a finger, the mouse): the chosen width.
    public static func width(_ base: Double, pressure: Double?) -> Double {
        guard let pressure else { return base }
        let feel = pow(min(max(pressure, 0) / 0.6, 1), 0.7)
        return base * (1 - sway + 2 * sway * feel)
    }

    /// How far a point is from a line through these points (from the one point, when there is only one).
    public static func distance(from p: CGPoint, toLine points: [CGPoint]) -> Double {
        guard let first = points.first else { return .infinity }
        if points.count == 1 { return Double(hypot(p.x - first.x, p.y - first.y)) }
        return Route.distance(from: p, to: points)
    }

    /// How far the piece from `a` to `b` (the rubber's last step) is from a line through these points; 0 when they cross.
    public static func distance(from a: CGPoint, _ b: CGPoint, toLine points: [CGPoint]) -> Double {
        guard let first = points.first else { return .infinity }
        if points.count == 1 { return Route.distance(from: first, to: [a, b]) }
        var best = Double.infinity
        for i in 1..<points.count {
            let c = points[i - 1], d = points[i]
            if crosses(a, b, c, d) { return 0 }
            best = min(best, Route.distance(from: a, to: [c, d]), Route.distance(from: b, to: [c, d]),
                       Route.distance(from: c, to: [a, b]), Route.distance(from: d, to: [a, b]))
        }
        return best
    }

    private static func crosses(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        func side(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> Double {
            Double((q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x))
        }
        let d1 = side(a, b, c), d2 = side(a, b, d), d3 = side(c, d, a), d4 = side(c, d, b)
        return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
    }

    // MARK: The way a line is drawn

    /// The line through the points as it is drawn: straight pieces with every corner rounded by a
    /// small curve (the curve begins and ends on the two pieces that meet, the corner point pulls it).
    /// A gentle bend is rounded from the middle of one piece to the middle of the next, so a hand's
    /// arc comes out smooth; a sharp corner is rounded only as far as keeps the curve within
    /// `rounding` of the corner, so a drawn corner stays a corner.
    /// With pressure the line is cut into runs of one width each (in steps of about 6 % of the
    /// chosen width); without, it is one run.
    public static func runs(_ points: [CGPoint], pressure: [Double]? = nil, base: Double) -> [InkRun] {
        let n = points.count
        guard n > 0 else { return [] }
        let force = pressure?.count == n ? pressure : nil
        let step = max(0.2, base * 0.06)
        func wide(_ i: Int) -> Double { width(base, pressure: force?[i]) }
        func snapped(_ w: Double) -> Double { force == nil ? base : (w / step).rounded() * step }
        if n == 1 { return [InkRun(width: snapped(wide(0)), steps: [.move(points[0]), .line(points[0])])] }

        var runs: [InkRun] = []
        var here = points[0]
        var current = InkRun(width: snapped(wide(0)), steps: [.move(here)])
        func add(_ step: InkStep, width: Double, to end: CGPoint) {
            if width != current.width {
                if current.steps.count > 1 { runs.append(current) }
                current = InkRun(width: width, steps: [.move(here)])
            }
            current.steps.append(step)
            here = end
        }
        /// A straight piece whose width goes from one value to another: cut so no cut shows.
        func straight(to end: CGPoint, from w0: Double, to w1: Double) {
            guard hypot(end.x - here.x, end.y - here.y) > 1e-9 else { return }
            let parts = force == nil ? 1 : min(max(1, Int((abs(w1 - w0) / step).rounded(.up))), 24)
            let start = here
            for k in 1...parts {
                let t = Double(k) / Double(parts)
                let p = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                add(.line(p), width: snapped(w0 + (w1 - w0) * (t - 0.5 / Double(parts))), to: p)
            }
        }
        if n > 2 {
            for i in 1..<(n - 1) {
                let p = points[i], before = points[i - 1], after = points[i + 1]
                let lengthIn = Double(hypot(p.x - before.x, p.y - before.y))
                let lengthOut = Double(hypot(after.x - p.x, after.y - p.y))
                guard lengthIn > 1e-9, lengthOut > 1e-9 else {
                    straight(to: p, from: wide(i - 1), to: wide(i))
                    continue
                }
                let uIn = CGPoint(x: (p.x - before.x) / lengthIn, y: (p.y - before.y) / lengthIn)
                let uOut = CGPoint(x: (after.x - p.x) / lengthOut, y: (after.y - p.y) / lengthOut)
                // Half the turn's sine: 0 straight on, 1 turning right back.
                let turn = ((1 - Double(uIn.x * uOut.x + uIn.y * uOut.y)) / 2).squareRoot()
                var cut = min(lengthIn, lengthOut) / 2
                if turn > 1e-6 { cut = min(cut, 2 * rounding / turn) }
                let a = CGPoint(x: p.x - uIn.x * cut, y: p.y - uIn.y * cut)
                let b = CGPoint(x: p.x + uOut.x * cut, y: p.y + uOut.y * cut)
                straight(to: a, from: wide(i - 1), to: wide(i))
                if cut > 1e-9 { add(.curve(b, control: p), width: snapped(wide(i)), to: b) }
            }
        }
        straight(to: points[n - 1], from: wide(max(n - 2, 0)), to: wide(n - 1))
        if current.steps.count > 1 { runs.append(current) }
        // Points all in one place: a dot.
        if runs.isEmpty { runs = [InkRun(width: snapped(wide(0)), steps: [.move(points[0]), .line(points[0])])] }
        return runs
    }
}

// MARK: One drawing

public extension Item {
    /// The strokes of a drawing as they lie on the board, in board points.
    var inkLines: [[CGPoint]] {
        guard kind == .drawing else { return [] }
        let corner = CGPoint(x: x, y: y)
        return (strokes ?? []).map { $0.path(from: corner) }
    }

    /// How far the point is from the nearest drawn line's edge (0 on a line); nil when this is no drawing or holds nothing.
    func inkDistance(to point: CGPoint) -> Double? {
        guard kind == .drawing, let strokes, !strokes.isEmpty else { return nil }
        let corner = CGPoint(x: x, y: y)
        var best: Double?
        for stroke in strokes where stroke.count > 0 {
            let far = max(0, Ink.distance(from: point, toLine: stroke.path(from: corner)) - stroke.thickness.points / 2)
            if best == nil || far < best! { best = far }
        }
        return best
    }
}

// MARK: On a board

public extension Board {
    /// The drawings, bottom to top.
    var drawings: [Item] { items.filter { $0.kind == .drawing } }

    /// The topmost drawing with a line within `reach` of the point. A drawing is caught near its
    /// lines only — never anywhere in its box, so what lies between the lines stays easy to reach.
    func inkHit(_ point: CGPoint, reach: Double) -> UUID? {
        for item in items.reversed() where item.kind == .drawing {
            guard item.frame.insetBy(dx: -reach, dy: -reach).contains(point) else { continue }
            if let far = item.inkDistance(to: point), far <= reach { return item.id }
        }
        return nil
    }

    /// The drawing a new stroke goes into, if any: the one the last stroke went into, when the new
    /// one began soon enough after it and near enough to it (`Ink.joins`).
    func drawingToJoin(_ stroke: CGRect, last: UUID?, after seconds: Double) -> UUID? {
        guard let last, let item = item(last), item.kind == .drawing else { return nil }
        return Ink.joins(stroke, drawing: item.frame, after: seconds) ? last : nil
    }

    /// A stroke through these board points is kept: in the drawing `drawing` when it is given (its
    /// box grows), otherwise as a new drawing on top of everything. The points are rounded to a
    /// tenth; thin them first (`Ink.thin`). Returns the drawing.
    @discardableResult
    mutating func addStroke(_ points: [CGPoint], pressure: [Double]? = nil, colour: String = "",
                            width: InkWidth = .medium, to drawing: UUID? = nil) -> UUID? {
        var force = pressure?.count == points.count ? pressure : nil
        var line: [CGPoint] = []
        var kept: [Double] = []
        for (i, p) in points.enumerated() where p.x.isFinite && p.y.isFinite {
            line.append(p)
            if let force { kept.append(Ink.hundredth(min(max(force[i].isFinite ? force[i] : 0, 0), 1))) }
        }
        guard !line.isEmpty else { return nil }
        if force != nil { force = kept }
        // A press that went nowhere is one dot.
        if line.count == 2, Ink.tenth(Double(line[0].x)) == Ink.tenth(Double(line[1].x)),
           Ink.tenth(Double(line[0].y)) == Ink.tenth(Double(line[1].y)) {
            line = [line[0]]
            force = force.map { [$0.max() ?? 0] }
        }
        var stroke = Stroke(colour: colour, width: width)
        stroke.pressure = force
        if let drawing, let i = index(of: drawing), items[i].kind == .drawing {
            let lines = items[i].inkLines + [line]
            items[i].strokes = (items[i].strokes ?? []) + [stroke]
            fitDrawing(at: i, lines: lines)
            return drawing
        }
        var item = Item(kind: .drawing)
        item.strokes = [stroke]
        items.append(item)
        fitDrawing(at: items.count - 1, lines: [line])
        return item.id
    }

    /// The box of a drawing is the box round its lines, with `Ink.margin` round it; the points are
    /// written from the box's corner. `lines`: every stroke's points in board points.
    private mutating func fitDrawing(at i: Int, lines: [[CGPoint]]) {
        guard let all = Ink.bounds(of: lines.flatMap { $0 }), var strokes = items[i].strokes, strokes.count == lines.count else { return }
        let x = Ink.tenth(Double(all.minX)) - Ink.margin
        let y = Ink.tenth(Double(all.minY)) - Ink.margin
        for s in strokes.indices {
            var flat: [Double] = []
            flat.reserveCapacity(lines[s].count * 2)
            for p in lines[s] {
                flat.append(Ink.tenth(Double(p.x) - x))
                flat.append(Ink.tenth(Double(p.y) - y))
            }
            let force = strokes[s].pressure
            strokes[s].points = flat
            strokes[s].pressure = force?.count == lines[s].count ? force : nil
        }
        items[i].strokes = strokes
        items[i].x = x
        items[i].y = y
        // From the rounded ends, so the last point lies exactly `margin` inside the far edge.
        items[i].w = Ink.tenth(Ink.tenth(Double(all.maxX)) - Ink.tenth(Double(all.minX))) + Ink.margin * 2
        items[i].h = Ink.tenth(Ink.tenth(Double(all.maxY)) - Ink.tenth(Double(all.minY))) + Ink.margin * 2
    }

    /// A drawing takes a new size: its lines stretch with its box (the thickness of a line stays).
    /// A drawing that is one flat line stays flat; no side gets smaller than 4 points of drawing.
    mutating func scaleDrawing(_ id: UUID, to rect: CGRect) {
        guard let i = index(of: id), items[i].kind == .drawing, var strokes = items[i].strokes else { return }
        let m = Ink.margin
        let oldW = items[i].w - m * 2, oldH = items[i].h - m * 2
        let r = rect.standardized
        let newW = oldW > 0.5 ? max(Double(r.width) - m * 2, 4) : oldW
        let newH = oldH > 0.5 ? max(Double(r.height) - m * 2, 4) : oldH
        let kx = oldW > 0.5 ? newW / oldW : 1, ky = oldH > 0.5 ? newH / oldH : 1
        for s in strokes.indices {
            for n in 0..<strokes[s].count {
                strokes[s].points[n * 2] = Ink.tenth(m + (strokes[s].points[n * 2] - m) * kx)
                strokes[s].points[n * 2 + 1] = Ink.tenth(m + (strokes[s].points[n * 2 + 1] - m) * ky)
            }
        }
        items[i].strokes = strokes
        items[i].x = Double(r.minX)
        items[i].y = Double(r.minY)
        items[i].w = newW + m * 2
        items[i].h = newH + m * 2
    }

    // MARK: The rubber

    /// The strokes the rubber touches on its way from `from` to `point` (one place when `from` is nil).
    func strokes(near point: CGPoint, from: CGPoint? = nil, reach: Double) -> Set<InkMark> {
        var found: Set<InkMark> = []
        let start = from ?? point
        let way = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                         width: abs(start.x - point.x), height: abs(start.y - point.y))
        for item in items where item.kind == .drawing {
            guard let strokes = item.strokes, item.frame.insetBy(dx: -reach, dy: -reach).intersects(way.insetBy(dx: -0.01, dy: -0.01)) else { continue }
            let corner = CGPoint(x: item.x, y: item.y)
            for (n, stroke) in strokes.enumerated() where stroke.count > 0 {
                let far = Ink.distance(from: start, point, toLine: stroke.path(from: corner)) - stroke.thickness.points / 2
                if far <= reach { found.insert(InkMark(drawing: item.id, stroke: n)) }
            }
        }
        return found
    }

    /// The rubber takes whole strokes away. A drawing left with none disappears (and the arrows
    /// joined to it); any other shrinks to the box of what is left.
    mutating func removeStrokes(_ marks: Set<InkMark>) {
        guard !marks.isEmpty else { return }
        var emptied: Set<UUID> = []
        for id in Set(marks.map(\.drawing)) {
            guard let i = index(of: id), items[i].kind == .drawing, let strokes = items[i].strokes else { continue }
            let lines = items[i].inkLines
            let stay = strokes.indices.filter { !marks.contains(InkMark(drawing: id, stroke: $0)) }
            guard stay.count < strokes.count else { continue }
            if stay.isEmpty {
                emptied.insert(id)
            } else {
                items[i].strokes = stay.map { strokes[$0] }
                fitDrawing(at: i, lines: stay.map { lines[$0] })
            }
        }
        if !emptied.isEmpty { remove(emptied) }
    }

    /// The rubber pressed at one place. True when it took something away.
    @discardableResult
    mutating func rub(at point: CGPoint, reach: Double) -> Bool {
        let marks = strokes(near: point, reach: reach)
        removeStrokes(marks)
        return !marks.isEmpty
    }
}
