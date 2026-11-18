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
}

extension BoardPainter {
    /// A drawing: every stroke in its own colour and thickness, in the order they were drawn.
    func drawInk(_ item: Item, _ ctx: GraphicsContext) {
        let corner = CGPoint(x: item.x, y: item.y)
        for stroke in item.strokes ?? [] where stroke.count > 0 {
            InkDraw.stroke(stroke.path(from: corner), pressure: stroke.pressure, base: stroke.thickness.points,
                           colour: InkDraw.colour(stroke.colour, paint: paint), in: ctx)
        }
    }
}
