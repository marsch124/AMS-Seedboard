import SwiftUI
import SeedboardCore

// Seedboard 0.14, idea 14: tilt a note, a picture, a free text or a flowchart shape. The rules are in
// SeedboardCore (Tilt14.swift); this file draws the turn and does the changes (one undo step each).

enum Tilt14 {
    /// The turn of a thing round its middle, in board points.
    static func turn(_ item: Item) -> CGAffineTransform {
        let c = item.centre
        return CGAffineTransform(translationX: c.x, y: c.y)
            .rotated(by: CGFloat(item.turn * .pi / 180))
            .translatedBy(x: -c.x, y: -c.y)
    }

    /// A control (grip) moved to where it lies on a turned thing; its size stays.
    static func moved(_ control: Controls.Control, _ item: Item) -> Controls.Control {
        func move(_ r: CGRect) -> CGRect {
            let c = Tilt.rotate(CGPoint(x: r.midX, y: r.midY), about: item.centre, degrees: item.turn)
            return CGRect(x: c.x - r.width / 2, y: c.y - r.height / 2, width: r.width, height: r.height)
        }
        var one = control
        one.rest = move(control.rest)
        one.grown = move(control.grown)
        return one
    }
}

extension BoardPainter {
    /// The drawing layer turned round a thing's middle by its tilt (no change for a straight thing).
    func turned(_ ctx: GraphicsContext, _ item: Item) -> GraphicsContext {
        guard item.turn != 0 else { return ctx }
        var layer = ctx
        let c = item.centre
        layer.translateBy(x: c.x, y: c.y)
        layer.rotate(by: .degrees(item.turn))
        layer.translateBy(x: -c.x, y: -c.y)
        return layer
    }
}

extension BoardSession {
    private var mayTilt: Bool { !readOnly && !board.placesItself && editing == nil && board.tiltable(selection) }

    /// The "Tilt" button: straight → a little left → a little right → straight. One undo step.
    func tiltStep() {
        guard mayTilt else { return }
        let ids = selection
        change { $0.stepTilt(ids) }
    }

    /// A chosen angle from the menu ("Straighten", "Lean left", "Lean right"). One undo step.
    func tilt(to degrees: Double?) {
        guard mayTilt else { return }
        let ids = selection
        change { $0.setTilt(ids, to: degrees) }
    }

    // MARK: Two-finger twist (iPhone and iPad)

    /// A twist begins between two fingers at this screen point: only when one tiltable thing is chosen and the
    /// fingers are on it. True when it took the twist.
    func twistBegin(at point: CGPoint) -> Bool {
        guard mayTilt, selection.count == 1, let item = board.item(selection.first!), !busy else { return false }
        let box = toScreen(Tilt.bounds(of: item.frame, turnedBy: item.turn)).insetBy(dx: -20, dy: -20)
        guard box.contains(point) else { return false }
        twistIDs = selection
        twistFrom = item.tilt ?? 0
        twisting = true
        liveStart()
        return true
    }

    /// The thing follows the fingers; `degrees` is the turn since the twist began (clockwise).
    func twistMove(_ degrees: Double) {
        guard twisting else { return }
        let ids = twistIDs, value = twistFrom + degrees
        live { $0.setTilt(ids, to: value) }
    }

    /// The fingers lift: within 3 degrees of straight it snaps straight. One undo step.
    func twistEnd(_ degrees: Double, keep: Bool) {
        guard twisting else { return }
        let ids = twistIDs, value = Tilt.snapped(twistFrom + degrees)
        live { $0.setTilt(ids, to: value) }
        twisting = false
        liveEnd(keep: keep)
    }
}
