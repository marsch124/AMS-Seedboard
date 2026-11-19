import Foundation
import CoreGraphics

// Seedboard 0.11, the pencil lane: a ruler (pick 37, view only — never saved in the board) and
// "Read this" (pick 31: the words of a drawing become a note beside it, the drawing stays).

/// A straight edge lying on the board (board points). It exists only while the board is open.
public struct Ruler: Equatable, Sendable {
    public var centre: CGPoint
    /// Radians; 0 lies along the x axis.
    public var angle: Double
    public var length: Double

    public static let defaultLength = 360.0
    /// How near the edge a line must be, in screen points, to snap to it.
    public static let screenReach = 16.0

    public init(centre: CGPoint, angle: Double = 0, length: Double = Ruler.defaultLength) {
        self.centre = centre
        self.angle = angle.isFinite ? angle : 0
        self.length = length.isFinite ? max(80, length) : Ruler.defaultLength
    }

    public var direction: CGPoint { CGPoint(x: cos(angle), y: sin(angle)) }
    public var start: CGPoint { CGPoint(x: centre.x - direction.x * length / 2, y: centre.y - direction.y * length / 2) }
    public var end: CGPoint { CGPoint(x: centre.x + direction.x * length / 2, y: centre.y + direction.y * length / 2) }

    /// The point of the edge's line nearest to `p`, and how far `p` lies from it. Along the line only:
    /// the edge's ends do not stop a line, it snaps along the whole straight line through the ruler.
    func foot(of p: CGPoint) -> (point: CGPoint, away: Double) {
        let d = direction
        let along = Double(p.x - centre.x) * Double(d.x) + Double(p.y - centre.y) * Double(d.y)
        let foot = CGPoint(x: Double(centre.x) + along * Double(d.x), y: Double(centre.y) + along * Double(d.y))
        return (foot, hypot(Double(p.x - foot.x), Double(p.y - foot.y)))
    }

    /// A line drawn beside the edge: every point within `reach` of the edge (and the line long enough to be a
    /// line, not a dot) becomes ONE straight line between where it began and where it ended, laid on the edge.
    /// nil: the line was not drawn along the edge, it stays as drawn.
    public func snapped(_ points: [CGPoint], reach: Double) -> [CGPoint]? {
        guard points.count >= 2, reach > 0, let first = points.first, let last = points.last,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        guard points.allSatisfy({ foot(of: $0).away <= reach }) else { return nil }
        let a = foot(of: first).point, b = foot(of: last).point
        guard hypot(Double(b.x - a.x), Double(b.y - a.y)) >= 4 else { return nil }
        return [a, b]
    }
}

public extension Board {
    /// "Read this": the words of a drawing become a note to the right of it. The drawing stays unchanged.
    /// Returns the new note's id; nil for no words, something that is not a drawing, or a board that may not be changed.
    @discardableResult
    mutating func addReadNote(besideDrawing id: UUID, words: String) -> UUID? {
        let clean = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canBeChanged, !placesItself, !clean.isEmpty, let d = item(id), d.kind == .drawing else { return nil }
        var note = Item(kind: .note, text: clean, colour: "yellow")
        note.x = d.x + d.w + 16
        note.y = d.y
        items.append(note)
        return note.id
    }
}
