import SwiftUI

/// One press on the board, from landing to lifting: a click and drag on the Mac; a finger, a Pencil
/// or a pointer on iPhone and iPad (TouchLayer.swift). The board's choose / move code reads only this.
struct Press {
    enum Kind { case finger, pencil, pointer }

    /// Where the press landed, and where it is now, in the board view's own points.
    var startLocation: CGPoint
    var location: CGPoint
    /// The way from the landing to now.
    var translation: CGSize
    var time: Date
    var kind: Kind = .pointer
    /// Shift is held (a keyboard with the pointer).
    var shift = false

    /// A mouse or a trackpad.
    var pointer: Bool { kind == .pointer }
    /// A pointer or a Pencil points exactly; a finger does not.
    var precise: Bool { kind != .finger }
}

extension Press {
    /// The Mac's click and drag.
    init(_ value: DragGesture.Value) {
        self.init(startLocation: value.startLocation, location: value.location, translation: value.translation, time: value.time)
    }
}

/// How a press on iPhone and iPad goes on.
enum PressPhase {
    case began, moved, ended
    /// The press was taken away. `takeBack`: by a second finger landing or the page's own edge swipe —
    /// a small shove is then taken back. Otherwise (a call, leaving the app) things stay as they stand.
    case lost(takeBack: Bool)
}

/// What the board remembers about the press that is going on (iPhone and iPad).
struct PressNotes {
    var shift = false
    var precise = false
    /// What was chosen before the press landed: a press that turns into two fingers chooses nothing.
    var selection: Set<UUID> = []
    var link: UUID?
}
