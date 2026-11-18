import SwiftUI
import SeedboardCore
#if os(iOS)
import UIKit
#endif

// 0.5, iPhone and iPad: three fingers swiped left (undo) or right (redo) and a shake reach the open board
// through the window's `UndoManager`. The rule — ONE undo path, the board's own steps stay the truth — is
// `SystemUndo` in SeedboardCore. Here: the window's manager is told after every change of the board's steps.
// The Mac keeps its Edit menu as it is (it calls the board's own undo and redo directly).

/// On the window (SeedboardApp.swift). Does nothing on the Mac.
struct SystemUndoHost: ViewModifier {
    @ObservedObject var model: AppModel
    @Environment(\.undoManager) private var manager

    func body(content: Content) -> some View {
        #if os(iOS)
        content.background {
            if let session = model.session {
                SystemUndoWatch(session: session, manager: manager)
                    .id(ObjectIdentifier(session))
            }
        }
        #else
        content
        #endif
    }
}

#if os(iOS)
/// Watches one board's steps. While words are typed the field has its own undo (the device's gestures go
/// there), and a board that is only read has no steps: then the window's manager is shown nothing.
private struct SystemUndoWatch: View {
    @ObservedObject var session: BoardSession
    let manager: UndoManager?

    private var steps: [Int] {
        session.editing != nil || session.readOnly ? [0, 0] : [session.undoCount, session.redoCount]
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { SystemUndoDesk.shared.show(session, in: manager) }
            .onChange(of: steps) { _, _ in SystemUndoDesk.shared.show(session, in: manager) }
            .onChange(of: manager.map(ObjectIdentifier.init)) { _, _ in SystemUndoDesk.shared.show(session, in: manager) }
            .onDisappear { SystemUndoDesk.shared.left(session) }
    }
}

/// The one link between the open board and the window's `UndoManager`.
@MainActor
final class SystemUndoDesk {
    static let shared = SystemUndoDesk()

    private let link = SystemUndo()
    private weak var session: BoardSession?
    private weak var manager: UndoManager?

    func show(_ session: BoardSession, in manager: UndoManager?) {
        self.session = session
        self.manager = manager
        link.undo = { [weak session] in session?.undo() }
        link.redo = { [weak session] in session?.redo() }
        arrange(tries: 0)
    }

    /// The board was left (back at the list, or another board): the device's Undo has nothing to take back.
    func left(_ session: BoardSession) {
        guard self.session === session || self.session == nil else { return }
        self.session = nil
        link.clear()
    }

    private func arrange(tries: Int) {
        guard let session else { return }
        let quiet = session.editing != nil || session.readOnly
        let done = link.show(canUndo: !quiet && session.undoCount > 0, canRedo: !quiet && session.redoCount > 0, in: manager)
        // In the middle of the device's own undo nothing may be touched: once more, a moment later.
        if !done, tries < 5 {
            DispatchQueue.main.async { [weak self] in self?.arrange(tries: tries + 1) }
        }
    }
}

/// The board rests while a third finger is down and for 0.3 s after (the rule is `ThirdFinger` in SeedboardCore).
/// Kept by the touch layer, which counts the fingers.
struct ThirdFingerRest {
    private var rule = ThirdFinger()

    mutating func landed(fingersAlreadyDown: Int) { rule.landed(fingersAlreadyDown: fingersAlreadyDown) }

    mutating func slides(fingersDown: Int) -> Bool {
        rule.slides(fingersDown: fingersDown, now: ProcessInfo.processInfo.systemUptime)
    }
}

extension TouchSurface {
    /// One of the device's own gestures that needs three fingers or more (three fingers swiped left or right:
    /// undo and redo; three fingers tapped: the small edit menu). It is let through beside the board's own
    /// press and never has to wait for it; with one or two fingers the board is alone, as before.
    static func isDevicesOwn(_ other: UIGestureRecognizer) -> Bool {
        let fingers: Int
        if let pan = other as? UIPanGestureRecognizer {
            fingers = pan.minimumNumberOfTouches
        } else if let tap = other as? UITapGestureRecognizer {
            fingers = tap.numberOfTouchesRequired
        } else if let swipe = other as? UISwipeGestureRecognizer {
            fingers = swipe.numberOfTouchesRequired
        } else if let long = other as? UILongPressGestureRecognizer {
            fingers = long.numberOfTouchesRequired
        } else {
            return false
        }
        return Fingers.isDevicesGesture(fingersNeeded: fingers)
    }

}
#endif
