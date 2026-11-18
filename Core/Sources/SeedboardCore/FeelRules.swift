import Foundation
import CoreGraphics

// 0.5 (the feel lane): the small rules of what the hand feels, how a button answers, how Send is handed
// over and how an empty board invites — as plain functions, so each has its data test (Feel05Tests.swift).

public enum FeelRules {
    // MARK: What the hand feels

    /// A guide line "catches" at most once in this many seconds.
    public static let catchGap = 0.12

    /// A catch may be felt now: the last one is at least `catchGap` ago.
    public static func mayCatch(last: Date, now: Date) -> Bool {
        now.timeIntervalSince(last) >= catchGap
    }

    /// A guide line appeared while dragging or sizing: there are more guides than a moment ago.
    /// (A guide that only grows longer, or one that goes, is not felt.)
    public static func guideAppeared(before: Int, now: Int) -> Bool { now > before }

    /// The smallest and the largest zoom of a board (the same two ends `Viewport` keeps to).
    public static let zoomLeast = 0.2
    public static let zoomMost = 3.0

    /// What a pinch feels on its way from one zoom to the next.
    public enum ZoomMoment: Equatable, Sendable {
        /// The pinch passed life size (100 %).
        case lifeSize
        /// The pinch reached the smallest or the largest zoom.
        case theEnd
    }

    /// The moment one step of a pinch passes. The end is felt once: a pinch that pushes on at the end feels
    /// nothing more. Life size is felt when the step crosses 100 % or lands on it, from either side.
    public static func zoomMoment(from old: Double, to new: Double) -> ZoomMoment? {
        guard old != new else { return nil }
        let atEnd: (Double) -> Bool = { $0 <= zoomLeast || $0 >= zoomMost }
        if atEnd(new) { return atEnd(old) ? nil : .theEnd }
        if (old < 1 && new >= 1) || (old > 1 && new <= 1) { return .lifeSize }
        return nil
    }

    /// A dragged idea was let go: it is felt when it found a new place in a map (under another idea, or
    /// between two sisters) — not when it sprang back or was torn off.
    public static func ideaSetDown(hangs: Bool, lands: Bool) -> Bool { hangs || lands }

    /// An arrow's end was let go: it is felt when the end landed on a shape it was not on before.
    public static func arrowJoined(before: UUID?, after: UUID?) -> Bool { after != nil && after != before }

    // MARK: How a button answers

    /// A tile or a bar button shrinks to this while pressed; the full-colour main button and a card to `mainPressed`.
    public static let tilePressed = 0.95
    public static let mainPressed = 0.97
    /// The full-colour main button is this much darker while pressed — and stays solid.
    public static let mainDarker = 0.12

    /// A colour made darker by a share (0.12 = 12 % darker). It never becomes see-through.
    public static func darker(_ rgb: (red: Double, green: Double, blue: Double), by share: Double) -> (red: Double, green: Double, blue: Double) {
        let keep = 1 - min(max(share, 0), 1)
        return (rgb.red * keep, rgb.green * keep, rgb.blue * keep)
    }

    /// How strongly a tile's own colour is laid over its soft plate: nothing at rest, one step with the
    /// pointer over it, and while pressed as much again as the plate's own tint — the tint doubles.
    /// (A soft plate is the part's colour at 6 % by day and 12 % by night.)
    public static func tintStrength(pressed: Bool, over: Bool, enabled: Bool = true, night: Bool) -> Double {
        guard enabled else { return 0 }
        let whole = night ? 0.136 : 0.064
        if pressed { return whole }
        return over ? whole / 2 : 0
    }

    // MARK: Send, the hand-over

    /// How long the white tick stands on the Send button before the page closes.
    public static let sendTick = 0.45
    /// How long the line about what went to PARAGON stays (other lines: 4 s).
    public static let sendLine = 6.0

    /// The line after Send carries "Open" when a note was made. "Only the to-do boxes" makes no note.
    public static func sendOffersOpen(madeNote: Bool) -> Bool { madeNote }

    // MARK: The empty board and the first start

    /// The three ways to begin that an empty board offers, in their order.
    public enum Start: String, CaseIterable, Sendable {
        case mindMap, note, paste

        public var word: String {
            switch self {
            case .mindMap: return "Mind map"
            case .note: return "Sticky note"
            case .paste: return "Paste a list"
            }
        }

        /// The identifier of its button.
        public var id: String {
            switch self {
            case .mindMap: return "empty.mindmap"
            case .note: return "empty.note"
            case .paste: return "empty.paste"
            }
        }
    }

    /// What an empty board shows in its middle.
    public enum Invitation: Equatable, Sendable {
        /// Nothing: the board holds something, or it places its own things (a timeline, "Who does what").
        case none
        /// The sprout and one line only: the board cannot be changed on this device.
        case words
        /// The sprout, "What is on your mind?" and the three starting buttons.
        case starts
    }

    /// `drawing`: the Draw tool is on — the board is left clear for the Pencil or the finger.
    public static func invitation(empty: Bool, placesItself: Bool, readOnly: Bool, drawing: Bool = false) -> Invitation {
        guard empty, !placesItself, !drawing else { return .none }
        return readOnly ? .words : .starts
    }

    /// "Paste a list" is pale while nothing that can be read as words is copied. It can still be pressed
    /// (the app then says "Nothing to paste.").
    public static func startIsPale(_ start: Start, wordsCopied: Bool) -> Bool { start == .paste && !wordsCopied }

    /// The iPhone's list with no board in it shows the starters themselves instead of a grey line.
    /// The Mac and the iPad have the home page for that.
    public static func showsFirstSeeds(loaded: Bool, boards: Int, phone: Bool) -> Bool { loaded && boards == 0 && phone }
}

public extension Board {
    /// What this board shows in its middle while nothing is on it.
    func invitation(readOnly: Bool, drawing: Bool = false) -> FeelRules.Invitation {
        FeelRules.invitation(empty: isEmpty, placesItself: placesItself, readOnly: readOnly, drawing: drawing)
    }
}
