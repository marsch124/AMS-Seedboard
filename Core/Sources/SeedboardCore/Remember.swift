import Foundation
import CoreGraphics

/// A board's view as the owner left it: the zoom, and the board point that stood in the middle of the
/// room. The middle, not the corner, so the same spot comes back in a window of another size.
public struct LeftView: Codable, Equatable, Sendable {
    public var scale: Double
    public var x: Double
    public var y: Double

    public init(scale: Double, x: Double, y: Double) {
        self.scale = scale
        self.x = x
        self.y = y
    }
}

/// What ONE device remembers between two starts. It lives in the device's own settings and is never
/// synced: which board was open, and every board's view.
public struct Remembered: Codable, Equatable, Sendable {
    /// The board that was open; nil when the owner left the app on the home page.
    public var open: UUID?
    /// Each board's view, by the board's id as text.
    public var views: [String: LeftView]
    /// 0.11: the boards opened last, newest first, at most five (the Mac's "Open Recent").
    public var recent: [UUID]

    public init(open: UUID? = nil, views: [String: LeftView] = [:], recent: [UUID] = []) {
        self.open = open
        self.views = views
        self.recent = recent
    }

    enum CodingKeys: String, CodingKey {
        case open
        case views
        case recent
    }

    /// Tolerant: whatever cannot be read is simply not remembered.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        open = try? c.decode(UUID.self, forKey: .open)
        views = (try? c.decode([String: LeftView].self, forKey: .views)) ?? [:]
        recent = (try? c.decode([UUID].self, forKey: .recent)) ?? []
    }

    public func view(of board: UUID) -> LeftView? { views[board.uuidString] }

    public mutating func note(_ view: LeftView?, of board: UUID) {
        views[board.uuidString] = view
    }

    /// Boards that are gone are forgotten, so the list never grows without end.
    public func keeping(_ boards: Set<UUID>) -> Remembered {
        var kept = self
        kept.views = views.filter { entry in UUID(uuidString: entry.key).map(boards.contains) ?? false }
        kept.recent = recent.filter(boards.contains)
        return kept
    }
}

/// What comes back when the app starts.
public enum Reopen {
    /// Launch words that set the scene themselves (pictures and tests). With one of them nothing is
    /// brought back; with `-sampleData` nothing is remembered either.
    public static let sceneWords: Set<String> = ["-sampleData", "-board", "-pick", "-pickAll", "-send", "-sendNow", "-settings", "-starters"]

    /// True when this run writes down where the owner left.
    public static func remembers(arguments: [String]) -> Bool { !arguments.contains("-sampleData") }

    /// True when this run brings back what was written down.
    public static func bringsBack(arguments: [String]) -> Bool { sceneWords.isDisjoint(with: arguments) }

    /// The board to open at the start; nil is the home page. A board that is gone falls back to the home page.
    public static func board(_ remembered: Remembered, onDevice: Set<UUID>, arguments: [String]) -> UUID? {
        guard bringsBack(arguments: arguments), let id = remembered.open, onDevice.contains(id) else { return nil }
        return id
    }

    /// The view a board opens with; nil shows it whole, as a board opens that was never moved.
    public static func view(_ remembered: Remembered, of board: UUID, arguments: [String]) -> LeftView? {
        guard bringsBack(arguments: arguments), let view = remembered.view(of: board),
              view.scale.isFinite, view.x.isFinite, view.y.isFinite, view.scale > 0 else { return nil }
        return view
    }
}

/// The spot a reopened board holds in the middle while its room still settles (a window finding its
/// size, a side bar sliding in). Dropped the moment the owner moves or zooms the board.
public struct ViewPin: Equatable, Sendable {
    var centre: CGPoint
    var offset: CGSize
    var scale: Double
}

public extension Viewport {
    /// What to write down: nil until the owner has moved or zoomed the board (it is then shown whole again).
    var leftView: LeftView? {
        guard movedByOwner, size.width > 10, size.height > 10 else { return nil }
        let middle = toBoard(CGPoint(x: size.width / 2, y: size.height / 2))
        return LeftView(scale: (scale * 1000).rounded() / 1000,
                        x: (Double(middle.x) * 10).rounded() / 10,
                        y: (Double(middle.y) * 10).rounded() / 10)
    }

    /// The board comes back as it was left: the same zoom, the same spot in the middle. The room may
    /// not be known yet, or may still change: the spot is held until the owner moves the board.
    mutating func comeBack(to left: LeftView) {
        // Counts as moved by the owner (it was, last time), so the board is not shown whole instead.
        zoom(to: left.scale)
        pin = ViewPin(centre: CGPoint(x: left.x, y: left.y), offset: offset, scale: scale)
        holdPin()
    }

    /// Puts the held spot back in the middle of the room. False when nothing is held (any more).
    @discardableResult
    mutating func holdPin() -> Bool {
        guard let held = pin else { return false }
        // The owner slid or zoomed since: the board stays where he put it.
        guard held.scale == scale, held.offset == offset else {
            pin = nil
            return false
        }
        guard size.width > 10, size.height > 10 else { return true }
        offset = CGSize(width: Double(size.width) / 2 - Double(held.centre.x) * scale,
                        height: Double(size.height) / 2 - Double(held.centre.y) * scale)
        pin?.offset = offset
        return true
    }
}
