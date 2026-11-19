import Foundation
import CoreGraphics

/// Rules for a finger on iPhone and iPad: how big a press area must be, which thing a press means,
/// and when the first finger's shove is taken back. All sizes are in SCREEN points, so they stay
/// the same at every zoom.
public enum Fingers {
    /// The smallest comfortable press area of a button or a thing on the board.
    public static let button: Double = 44
    /// The smallest press area of the small controls round a chosen thing (plus-handles, size knob).
    public static let control: Double = 32
    /// A control is always caught this close to its drawn box, whatever lies there.
    public static let close: Double = 9

    /// Two fingers only ever slide and zoom the board. What the first finger did to a thing before
    /// the second one landed is taken back when it was a shove: the second finger came within half a
    /// second, or the thing went less than 30 points. A longer, later move is kept as it stands.
    public static func isShove(moved points: Double, after seconds: Double) -> Bool {
        seconds < 0.5 || points < 30
    }

    /// Which of the small controls a press means, if any. `boxes` are the controls as drawn.
    /// Within `close` of its box a control is always caught. Further out — up to a press area of
    /// `least` — it is caught only when no thing lies exactly under the press (`onThing` false),
    /// so the bigger press area never takes a press away from the thing itself.
    /// Among several the nearest wins.
    public static func control(at point: CGPoint, boxes: [CGRect], onThing: Bool,
                               least: Double = control, close: Double = close) -> Int? {
        var best: (index: Int, far: Double)?
        for (i, box) in boxes.enumerated() {
            var caught = box.insetBy(dx: -close, dy: -close).contains(point)
            if !caught, !onThing {
                let dx = max(close, (least - Double(box.width)) / 2)
                let dy = max(close, (least - Double(box.height)) / 2)
                caught = box.insetBy(dx: -dx, dy: -dy).contains(point)
            }
            guard caught else { continue }
            let far = distance(from: point, to: box)
            if best == nil || far < best!.far { best = (i, far) }
        }
        return best?.index
    }

    /// How far a point is from a box; nothing when it is inside.
    public static func distance(from p: CGPoint, to box: CGRect) -> Double {
        let dx = max(Double(box.minX) - Double(p.x), 0, Double(p.x) - Double(box.maxX))
        let dy = max(Double(box.minY) - Double(p.y), 0, Double(p.y) - Double(box.maxY))
        return (dx * dx + dy * dy).squareRoot()
    }
}

public extension Board {
    /// The thing a finger means. What lies exactly under the point comes first (the topmost).
    /// Otherwise a thing that is smaller on screen than `least` points is caught in a press area of
    /// that size round it, and among several the nearest wins. `scale`: screen points per board point.
    func hit(_ point: CGPoint, scale: Double, least: Double = Fingers.button) -> UUID? {
        if let exact = hit(point) { return exact }
        // A drawing is caught near its lines: 6 screen points for a pointer, half a finger for a finger.
        if scale > 0, let sketch = inkHit(point, reach: max(least / 2, Ink.reach) / scale) { return sketch }
        guard least > 0, scale > 0 else { return nil }
        let side = least / scale
        var best: (id: UUID, far: Double)?
        for item in items where item.kind != .frame && item.kind != .drawing && !isHidden(item.id) {
            let f = item.frame
            let point = item.turn == 0 ? point : Tilt.rotate(point, about: item.centre, degrees: -item.turn)
            let dx = max(0, (side - Double(f.width)) / 2)
            let dy = max(0, (side - Double(f.height)) / 2)
            guard dx > 0 || dy > 0, f.insetBy(dx: -dx, dy: -dy).contains(point) else { continue }
            let far = Fingers.distance(from: point, to: f)
            // Equally near: the one on top (later in the list).
            if best == nil || far <= best!.far { best = (item.id, far) }
        }
        return best?.id
    }

    /// The thing a small screen opens on: the middle idea of the first mind map, else the first
    /// shape, note or text, else the first frame.
    var mainThing: Item? {
        items.first { $0.kind == .idea && $0.parent == nil }
            ?? items.first { $0.kind != .frame && !isHidden($0.id) }
            ?? items.first
    }
}
