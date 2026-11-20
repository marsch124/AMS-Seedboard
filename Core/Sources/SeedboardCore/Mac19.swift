import Foundation

/// 0.19 (picks 49 and 50): where the iPad's tool bar sits, and the first lines of a board for the Mac's Quick look.
public enum ToolDock: String, CaseIterable, Sendable {
    case bottom, left, right

    public var vertical: Bool { self != .bottom }

    /// The edge nearest to a point in an area of this size (top is not offered: it would cover the board's top bar).
    public static func nearest(x: Double, y: Double, width: Double, height: Double) -> ToolDock {
        let l = x, r = width - x, b = height - y
        if b <= l && b <= r { return .bottom }
        return l <= r ? .left : .right
    }

    public static func stored(_ raw: String?) -> ToolDock { raw.flatMap(ToolDock.init(rawValue:)) ?? .bottom }
}

public extension Board {
    /// The first lines of the board as text (the words "Copy the board as text" writes), for the Mac's Quick look.
    func quickLookLines(limit: Int = 6) -> [String] {
        let lines = outlineText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Array(lines.prefix(limit))
    }
}
