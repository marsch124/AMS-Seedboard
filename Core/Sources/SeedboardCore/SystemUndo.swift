import Foundation

// 0.5, iPhone and iPad: the device's own Undo — three fingers swiped left (undo) or right (redo), and a shake —
// reaches the board through the window's `UndoManager`.
//
// ONE undo path. The board's own steps (up to 120, `BoardSession`) stay the truth. The window's manager never
// holds a copy of them: it only ever holds ONE "undo" and ONE "redo", and each does nothing but call the
// board's own undo or redo. A press on the Undo button or ⌘Z goes straight to the board and never through
// the manager; the device's gesture comes through the manager and never through the button. So one press or
// one swipe takes back exactly one step.

/// Shows the window's `UndoManager` what the board can do right now, and passes its undo and redo on to the board.
@MainActor
public final class SystemUndo {
    /// The board's own undo and redo.
    public var undo: () -> Void = {}
    public var redo: () -> Void = {}

    private weak var manager: UndoManager?
    /// While the two entries are being put in place nothing may reach the board.
    private var arranging = false

    public init() {}

    /// Puts into `manager` exactly what the board can do: an undo when `canUndo`, a redo when `canRedo`.
    /// Called after every change of the board's steps. False: the manager is in the middle of its own undo or
    /// redo, or of an event's group — nothing was touched, ask again a moment later.
    @discardableResult
    public func show(canUndo: Bool, canRedo: Bool, in manager: UndoManager?) -> Bool {
        if let old = self.manager, old !== manager {
            if old.isUndoing || old.isRedoing { return false }
            old.removeAllActions(withTarget: self)
        }
        self.manager = manager
        guard let manager else { return true }
        guard !manager.isUndoing, !manager.isRedoing else { return false }
        // A group is open (something else was registered in this very event): not now. The manager closes it
        // by itself at the end of the event, and must be left to do so.
        guard manager.groupingLevel == 0 else { return false }
        arranging = true
        // The two entries are grouped here by hand, each in a group of its own: the manager's own grouping
        // (one group per event) would put them into ONE group and undo both at once.
        let byEvent = manager.groupsByEvent
        manager.groupsByEvent = false
        defer {
            manager.groupsByEvent = byEvent
            arranging = false
        }
        manager.removeAllActions(withTarget: self)
        if canUndo {
            manager.beginUndoGrouping()
            register(redo: false)
            manager.endUndoGrouping()
        }
        if canRedo {
            // A redo can only be left behind by an undo: this entry does nothing but that.
            manager.beginUndoGrouping()
            manager.registerUndo(withTarget: self) { me in me.register(redo: true) }
            manager.endUndoGrouping()
            manager.undo()
        }
        return true
    }

    /// The board is gone (back at the list): the device's Undo has nothing to take back.
    public func clear() {
        guard let manager, !manager.isUndoing, !manager.isRedoing else { return }
        manager.removeAllActions(withTarget: self)
    }

    /// One entry. Run by the manager, it leaves its counterpart behind, as the manager expects of every entry
    /// (a redo that left nothing behind would leave the manager believing there is still something to undo).
    private func register(redo again: Bool) {
        manager?.registerUndo(withTarget: self) { me in
            me.register(redo: !again)
            me.fire(redo: again)
        }
    }

    private func fire(redo again: Bool) {
        guard !arranging else { return }
        if again { redo() } else { undo() }
    }
}

public extension Fingers {
    /// The device's own editing gestures need three fingers (swipe left: undo, right: redo). A gesture of the
    /// device that needs three fingers or more is let through beside the board's own press; one or two fingers
    /// stay the board's alone.
    static func isDevicesGesture(fingersNeeded: Int) -> Bool { fingersNeeded >= 3 }

}

/// Two fingers slide and zoom the board. A third finger means the device's own gesture (three fingers swipe for
/// Undo): the board rests while it is down AND for 0.3 s after it lifted — the two fingers left over at the end
/// of a swipe must not shove the board. After that two fingers slide again, without a jump. A new touch on an
/// empty board starts afresh.
public struct ThirdFinger: Sendable {
    /// How long the board still rests after the third finger lifted, in seconds.
    public static let rest: Double = 0.3

    private var down = false
    private var lifted: Double?

    public init() {}

    /// A finger landed; `fingersAlreadyDown`: how many were on the board before it.
    public mutating func landed(fingersAlreadyDown: Int) {
        if fingersAlreadyDown == 0 {
            down = false
            lifted = nil
        } else if fingersAlreadyDown >= 2 {
            down = true
            lifted = nil
        }
    }

    /// May two fingers slide the board now? `now`: any clock that counts seconds.
    public mutating func slides(fingersDown: Int, now: Double) -> Bool {
        if fingersDown > 2 {
            down = true
            lifted = nil
            return false
        }
        if down {
            down = false
            lifted = now
        }
        guard let since = lifted else { return true }
        guard now - since >= ThirdFinger.rest else { return false }
        lifted = nil
        return true
    }
}
