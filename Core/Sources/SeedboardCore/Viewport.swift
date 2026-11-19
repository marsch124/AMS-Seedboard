import Foundation
import CoreGraphics

/// Where the board stands on screen: the place of its zero point, how big one board point is,
/// and whether the owner has moved or zoomed it. Until the owner has, the board is shown whole
/// again whenever its room changes; after that it stays where the owner left it.
public struct Viewport: Equatable, Sendable {
    public var offset: CGSize = .zero
    public var scale: Double = 1
    /// The room the board has on screen.
    public var size: CGSize = .zero
    /// The owner slid, scrolled or zoomed the board.
    public private(set) var movedByOwner = false
    /// A small screen zoomed in for typing: the zoom before, to go back to afterwards.
    public private(set) var scaleBeforeTyping: Double?
    /// A reopened board holds the spot it was left at while its room settles (pick 26, Remember.swift).
    public internal(set) var pin: ViewPin?

    public init() {}

    public func toBoard(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (Double(p.x) - Double(offset.width)) / scale, y: (Double(p.y) - Double(offset.height)) / scale)
    }

    public mutating func pan(by delta: CGSize) {
        movedByOwner = true
        offset = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
    }

    /// A finger slide: the view stands where it stood when the slide began, moved by the finger's way.
    public mutating func slide(from start: CGSize, by way: CGSize) {
        pan(by: CGSize(width: start.width + way.width - offset.width, height: start.height + way.height - offset.height))
    }

    /// Zooms so the board point under the screen point (the middle, if none is given) stays where it is.
    public mutating func zoom(to newScale: Double, around point: CGPoint? = nil) {
        let anchor = point ?? CGPoint(x: size.width / 2, y: size.height / 2)
        movedByOwner = true
        scaleBeforeTyping = nil
        let clamped = min(max(newScale, 0.2), 3)
        let under = toBoard(anchor)
        scale = clamped
        offset = CGSize(width: Double(anchor.x) - Double(under.x) * clamped, height: Double(anchor.y) - Double(under.y) * clamped)
    }

    /// Shows everything inside the box (the whole board), never bigger than life size.
    public mutating func fit(_ all: CGRect?) {
        guard size.width > 10, size.height > 10 else { return }
        scaleBeforeTyping = nil
        guard let all else {
            scale = 1
            offset = CGSize(width: size.width / 2, height: size.height / 2)
            return
        }
        let room = CGSize(width: max(size.width - 80, 80), height: max(size.height - 170, 80))
        let s = min(1, min(Double(room.width) / max(Double(all.width), 1), Double(room.height) / max(Double(all.height), 1)))
        // Never so small that the words cannot be read: on a small screen the middle of the board shows.
        scale = max(s, 0.5)
        offset = CGSize(width: Double(size.width) / 2 - Double(all.midX) * scale, height: Double(size.height) / 2 - Double(all.midY) * scale)
    }

    // 0.14 (look, 19): shows the chosen things so they fill the room, with a margin. Zooms in as far as twice
    // life size and out to a fifth, never beyond. Nothing happens for an empty box.
    public mutating func fitChosen(_ box: CGRect?) {
        guard let box, size.width > 10, size.height > 10 else { return }
        movedByOwner = true
        scaleBeforeTyping = nil
        let room = CGSize(width: max(size.width - 120, 80), height: max(size.height - 220, 80))
        let s = min(Double(room.width) / max(Double(box.width), 1), Double(room.height) / max(Double(box.height), 1))
        scale = min(max(s, 0.2), 2)
        offset = CGSize(width: Double(size.width) / 2 - Double(box.midX) * scale, height: Double(size.height) / 2 - Double(box.midY) * scale)
    }

    /// The room changed (a window settling, the keyboard coming up, a page opening over the board).
    /// The board is shown whole again only while the owner has not moved it.
    /// `readableAround`: on a small screen, the main thing — the board then opens readable (see `open`).
    public mutating func resized(to newSize: CGSize, showing all: CGRect?, readableAround main: CGRect? = nil) {
        size = newSize
        if holdPin() { return }
        // While the view is zoomed in for typing, the keyboard coming up does not show the board whole again.
        guard !movedByOwner, scaleBeforeTyping == nil, newSize.width > 10 else { return }
        if let main { open(all, around: main) } else { fit(all) }
    }

    // MARK: iPhone and iPad

    /// Two fingers: the board point that was between the fingers stays between them while they
    /// move (the board slides) and spread or close (it zooms) — both in one step.
    /// `factor`: how much further apart the fingers are than at the step before (1 = the same).
    public mutating func pinch(from old: CGPoint, to new: CGPoint, by factor: Double) {
        movedByOwner = true
        let under = toBoard(old)
        if factor.isFinite, factor > 0, factor != 1 {
            scale = min(max(scale * factor, 0.2), 3)
            scaleBeforeTyping = nil
        }
        offset = CGSize(width: Double(new.x) - Double(under.x) * scale, height: Double(new.y) - Double(under.y) * scale)
    }

    /// A small screen opens a board readable. When the whole board can be shown at `least`
    /// (75 %) or bigger, it is. Otherwise the board is shown at `least` with the main thing in the
    /// middle — moved only as far as the board's own edge, so no room is given to empty board.
    public mutating func open(_ all: CGRect?, around main: CGRect?, least: Double = 0.75) {
        fit(all)
        guard size.width > 10, size.height > 10, let all, let main else { return }
        let room = CGSize(width: max(size.width - 80, 80), height: max(size.height - 170, 80))
        let whole = min(1, min(Double(room.width) / max(Double(all.width), 1), Double(room.height) / max(Double(all.height), 1)))
        guard whole < least else { return }
        scale = least
        /// One direction: the main thing in the middle, but the board's edge never further in than its margin.
        func settle(_ mid: Double, _ low: Double, _ high: Double, room: Double, before: Double, after: Double) -> Double {
            if (high - low) * least + before + after <= room { return before + (room - before - after) / 2 - (low + high) / 2 * least }
            return min(max(room / 2 - mid * least, room - after - high * least), before - low * least)
        }
        offset = CGSize(
            width: settle(Double(main.midX), Double(all.minX), Double(all.maxX), room: Double(size.width), before: 40, after: 40),
            height: settle(Double(main.midY), Double(all.minY), Double(all.maxY), room: Double(size.height), before: 70, after: 100))
    }

    /// Typing began on a small screen: the view is at least life size, and the thing typed in stays
    /// where it is on screen. Does nothing when the view is big enough or already zoomed for typing.
    /// True when the view changed.
    @discardableResult
    public mutating func typingBegan(round box: CGRect, least: Double = 1) -> Bool {
        guard scaleBeforeTyping == nil, scale < least else { return false }
        scaleBeforeTyping = scale
        rescale(to: least, holding: CGPoint(x: box.midX, y: box.midY))
        return true
    }

    /// Typing ended: back to the zoom before, round the thing that was typed in (the middle of the
    /// view when it is gone). True when the view changed.
    @discardableResult
    public mutating func typingEnded(round box: CGRect?) -> Bool {
        guard let before = scaleBeforeTyping else { return false }
        scaleBeforeTyping = nil
        let held = box.map { CGPoint(x: $0.midX, y: $0.midY) } ?? toBoard(CGPoint(x: size.width / 2, y: size.height / 2))
        rescale(to: before, holding: held)
        return true
    }

    /// Another zoom with this board point staying where it is on screen. Not a move by the owner.
    private mutating func rescale(to newScale: Double, holding p: CGPoint) {
        let x = Double(p.x) * scale + Double(offset.width), y = Double(p.y) * scale + Double(offset.height)
        scale = newScale
        offset = CGSize(width: x - Double(p.x) * newScale, height: y - Double(p.y) * newScale)
    }
}
