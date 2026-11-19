import Foundation
import CoreGraphics

// Seedboard 0.14, idea 14: tilt a note, a picture, a free text or a flowchart shape, like a note stuck
// on crooked. Stored in `Item.tilt` (degrees, clockwise); nil means straight. Rules only — no screen.

public enum Tilt {
    /// The most a thing may be turned, either way.
    public static let limit: Double = 45
    /// What "Tilt" steps through: straight, a little left, a little right, straight again.
    public static let steps: [Double] = [0, -4, 4]
    /// A twist that ends this close to straight snaps to straight.
    public static let snap: Double = 3

    /// The kinds that can be tilted: a note, a picture, a free text and the flowchart shapes.
    public static func canTilt(_ kind: ItemKind) -> Bool {
        kind == .note || kind == .picture || kind == .text || kind.isShape
    }

    /// What is stored for a turn: kept within the limit; straight (or nothing sensible) is nil.
    public static func stored(_ degrees: Double) -> Double? {
        guard degrees.isFinite else { return nil }
        let d = max(-limit, min(limit, degrees))
        return abs(d) < 0.05 ? nil : d
    }

    /// A twist that ends: snaps to straight within `snap` degrees.
    public static func snapped(_ degrees: Double) -> Double? {
        abs(degrees) <= snap ? nil : stored(degrees)
    }

    /// The next step of the "Tilt" button: 0 → −4° → 4° → 0. Anything else starts again at −4°.
    public static func next(after current: Double?) -> Double? {
        let now = current ?? 0
        if abs(now) < 0.05 { return -4 }
        if abs(now - -4) < 0.05 { return 4 }
        if abs(now - 4) < 0.05 { return nil }
        return -4
    }

    /// A point turned round another, by degrees clockwise (the board's y runs down).
    public static func rotate(_ p: CGPoint, about c: CGPoint, degrees: Double) -> CGPoint {
        guard degrees != 0 else { return p }
        let r = degrees * .pi / 180
        let s = sin(r), k = cos(r)
        let dx = Double(p.x - c.x), dy = Double(p.y - c.y)
        return CGPoint(x: Double(c.x) + dx * k - dy * s, y: Double(c.y) + dx * s + dy * k)
    }

    /// Is the point inside the box once the box is turned by `degrees` round its middle?
    public static func contains(_ box: CGRect, turnedBy degrees: Double, _ p: CGPoint) -> Bool {
        box.contains(rotate(p, about: CGPoint(x: box.midX, y: box.midY), degrees: -degrees))
    }

    /// The smallest upright box round a box turned by `degrees` round its middle.
    public static func bounds(of box: CGRect, turnedBy degrees: Double) -> CGRect {
        guard degrees != 0 else { return box }
        let c = CGPoint(x: box.midX, y: box.midY)
        let corners = [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                       CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY)]
            .map { rotate($0, about: c, degrees: degrees) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}

public extension Item {
    /// How far this thing is turned (clockwise degrees); 0 for a kind that cannot be tilted.
    var turn: Double { Tilt.canTilt(kind) ? (tilt ?? 0) : 0 }
}

public extension Board {
    /// The chosen things that can be tilted, all of them or none.
    func tiltable(_ ids: Set<UUID>) -> Bool {
        !ids.isEmpty && ids.allSatisfy { item($0).map { Tilt.canTilt($0.kind) } ?? false }
    }

    /// Turns the things to these degrees (nil or 0: straight, stored as nothing).
    mutating func setTilt(_ ids: Set<UUID>, to degrees: Double?) {
        let value = degrees.flatMap { Tilt.stored($0) }
        for i in items.indices where ids.contains(items[i].id) && Tilt.canTilt(items[i].kind) {
            items[i].tilt = value
        }
    }

    /// "Tilt": each press moves the chosen things one step on (they all take the step of the first).
    mutating func stepTilt(_ ids: Set<UUID>) {
        guard let first = items.first(where: { ids.contains($0.id) && Tilt.canTilt($0.kind) }) else { return }
        setTilt(ids, to: Tilt.next(after: first.tilt))
    }
}
