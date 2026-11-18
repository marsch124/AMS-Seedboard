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
        let clamped = min(max(newScale, 0.2), 3)
        let under = toBoard(anchor)
        scale = clamped
        offset = CGSize(width: Double(anchor.x) - Double(under.x) * clamped, height: Double(anchor.y) - Double(under.y) * clamped)
    }

    /// Shows everything inside the box (the whole board), never bigger than life size.
    public mutating func fit(_ all: CGRect?) {
        guard size.width > 10, size.height > 10 else { return }
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

    /// The room changed (a window settling, the keyboard coming up, a page opening over the board).
    /// The board is shown whole again only while the owner has not moved it.
    public mutating func resized(to newSize: CGSize, showing all: CGRect?) {
        size = newSize
        guard !movedByOwner, newSize.width > 10 else { return }
        fit(all)
    }
}
