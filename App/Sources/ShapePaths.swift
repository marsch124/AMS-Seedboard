import SwiftUI
import SeedboardCore

// The outlines of the four new flow shapes as paths. Every measure comes from `ShapeOutline`
// in the Core, so the words and the arrows always meet what is drawn.

enum ShapePaths {
    /// The closed outline of a new kind of shape, and the line drawn inside it (the front lip of a Store).
    static func outline(_ kind: ItemKind, _ f: CGRect) -> (body: Path, inner: Path?) {
        switch kind {
        case .person:
            let fig = ShapeOutline.figure(in: f)
            var p = Path(ellipseIn: fig.head)
            // The shoulders: the upper half of an oval that stands on the base line.
            let s = fig.shoulders
            p.move(to: CGPoint(x: s.minX, y: fig.base))
            p.addCurve(to: CGPoint(x: s.midX, y: s.minY),
                       control1: CGPoint(x: s.minX, y: fig.base - s.height / 2 * 0.5523),
                       control2: CGPoint(x: s.midX - s.width / 2 * 0.5523, y: s.minY))
            p.addCurve(to: CGPoint(x: s.maxX, y: fig.base),
                       control1: CGPoint(x: s.midX + s.width / 2 * 0.5523, y: s.minY),
                       control2: CGPoint(x: s.maxX, y: fig.base - s.height / 2 * 0.5523))
            p.closeSubpath()
            return (p, nil)

        case .document:
            let a = ShapeOutline.wave(f)
            let line = f.maxY - a
            let r = min(7, f.width / 4, f.height / 4)
            // Two controls at 4/3 of the swing make the curve reach exactly the swing.
            let reach = a * 4 / 3
            var p = Path()
            p.move(to: CGPoint(x: f.minX, y: line))
            p.addLine(to: CGPoint(x: f.minX, y: f.minY + r))
            p.addQuadCurve(to: CGPoint(x: f.minX + r, y: f.minY), control: CGPoint(x: f.minX, y: f.minY))
            p.addLine(to: CGPoint(x: f.maxX - r, y: f.minY))
            p.addQuadCurve(to: CGPoint(x: f.maxX, y: f.minY + r), control: CGPoint(x: f.maxX, y: f.minY))
            p.addLine(to: CGPoint(x: f.maxX, y: line))
            // The wavy bottom edge, right to left: up over the right half, down under the left half.
            p.addCurve(to: CGPoint(x: f.midX, y: line),
                       control1: CGPoint(x: f.maxX - f.width * 0.17, y: line - reach),
                       control2: CGPoint(x: f.midX + f.width * 0.17, y: line - reach))
            p.addCurve(to: CGPoint(x: f.minX, y: line),
                       control1: CGPoint(x: f.midX - f.width * 0.17, y: line + reach),
                       control2: CGPoint(x: f.minX + f.width * 0.17, y: line + reach))
            p.closeSubpath()
            return (p, nil)

        case .slanted:
            let s = ShapeOutline.slant(f)
            var p = Path()
            p.move(to: CGPoint(x: f.minX + s, y: f.minY))
            p.addLine(to: CGPoint(x: f.maxX, y: f.minY))
            p.addLine(to: CGPoint(x: f.maxX - s, y: f.maxY))
            p.addLine(to: CGPoint(x: f.minX, y: f.maxY))
            p.closeSubpath()
            return (p, nil)

        case .store:
            let r = ShapeOutline.rim(f)
            let k = 0.5523 * f.width / 2
            let top = f.minY + r, bottom = f.maxY - r
            var p = Path()
            p.move(to: CGPoint(x: f.minX, y: top))
            p.addLine(to: CGPoint(x: f.minX, y: bottom))
            // The bottom: the lower half of an oval.
            p.addCurve(to: CGPoint(x: f.midX, y: f.maxY),
                       control1: CGPoint(x: f.minX, y: bottom + r * 0.5523), control2: CGPoint(x: f.midX - k, y: f.maxY))
            p.addCurve(to: CGPoint(x: f.maxX, y: bottom),
                       control1: CGPoint(x: f.midX + k, y: f.maxY), control2: CGPoint(x: f.maxX, y: bottom + r * 0.5523))
            p.addLine(to: CGPoint(x: f.maxX, y: top))
            // The top: the upper half of the lid.
            p.addCurve(to: CGPoint(x: f.midX, y: f.minY),
                       control1: CGPoint(x: f.maxX, y: top - r * 0.5523), control2: CGPoint(x: f.midX + k, y: f.minY))
            p.addCurve(to: CGPoint(x: f.minX, y: top),
                       control1: CGPoint(x: f.midX - k, y: f.minY), control2: CGPoint(x: f.minX, y: top - r * 0.5523))
            p.closeSubpath()
            // The front lip of the lid.
            var lip = Path()
            lip.move(to: CGPoint(x: f.minX, y: top))
            lip.addCurve(to: CGPoint(x: f.midX, y: top + r),
                         control1: CGPoint(x: f.minX, y: top + r * 0.5523), control2: CGPoint(x: f.midX - k, y: top + r))
            lip.addCurve(to: CGPoint(x: f.maxX, y: top),
                         control1: CGPoint(x: f.midX + k, y: top + r), control2: CGPoint(x: f.maxX, y: top + r * 0.5523))
            return (p, lip)

        default:
            return (Path(roundedRect: f, cornerRadius: 9), nil)
        }
    }
}
