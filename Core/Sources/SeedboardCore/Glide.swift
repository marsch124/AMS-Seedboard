import Foundation
import CoreGraphics

/// 0.5: one glide of the view — every move of the board the owner did not make with his own fingers
/// (a zoom step, "Show the whole board", bringing a new idea into sight, the iPhone's zoom for typing).
/// The session steps the view along it, frame by frame, so the drawing, the frame round a chosen thing,
/// the bar beside it and the typing field always agree.
public struct Glide: Equatable, Sendable {
    /// A zoom step (the buttons, ⌘+ and ⌘−, Actual Size).
    public static let zoomStep = 0.22
    /// Show the whole board (the button, ⌘1, two presses on empty board).
    public static let wholeBoard = 0.30
    /// Bringing a new idea into sight, and the iPhone's zoom for typing.
    public static let intoSight = 0.18

    public let fromOffset: CGSize
    public let fromScale: Double
    public let toOffset: CGSize
    public let toScale: Double
    public let seconds: Double

    public init(fromOffset: CGSize, fromScale: Double, toOffset: CGSize, toScale: Double, seconds: Double) {
        self.fromOffset = fromOffset
        self.fromScale = fromScale
        self.toOffset = toOffset
        self.toScale = toScale
        self.seconds = seconds
    }

    /// From where the view stands to where it shall stand.
    public init(from: Viewport, to: Viewport, seconds: Double) {
        self.init(fromOffset: from.offset, fromScale: from.scale, toOffset: to.offset, toScale: to.scale, seconds: seconds)
    }

    /// Ease-out: quick at first, soft at the end. 0 gives 0, 1 gives 1.
    public static func ease(_ part: Double) -> Double {
        let left = 1 - min(max(part, 0), 1)
        return 1 - left * left * left
    }

    /// Nothing to see: the view would move less than half a point and zoom less than a tenth of a per cent.
    public var isStill: Bool {
        abs(Double(toOffset.width - fromOffset.width)) < 0.5 && abs(Double(toOffset.height - fromOffset.height)) < 0.5
            && abs(toScale - fromScale) < 0.001
    }

    /// The view `part` of the way through the glide's time (0 = the start, 1 or more = the end).
    /// When the zoom changes, the one board point that stands at the same place on screen before and after
    /// (the middle, for a zoom step) stays exactly there the whole way.
    public func view(at part: Double) -> (offset: CGSize, scale: Double) {
        guard part < 1, seconds > 0 else { return (toOffset, toScale) }
        let eased = Glide.ease(part)
        var along = eased
        var scale = toScale
        if fromScale > 0, toScale > 0, abs(toScale - fromScale) > 1e-9 {
            // The zoom goes in even steps of "times", the board slides in step with it.
            scale = fromScale * pow(toScale / fromScale, eased)
            along = (scale - fromScale) / (toScale - fromScale)
        }
        return (CGSize(width: Double(fromOffset.width) + Double(toOffset.width - fromOffset.width) * along,
                       height: Double(fromOffset.height) + Double(toOffset.height - fromOffset.height) * along), scale)
    }

    /// The view after `time` seconds.
    public func view(after time: Double) -> (offset: CGSize, scale: Double) {
        view(at: seconds > 0 ? time / seconds : 1)
    }
}
