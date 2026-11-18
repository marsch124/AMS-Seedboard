import SwiftUI
import SeedboardCore

// The four flow shapes that are new in 0.2 — Person, Document, Slanted box, Store — drawn in the
// same clean hand as the Box: one even line with round joins, the plate's colour inside, or the
// soft tint of the colour the owner gave it. Every measure comes from `ShapeOutline` in the Core,
// so the words and the arrows always meet what is drawn here.

extension BoardPainter {
    /// Draws the outline of a Person, a Document, a Slanted box or a Store.
    func drawOutline(_ item: Item, _ ctx: inout GraphicsContext) {
        let shape = ShapePaths.outline(item.kind, item.frame)
        let fill: Color, line: Color, width: CGFloat
        if item.colour.isEmpty {
            fill = paint.plate; line = paint.edge; width = 1.4
        } else {
            fill = paint.soft(item.colour); line = paint.line(item.colour); width = 1.8
        }
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        ctx.fill(shape.body, with: .color(fill))
        ctx.stroke(shape.body, with: .color(line), style: style)
        if let inner = shape.inner { ctx.stroke(inner, with: .color(line), style: style) }
    }
}

extension Item {
    /// Where the words are typed in place: the whole thing, or for the new shapes the part their
    /// words may fill (12 wider at each side, which the field takes back as its own padding).
    var typingFrame: CGRect {
        switch kind {
        case .person, .document, .slanted, .store:
            return ShapeOutline.textBox(kind, frame).insetBy(dx: -12, dy: 0)
        default:
            return frame
        }
    }
}
