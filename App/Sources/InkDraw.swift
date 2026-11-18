import SwiftUI
import SeedboardCore

// How a line drawn by hand is painted (0.2). ONE piece of drawing code for the live board, the Mac,
// the small pictures on the home page, the picture that goes to PARAGON — and the wet line that
// runs under the Pencil while it is down. The way of a line (its rounded corners, its widths under
// pressure) is worked out in SeedboardCore (`Ink.runs`); here it only becomes paint.

enum InkDraw {
    /// A stroke's colour: a palette name, by day and by night; no name is plain ink.
    static func colour(_ name: String, paint: Paint) -> Color {
        name.isEmpty ? paint.ink : paint.line(name)
    }

    static func path(_ run: InkRun) -> Path {
        var path = Path()
        var here = CGPoint.zero
        for step in run.steps {
            switch step {
            case .move(let p):
                path.move(to: p)
                here = p
            case .line(let p):
                // A dot: a line to where it already is draws nothing, so it goes a hair further.
                path.addLine(to: p == here ? CGPoint(x: p.x + 0.01, y: p.y) : p)
                here = p
            case .curve(let p, let control):
                path.addQuadCurve(to: p, control: control)
                here = p
            }
        }
        return path
    }

    /// Paints one line through the points (board points; the context must be in board points too).
    static func stroke(_ points: [CGPoint], pressure: [Double]?, base: Double, colour: Color, in ctx: GraphicsContext) {
        for run in Ink.runs(points, pressure: pressure, base: base) {
            ctx.stroke(path(run), with: .color(colour),
                       style: StrokeStyle(lineWidth: run.width, lineCap: .round, lineJoin: .round))
        }
    }

    /// A highlighter line (0.9): wide, see-through (35 %), flat ends, one width whatever the pressure.
    /// Drawn as one path in one go, so its own overlaps do not darken.
    static func highlight(_ points: [CGPoint], colour: Color, in ctx: GraphicsContext) {
        var path = Path()
        if let first = points.first {
            path.move(to: first)
            for p in points.dropFirst() { path.addLine(to: p) }
            if points.count == 1 { path.addLine(to: CGPoint(x: first.x + 0.01, y: first.y)) }
        }
        ctx.stroke(path, with: .color(colour.opacity(Ink.highlighterOpacity)),
                   style: StrokeStyle(lineWidth: CGFloat(Ink.highlighterWidth), lineCap: .butt, lineJoin: .round))
    }

    /// One stored stroke, the highlighter's way or the pen's.
    static func paint(_ stroke: Stroke, from corner: CGPoint, paint: Paint, in ctx: GraphicsContext) {
        let colour = InkDraw.colour(stroke.colour, paint: paint)
        if stroke.isHighlighter {
            highlight(stroke.path(from: corner), colour: colour, in: ctx)
        } else {
            InkDraw.stroke(stroke.path(from: corner), pressure: stroke.pressure, base: stroke.thickness.points, colour: colour, in: ctx)
        }
    }
}

extension BoardPainter {
    /// A drawing: every stroke in its own colour and thickness, in the order they were drawn.
    func drawInk(_ item: Item, _ ctx: GraphicsContext) {
        let corner = CGPoint(x: item.x, y: item.y)
        // The highlighter lies under the ordinary ink of the same drawing (Ink.swift: `paintedStrokes`).
        for stroke in item.paintedStrokes { InkDraw.paint(stroke, from: corner, paint: paint, in: ctx) }
    }

    /// Marks drawn on a picture (0.9): measured from its corner, above the picture, cut off at its edge.
    func drawPictureMarks(_ item: Item, _ ctx: GraphicsContext) {
        guard let marks = item.strokes, !marks.isEmpty else { return }
        var inside = ctx
        inside.clip(to: Path(roundedRect: item.frame, cornerRadius: 4))
        let corner = CGPoint(x: item.x, y: item.y)
        for stroke in item.paintedStrokes { InkDraw.paint(stroke, from: corner, paint: paint, in: inside) }
    }
}
