import Foundation
import CoreGraphics

// Tidy shapes (0.5, pick 30): a line drawn by hand that was plainly meant as a shape becomes the
// real thing. A closed loop that fits a rectangle, an oval or a diamond becomes a Box, an Oval or
// a Diamond of that size and place; an open line that begins at one thing and ends at another
// becomes an arrow between them. Everything else stays the sketch it is.
//
// Only a line that begins a NEW sketch is looked at, and only when the tip rested at its end
// (`InkRest`) — a line that joins a sketch he is still drawing is never touched. Nothing is stored:
// the sketch is taken off the board and an ordinary shape or arrow is put there, as one step, so
// one Undo gives the raw line back.
//
// Apple gives no recogniser for this; these are the app's own rules, all pure, in board points
// unless a name says otherwise. The numbers are first guesses to be tuned with a real Pencil.

/// Has the tip come to rest? Fed with every place the tip goes; asked once, when it lifts.
public struct InkRest: Equatable, Sendable {
    /// Where the tip last really moved to, and when (seconds on any one clock).
    public private(set) var anchor: CGPoint
    public private(set) var since: Double

    public init(at point: CGPoint = .zero, time: Double = 0) {
        anchor = point
        since = time
    }

    /// The tip is here now. A tremble of up to `InkShape.restWay` round where it stood is still resting.
    public mutating func moved(to point: CGPoint, time: Double) {
        guard Double(hypot(point.x - anchor.x, point.y - anchor.y)) > InkShape.restWay else { return }
        anchor = point
        since = time
    }

    /// The tip lifts at `time`: did it stand still for `InkShape.rest` before that?
    public func rested(until time: Double) -> Bool { time - since >= InkShape.rest }
}

public enum InkShape {
    /// How long the tip rests at the end of the line before it is looked at, in seconds.
    public static let rest: Double = 0.4
    /// How far the tip may tremble while it rests, in SCREEN points.
    public static let restWay: Double = 6
    /// A loop fits a shape when its line lies, on average, no further from the shape's outline (and
    /// the outline no further from the line) than this share of the shape's diagonal.
    public static let fit: Double = 0.035
    /// A loop may lean: it is tried as drawn and turned back by up to this many degrees, in steps of 2.
    public static let tilt: Double = 10
    /// A line is a closed loop when its ends come this near each other, as a share of its box's diagonal.
    public static let closing: Double = 0.2
    /// A loop goes round its middle once: at least this much of a turn …
    public static let leastTurn: Double = 0.8
    /// … and no more than this (a little way over where it began is fine, twice round is a scribble).
    public static let mostTurn: Double = 1.35
    /// The smallest loop that becomes a shape — the smallest a shape can be made. Smaller is handwriting.
    public static let least = CGSize(width: 44, height: 28)
    /// How near a thing an arrow's line must begin and end, in SCREEN points (inside the thing counts as on it).
    public static let reach: Double = 14
    /// An arrow's line may bend, not wander: it is no longer than this many times the straight way between its ends.
    public static let wander: Double = 2.5
    /// The shortest line that becomes an arrow.
    public static let leastArrow: Double = 12

    /// What a drawn line should become.
    public enum Tidy: Equatable, Sendable {
        case shape(ItemKind, CGRect)
        case arrow(from: UUID, to: UUID)
    }

    /// What it became: the new shape, or the new arrow.
    public enum Made: Equatable, Sendable {
        case shape(UUID)
        case arrow(UUID)
    }

    /// The three shapes a loop can become, in the order they are tried (the first wins a tie).
    static let kinds: [ItemKind] = [.box, .oval, .diamond]
    /// The leans that are tried: as drawn first, then 2, −2, 4, −4 … degrees.
    static let tilts: [Double] = [0] + stride(from: 2.0, through: tilt, by: 2).flatMap { [$0, -$0] }

    // MARK: Measuring a line

    static func length(of points: [CGPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var all = 0.0
        for i in 1..<points.count { all += Double(hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)) }
        return all
    }

    /// `count` points spread evenly along the line, so a slow corner weighs no more than a fast side.
    static func spread(_ points: [CGPoint], count: Int) -> [CGPoint] {
        let whole = length(of: points)
        guard points.count > 1, whole > 0, count > 1 else { return points }
        var out: [CGPoint] = [points[0]]
        let step = whole / Double(count - 1)
        var want = step
        var gone = 0.0
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let piece = Double(hypot(b.x - a.x, b.y - a.y))
            guard piece > 0 else { continue }
            while want <= gone + piece + 1e-9, out.count < count - 1 {
                let t = CGFloat((want - gone) / piece)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                want += step
            }
            gone += piece
        }
        out.append(points[points.count - 1])
        return out
    }

    /// Is the line a closed loop? Its two ends meet, or one end runs a little way over the other's
    /// beginning: the nearest the first point comes to the last quarter of the line, or the last
    /// point to the first quarter, is within `closing` of the diagonal of the line's box.
    public static func closed(_ points: [CGPoint]) -> Bool {
        guard points.count >= 4, let box = Ink.bounds(of: points) else { return false }
        let diagonal = Double(hypot(box.width, box.height))
        guard diagonal > 0 else { return false }
        let even = spread(points, count: samples)
        guard let first = even.first, let last = even.last else { return false }
        let quarter = even.count / 4
        var gap = Double(hypot(first.x - last.x, first.y - last.y))
        for p in even.suffix(quarter) { gap = min(gap, Double(hypot(p.x - first.x, p.y - first.y))) }
        for p in even.prefix(quarter) { gap = min(gap, Double(hypot(p.x - last.x, p.y - last.y))) }
        return gap <= closing * diagonal
    }

    /// How many times the line goes round the middle of its box (1 = once; the way round does not matter).
    public static func turns(_ points: [CGPoint]) -> Double {
        guard points.count > 2, let box = Ink.bounds(of: points) else { return 0 }
        let mid = CGPoint(x: box.midX, y: box.midY)
        var sum = 0.0
        var before: Double?
        for p in points {
            let dx = Double(p.x - mid.x), dy = Double(p.y - mid.y)
            guard dx != 0 || dy != 0 else { continue }
            let angle = atan2(dy, dx)
            if let before {
                var step = angle - before
                if step > .pi { step -= 2 * .pi }
                if step < -.pi { step += 2 * .pi }
                sum += step
            }
            before = angle
        }
        return abs(sum) / (2 * .pi)
    }

    /// The outline of a shape of this kind filling the box, as a closed line (the first point again at the end).
    static func outline(_ kind: ItemKind, in box: CGRect) -> [CGPoint] {
        switch kind {
        case .oval:
            let steps = 72
            return (0...steps).map { i in
                let a = Double(i) / Double(steps) * 2 * .pi
                return CGPoint(x: Double(box.midX) + Double(box.width) / 2 * cos(a), y: Double(box.midY) + Double(box.height) / 2 * sin(a))
            }
        case .diamond:
            return [CGPoint(x: box.midX, y: box.minY), CGPoint(x: box.maxX, y: box.midY), CGPoint(x: box.midX, y: box.maxY),
                    CGPoint(x: box.minX, y: box.midY), CGPoint(x: box.midX, y: box.minY)]
        default:
            return [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY),
                    CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.minX, y: box.minY)]
        }
    }

    /// How many points of a line, and of an outline, are measured.
    static let samples = 64

    /// The line's points to the outline of this kind of shape filling `box` (`there`), and the
    /// outline's points to the line (`back`): each the average distance, in board points.
    /// `line`: spread evenly (`spread`); `box`: the box of the whole line.
    static func ways(of line: [CGPoint], from kind: ItemKind, in box: CGRect) -> (there: Double, back: Double) {
        let shape = outline(kind, in: box)
        let round = spread(shape, count: samples)
        var there = 0.0, back = 0.0
        for p in line { there += Route.distance(from: p, to: shape) }
        for p in round { back += Route.distance(from: p, to: line) }
        return (there / Double(max(line.count, 1)), back / Double(max(round.count, 1)))
    }

    /// How far the line is from the outline of this kind of shape filling the line's own box, as a
    /// share of the box's diagonal: the larger of "the line's points to the outline" and "the
    /// outline's points to the line". 0 = the line IS the outline. Both ways are asked, so a
    /// triangle (all of it near a rectangle's edge, but a whole corner of the rectangle bare) is no rectangle.
    public static func farness(of points: [CGPoint], from kind: ItemKind) -> Double {
        guard points.count > 1, let box = Ink.bounds(of: points) else { return .infinity }
        let diagonal = Double(hypot(box.width, box.height))
        guard diagonal > 0 else { return .infinity }
        let ways = ways(of: spread(points, count: samples), from: kind, in: box)
        return max(ways.there, ways.back) / diagonal
    }

    /// The line turned by so many degrees round `middle`.
    static func turned(_ points: [CGPoint], by degrees: Double, round middle: CGPoint) -> [CGPoint] {
        guard degrees != 0 else { return points }
        let a = degrees * .pi / 180
        let midX = Double(middle.x), midY = Double(middle.y)
        return points.map { p in
            let x = Double(p.x) - midX, y = Double(p.y) - midY
            return CGPoint(x: midX + x * cos(a) - y * sin(a), y: midY + x * sin(a) + y * cos(a))
        }
    }

    /// The shape a drawn line was meant as, with its place: a closed loop, once round, big enough,
    /// that fits a rectangle, an oval or a diamond. A hand seldom draws dead straight, so a loop
    /// that does not fit well as drawn is also tried turned back by up to `tilt` degrees; the shape
    /// it becomes always stands straight, where the loop was. Its size is the loop's own, less the
    /// hand's wobble (the box round a wobbly line is that much too big on every side). The best
    /// fit wins. nil: no shape.
    public static func shape(of points: [CGPoint]) -> (kind: ItemKind, frame: CGRect)? {
        let clean = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard clean.count >= 4, let box = Ink.bounds(of: clean) else { return nil }
        guard box.width >= least.width, box.height >= least.height, closed(clean) else { return nil }
        let middle = CGPoint(x: box.midX, y: box.midY)
        let even = spread(clean, count: samples)
        let round = turns(even)
        guard round >= leastTurn, round <= mostTurn else { return nil }
        var best: (kind: ItemKind, far: Double, wobble: Double, box: CGRect)?
        for degrees in tilts {
            guard let whole = Ink.bounds(of: turned(clean, by: -degrees, round: middle)) else { continue }
            let diagonal = Double(hypot(whole.width, whole.height))
            guard diagonal > 0 else { continue }
            let straight = turned(even, by: -degrees, round: middle)
            for kind in kinds {
                let ways = ways(of: straight, from: kind, in: whole)
                let far = max(ways.there, ways.back) / diagonal
                if far <= fit, best == nil || far < best!.far { best = (kind, far, ways.there, whole) }
            }
            // As good as drawn with a ruler: no need to try it leaning.
            if let best, best.far <= fit / 3 { break }
        }
        guard let best else { return nil }
        let inset = min(best.wobble, Double(min(best.box.width, best.box.height)) / 4)
        let frame = CGRect(x: (Double(best.box.minX) + inset).rounded(), y: (Double(best.box.minY) + inset).rounded(),
                           width: (Double(best.box.width) - inset * 2).rounded(), height: (Double(best.box.height) - inset * 2).rounded())
        return (best.kind, frame)
    }

    /// How far the point is from the box; 0 inside it.
    static func distance(from p: CGPoint, to box: CGRect) -> Double {
        let dx = max(0, Double(box.minX) - Double(p.x), Double(p.x) - Double(box.maxX))
        let dy = max(0, Double(box.minY) - Double(p.y), Double(p.y) - Double(box.maxY))
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: Writing straight onto a shape

    /// The Pencil came down on a thing and the system says he is writing. Writing wins while the
    /// tip has gone no further than this from where it landed (SCREEN points); further is a drag — the thing moves.
    public static let dragWins: Double = 10

    /// Does the writing win over moving the thing? `strayed`: how far the tip went from where it landed.
    public static func writingWins(strayed: Double) -> Bool { strayed <= dragWins }
}

public extension Board {
    // MARK: Tidy shapes

    /// The thing an arrow's line begins or ends at: the one the point lies in, or the nearest within
    /// `reach` (the topmost when two are as near). Frames take no arrows, sketches are not joined this way.
    func inkEnd(at point: CGPoint, reach: Double, except: UUID? = nil) -> UUID? {
        var best: (id: UUID, far: Double)?
        for item in items.reversed() where item.id != except && item.kind != .frame && item.kind != .drawing
            && item.unknownKind == nil && !isHidden(item.id) {
            let far = InkShape.distance(from: point, to: item.frame)
            if far <= reach, best == nil || far < best!.far { best = (item.id, far) }
        }
        return best?.id
    }

    /// What a line that began a new sketch should become, if anything. `points`: board points.
    /// `reach`: how near a thing an arrow must begin and end, in board points. `except`: the sketch
    /// that holds the line now (it does not stand in its own way).
    ///
    /// - A loop that fits a shape becomes that shape — unless it would lie over something that is
    ///   already there (a ring drawn round a thing is a ring, not a lid).
    /// - A closed loop that fits nothing stays a sketch.
    /// - An open line from one thing to another becomes an arrow, unless that arrow is there already
    ///   or the line wanders.
    /// Never on a timeline or a "Who does what" board, never on a board that cannot be changed.
    func inkTidy(of points: [CGPoint], reach: Double, except: UUID? = nil) -> InkShape.Tidy? {
        guard canBeChanged, !placesItself else { return nil }
        let clean = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard clean.count >= 2, let first = clean.first, let last = clean.last else { return nil }
        if let found = InkShape.shape(of: clean) {
            let covers = items.contains {
                $0.id != except && $0.kind != .frame && !isHidden($0.id) && $0.frame.intersects(found.frame)
            }
            return covers ? nil : .shape(found.kind, found.frame)
        }
        guard !InkShape.closed(clean) else { return nil }
        let way = Double(hypot(last.x - first.x, last.y - first.y))
        let whole = InkShape.length(of: clean)
        guard whole >= InkShape.leastArrow, whole <= InkShape.wander * way else { return nil }
        guard let from = inkEnd(at: first, reach: reach, except: except),
              let to = inkEnd(at: last, reach: reach, except: except), from != to else { return nil }
        guard !links.contains(where: { $0.from == from && $0.to == to }) else { return nil }
        return .arrow(from: from, to: to)
    }

    /// The sketch `id` — one line, just drawn — becomes what it was meant as: a Box, an Oval or a
    /// Diamond where the loop was (in the line's colour; plain ink = the shape's own colour), on top
    /// of everything, or an arrow between the two things the line joined. The sketch itself goes.
    /// nil, and nothing changes, when the line is no shape and no arrow, or the sketch holds more than one line.
    @discardableResult
    mutating func tidyInk(_ id: UUID, reach: Double) -> InkShape.Made? {
        guard let i = index(of: id), items[i].kind == .drawing, let strokes = items[i].strokes, strokes.count == 1,
              let line = items[i].inkLines.first, let found = inkTidy(of: line, reach: reach, except: id) else { return nil }
        switch found {
        case .shape(let kind, let frame):
            var item = Item(kind: kind, colour: Palette.names.contains(strokes[0].colour) ? strokes[0].colour : "")
            item.frame = frame
            remove([id])
            items.append(item)
            return .shape(item.id)
        case .arrow(let from, let to):
            remove([id])
            guard let made = link(from: from, to: to) else { return nil }
            return .arrow(made)
        }
    }

    // MARK: Writing straight onto a shape

    /// May the Pencil write straight into this thing? Everything that holds words of its own and is
    /// typed in place: not a sketch (no words), not a picture (its caption has its own button), not a
    /// frame (it would swallow every line drawn inside it), not a door (its words are the other board's name).
    func takesWriting(_ id: UUID) -> Bool {
        guard canBeChanged, !placesItself, let item = item(id), item.unknownKind == nil, !isHidden(id) else { return false }
        switch item.kind {
        case .drawing, .picture, .frame, .door: return false
        case .bar, .milestone, .phase, .who, .message, .band, .section: return false
        case .idea, .box, .round, .diamond, .oval, .note, .text, .person, .document, .slanted, .store: return true
        }
    }

    /// The things in this part of the board the Pencil may write straight into, bottom to top.
    func writable(in rect: CGRect) -> [UUID] {
        items.filter { $0.frame.intersects(rect) && takesWriting($0.id) }.map(\.id)
    }
}
