import Foundation
import CoreGraphics

// The soft dot grid behind a board: a dot every 24 board points. Zoomed out, every second
// dot is left out (again and again) so the dots never stand closer than 12 screen points,
// and below 40 % zoom they fade away. Only the dots that can be seen are worked out.

public enum DotGrid {
    /// Board points between two dots at life size.
    public static let pitch: CGFloat = 24
    /// A dot's width in screen points.
    public static let dot: CGFloat = 1.5
    /// Dots never stand closer than this many screen points.
    public static let closest: CGFloat = 12
    /// Below this zoom the dots fade; at `gone` nothing is left of them.
    public static let fadeFrom: CGFloat = 0.4
    public static let gone: CGFloat = 0.2

    /// Board points between two dots at this zoom: 24, 48, 96 …
    public static func step(scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return pitch }
        var step = pitch
        while step * scale < closest, step < pitch * 64 { step *= 2 }
        return step
    }

    /// How strong the dots are at this zoom: 1 from 40 % up, fading to 0 at 20 %.
    public static func strength(scale: CGFloat) -> CGFloat {
        min(1, max(0, (scale - gone) / (fadeFrom - gone)))
    }

    /// The dots inside the part of the board that can be seen, in board points.
    public static func dots(in visible: CGRect, scale: CGFloat) -> [CGPoint] {
        guard strength(scale: scale) > 0, visible.width > 0, visible.height > 0,
              visible.minX.isFinite, visible.maxX.isFinite, visible.minY.isFinite, visible.maxY.isFinite else { return [] }
        let step = step(scale: scale)
        let x0 = SafeNumber.int((visible.minX / step).rounded(.up)), x1 = SafeNumber.int((visible.maxX / step).rounded(.down))
        let y0 = SafeNumber.int((visible.minY / step).rounded(.up)), y1 = SafeNumber.int((visible.maxY / step).rounded(.down))
        guard x0 <= x1, y0 <= y1, (x1 - x0 + 1) <= 20_000, (y1 - y0 + 1) <= 20_000, (x1 - x0 + 1) * (y1 - y0 + 1) <= 400_000 else { return [] }
        var points: [CGPoint] = []
        points.reserveCapacity((x1 - x0 + 1) * (y1 - y0 + 1))
        for y in y0...y1 {
            for x in x0...x1 { points.append(CGPoint(x: CGFloat(x) * step, y: CGFloat(y) * step)) }
        }
        return points
    }
}
