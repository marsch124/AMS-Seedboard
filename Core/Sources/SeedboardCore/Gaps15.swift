import Foundation
import CoreGraphics

// Seedboard 0.15: one colour, one meaning on a timeline, and sizing a tilted thing by its own edges.
// Rules only — no screen.

public enum TimelineColours {
    /// A new milestone's colour. Purple means PARAGON in this app, so a milestone is orange.
    public static let milestone = "orange"
    /// Colours a new bar takes by itself, in turn. Never purple (PARAGON) or red (late).
    public static let bars = ["pink", "orange", "teal", "blue", "green"]
    /// Colours a new phase takes by itself, in turn. Never purple or red.
    public static let phases = ["teal", "blue", "orange", "green", "pink"]

    public static func bar(_ index: Int) -> String { bars[((index % bars.count) + bars.count) % bars.count] }
    public static func phase(_ index: Int) -> String { phases[((index % phases.count) + phases.count) % phases.count] }
}

public extension Tilt {
    /// A drag on the board, seen along the edges of a thing turned by `degrees`.
    static func along(_ delta: CGSize, turnedBy degrees: Double) -> CGSize {
        guard degrees != 0 else { return delta }
        let p = rotate(CGPoint(x: delta.width, y: delta.height), about: .zero, degrees: -degrees)
        return CGSize(width: p.x, height: p.y)
    }

    /// A turned thing changed size from `base` to `now` (both straight boxes, the same corner held): how far
    /// to slide it so that the held corner stays where it was on the screen.
    static func slide(from base: CGRect, to now: CGRect, turnedBy degrees: Double) -> CGSize {
        guard degrees != 0 else { return .zero }
        let c0 = CGPoint(x: base.midX, y: base.midY), c1 = CGPoint(x: now.midX, y: now.midY)
        let d = CGPoint(x: c0.x - c1.x, y: c0.y - c1.y)
        let turned = rotate(d, about: .zero, degrees: degrees)
        return CGSize(width: d.x - turned.x, height: d.y - turned.y)
    }

    /// Where a point of a straight box lies once the box is turned round its middle.
    static func onScreen(_ p: CGPoint, of box: CGRect, turnedBy degrees: Double) -> CGPoint {
        rotate(p, about: CGPoint(x: box.midX, y: box.midY), degrees: degrees)
    }
}
