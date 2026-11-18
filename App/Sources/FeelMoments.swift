import SwiftUI
import SeedboardCore

// 0.5 (the feel lane): where the board calls the eight moments of Feel.swift. The rules of WHEN are in
// Core (FeelRules.swift, with their data tests); the board's own code only names the moment.

extension Feel {
    /// While dragging or sizing: hands the guides on as they are, and ticks when a guide line appeared.
    static func catching(_ guides: [Snap.Guide], after before: [Snap.Guide]) -> [Snap.Guide] {
        if FeelRules.guideAppeared(before: before.count, now: guides.count) { caught() }
        return guides
    }

    /// One step of a pinch from one zoom to the next: a tick when it passes life size, a knock when it
    /// reaches the smallest or the largest zoom (once).
    static func zoomed(from old: CGFloat, to new: CGFloat) {
        switch FeelRules.zoomMoment(from: Double(old), to: Double(new)) {
        case .lifeSize: lifeSize()
        case .theEnd: theEnd()
        case nil: break
        }
    }

    /// A dragged idea is let go here: felt when it will hang under another idea or land between two sisters.
    static func ideaDropped(_ hints: (target: UUID?, line: Landing?)) {
        if FeelRules.ideaSetDown(hangs: hints.target != nil, lands: hints.line != nil) { setDown() }
    }
}

extension BoardSession {
    /// Two fingers on the glass, with what the hand feels on the way (life size, the end).
    func feltPinch(from old: CGPoint, to new: CGPoint, by factor: CGFloat) {
        let before = scale
        pinch(from: old, to: new, by: factor)
        // A timeline steps through days, weeks and months: it has no life size.
        if !board.isTimeline { Feel.zoomed(from: before, to: scale) }
    }

    /// A trackpad's pinch, with what the hand feels on the way (life size, the end).
    func feltZoom(to newScale: CGFloat, around point: CGPoint? = nil) {
        let before = scale
        zoom(to: newScale, around: point)
        if !board.isTimeline { Feel.zoomed(from: before, to: scale) }
    }
}
