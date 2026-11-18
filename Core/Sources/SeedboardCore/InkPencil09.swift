import Foundation
import CoreGraphics

// 0.9, the pencil lane: a highlighter and a rubber in three sizes (pick 35), handwriting turned into
// typed words (36), marks drawn on a picture (37) and the lasso (39). All rules, no screen.
//
// Stored names (they must never change): `Stroke.pen` = "highlighter"; marks on a picture are in the
// PICTURE item's own `strokes`, measured from the picture's corner exactly as a sketch's are.

// MARK: Highlighter (35)

public extension Ink {
    /// The stored name of the highlighter pen (`Stroke.pen`).
    static let highlighter = "highlighter"
    /// A highlighter line is about three times the thick pen, in board points.
    static let highlighterWidth: Double = InkWidth.thick.points * 3
    /// How much of the board shows through a highlighter line: it paints at 35 %.
    static let highlighterOpacity: Double = 0.35
    /// The colours of the highlighter, in the order the plate shows them.
    static let highlighterColours = ["yellow", "green", "pink", "blue"]

    /// A colour the highlighter has: any other name (and plain ink) becomes yellow.
    static func highlighterColour(_ name: String) -> String {
        highlighterColours.contains(name) ? name : "yellow"
    }
}

public extension Stroke {
    /// A highlighter line (wide, see-through, flat ends).
    var isHighlighter: Bool { pen == Ink.highlighter }

    /// The line's width in board points: the highlighter's own width, else the chosen thickness.
    var lineWidth: Double { isHighlighter ? Ink.highlighterWidth : thickness.points }
}

public extension Item {
    /// The strokes in the order they are painted: every highlighter line first, so it lies UNDER the
    /// ordinary ink of the same drawing; each group keeps the order it was drawn in.
    var paintedStrokes: [Stroke] {
        let all = (strokes ?? []).filter { $0.count > 0 }
        return all.filter(\.isHighlighter) + all.filter { !$0.isHighlighter }
    }
}

// MARK: The rubber's three sizes (35)

/// How near a stroke the rubber must pass to take it out. Whole strokes only.
public enum RubberSize: String, CaseIterable, Sendable {
    case small, medium, large

    /// The reach round the rubber's middle, in SCREEN points (medium is what the rubber always was).
    public var screenReach: Double {
        switch self {
        case .small: return Ink.rubber / 2
        case .medium: return Ink.rubber
        case .large: return Ink.rubber * 2
        }
    }

    /// The reach in board points when the board is shown at `scale`.
    public func reach(scale: Double) -> Double { screenReach / max(scale, 0.01) }

    public var word: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

// MARK: Handwriting becomes words (36)

public enum InkText {
    /// What is said when nothing could be read.
    public static let noWords = "No words found in this sketch"

    /// The lines Vision read, joined with line breaks: trimmed, empty lines and doubled spaces left out. Empty = nothing read.
    public static func clean(_ lines: [String]) -> String {
        lines.map { $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// How many pixels a board point becomes when a sketch is drawn into an image for reading: the long side
    /// comes to about 1600 pixels, never more than 4 pixels a point (small writing) and never less than 1.
    public static func imageScale(for size: CGSize) -> Double {
        let long = max(Double(size.width), Double(size.height), 1)
        return min(4, max(1, 1600 / long))
    }
}

public extension Board {
    /// The sketch becomes Text holding the words, at the same place and under the same name (so arrows stay).
    /// Refused (false): not a sketch, no words, a board that may not be changed or places things itself.
    @discardableResult
    mutating func makeTyped(_ id: UUID, words: String) -> Bool {
        let clean = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canBeChanged, !placesItself, !clean.isEmpty, let i = index(of: id), items[i].kind == .drawing else { return false }
        let size = ItemKind.text.defaultSize
        items[i].kind = .text
        items[i].text = clean
        items[i].strokes = nil
        items[i].w = max(size.width, min(items[i].w, 320))
        items[i].h = size.height
        return true
    }
}

// MARK: Marks on a picture (37)

public extension Board {
    /// A stroke through these BOARD points is kept as a mark on the picture: its points are written from the
    /// picture's corner (they may lie outside it; the picture clips them). The picture keeps its box.
    /// Refused (false) for something that is not a picture or a board that may not be changed.
    @discardableResult
    mutating func addPictureStroke(_ points: [CGPoint], colour: String = "", width: InkWidth = .medium,
                                   pen: String? = nil, on picture: UUID) -> Bool {
        guard canBeChanged, let i = index(of: picture), items[i].kind == .picture else { return false }
        let line = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard !line.isEmpty else { return false }
        let high = pen == Ink.highlighter
        var stroke = Stroke(colour: high ? Ink.highlighterColour(colour) : colour, width: high ? .thick : width)
        stroke.pen = high ? Ink.highlighter : nil
        var flat: [Double] = []
        for p in (line.count == 2 && line[0] == line[1] ? [line[0]] : line) {
            flat.append(Ink.tenth(Double(p.x) - items[i].x))
            flat.append(Ink.tenth(Double(p.y) - items[i].y))
        }
        stroke.points = flat
        items[i].strokes = (items[i].strokes ?? []) + [stroke]
        return true
    }
}

public extension Ink {
    /// The marks of a picture after the picture grew or shrank: every point moves with the picture's corner
    /// (`kx`, `ky` times as far from it); the thickness of a line stays.
    static func scaled(_ strokes: [Stroke], kx: Double, ky: Double) -> [Stroke] {
        strokes.map { stroke in
            var s = stroke
            for n in 0..<s.count {
                s.points[n * 2] = tenth(s.points[n * 2] * kx)
                s.points[n * 2 + 1] = tenth(s.points[n * 2 + 1] * ky)
            }
            return s
        }
    }

    /// The marks of a picture after its corner moved by `dx`, `dy` on the picture (a crop): they stay where
    /// they were on the picture.
    static func shifted(_ strokes: [Stroke], dx: Double, dy: Double) -> [Stroke] {
        strokes.map { stroke in
            var s = stroke
            for n in 0..<s.count {
                s.points[n * 2] = tenth(s.points[n * 2] - dx)
                s.points[n * 2 + 1] = tenth(s.points[n * 2 + 1] - dy)
            }
            return s
        }
    }
}

// MARK: The lasso (39)

public extension Ink {
    /// A stroke is chosen when MORE than this share of its length lies inside the loop.
    static let lassoShare: Double = 0.5
    /// A loop must be at least this wide and high (board points) and have three points, else it is a tap.
    static let lassoLeast: Double = 12

    /// Is the point inside the loop (the loop closes itself from its last point to its first)? Even-odd rule.
    static func loopContains(_ loop: [CGPoint], _ p: CGPoint) -> Bool {
        guard loop.count >= 3 else { return false }
        var inside = false
        var j = loop.count - 1
        for i in 0..<loop.count {
            let a = loop[i], b = loop[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// The share (0 … 1) of a line's length that lies inside the loop, measured at steps of about 3 points.
    static func share(of line: [CGPoint], insideLoop loop: [CGPoint]) -> Double {
        guard !line.isEmpty else { return 0 }
        if line.count == 1 { return loopContains(loop, line[0]) ? 1 : 0 }
        var total = 0.0, inside = 0.0
        for k in 1..<line.count {
            let a = line[k - 1], b = line[k]
            let length = Double(hypot(b.x - a.x, b.y - a.y))
            let steps = max(1, Int((length / 3).rounded(.up)))
            for s in 0..<steps {
                let t = (Double(s) + 0.5) / Double(steps)
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                total += length / Double(steps)
                if loopContains(loop, p) { inside += length / Double(steps) }
            }
        }
        return total > 0 ? inside / total : (loopContains(loop, line[0]) ? 1 : 0)
    }

    /// Is this loop big enough to mean something?
    static func isLoop(_ loop: [CGPoint]) -> Bool {
        guard loop.count >= 3, let box = bounds(of: loop) else { return false }
        return Double(box.width) >= lassoLeast && Double(box.height) >= lassoLeast
    }
}

public extension Board {
    /// The strokes (of sketches only) that mostly lie inside the loop.
    func lassoMarks(loop: [CGPoint]) -> Set<InkMark> {
        guard Ink.isLoop(loop), let box = Ink.bounds(of: loop) else { return [] }
        var found: Set<InkMark> = []
        for item in items where item.kind == .drawing && !isHidden(item.id) {
            guard let strokes = item.strokes, item.frame.intersects(box) else { continue }
            let corner = CGPoint(x: item.x, y: item.y)
            for (n, stroke) in strokes.enumerated() where stroke.count > 0 {
                if Ink.share(of: stroke.path(from: corner), insideLoop: loop) > Ink.lassoShare {
                    found.insert(InkMark(drawing: item.id, stroke: n))
                }
            }
        }
        return found
    }

    /// The loop chooses strokes; a sketch of which only some strokes were chosen has them split off into a
    /// new sketch (the rest stays where it was), so they can move alone. Returns the sketches that now hold
    /// exactly the chosen strokes (empty: nothing was inside, and nothing changed). Refused on a board that
    /// may not be changed or places things itself.
    @discardableResult
    mutating func lasso(loop: [CGPoint]) -> Set<UUID> {
        guard canBeChanged, !placesItself else { return [] }
        let marks = lassoMarks(loop: loop)
        guard !marks.isEmpty else { return [] }
        var chosen: Set<UUID> = []
        for id in Set(marks.map(\.drawing)).sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let i = index(of: id), let strokes = items[i].strokes else { continue }
            let lines = items[i].inkLines
            let take = strokes.indices.filter { marks.contains(InkMark(drawing: id, stroke: $0)) }
            let stay = strokes.indices.filter { !marks.contains(InkMark(drawing: id, stroke: $0)) }
            if stay.isEmpty { chosen.insert(id); continue }
            var piece = Item(kind: .drawing)
            piece.strokes = take.map { strokes[$0] }
            items.append(piece)
            fitDrawing(at: items.count - 1, lines: take.map { lines[$0] })
            items[i].strokes = stay.map { strokes[$0] }
            fitDrawing(at: i, lines: stay.map { lines[$0] })
            chosen.insert(piece.id)
        }
        return chosen
    }
}

// MARK: Colour for chosen sketches (39)

public extension Item {
    /// The one colour all the ordinary lines of a sketch have ("" = plain ink); nil when they differ or there are none.
    var sketchColour: String? {
        guard kind == .drawing else { return nil }
        let all = Set((strokes ?? []).filter { !$0.isHighlighter }.map(\.colour))
        return all.count == 1 ? all.first : nil
    }
}

public extension Board {
    /// Every line of the sketch takes the colour ("" = plain ink). A highlighter line takes it only when it is one of
    /// the highlighter's four colours; otherwise it keeps its own.
    mutating func recolourSketch(_ id: UUID, to name: String) {
        guard canBeChanged, let i = index(of: id), items[i].kind == .drawing, var strokes = items[i].strokes else { return }
        for n in strokes.indices {
            if strokes[n].isHighlighter {
                if Ink.highlighterColours.contains(name) { strokes[n].colour = name }
            } else {
                strokes[n].colour = name
            }
        }
        items[i].strokes = strokes
    }
}
