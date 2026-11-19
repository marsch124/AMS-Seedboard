import SwiftUI
import SeedboardCore

// Seedboard 0.15: a board locked with Face ID closes when the app goes to the background,
// so coming back asks again before its things are seen.

@MainActor
enum LockLeave {
    /// The name of the locked board that was closed while the owner was away, said once on return.
    static var closed: String?
}

extension AppModel {
    /// The app went to the background: an open locked board is closed (its work is kept).
    func closeLockedOnLeave() {
        guard let session, let id = openID, session.board.id == id,
              let board = boards.first(where: { $0.id == id }), board.faceLock == true else { return }
        LockLeave.closed = board.title
        openNow(nil)
    }

    /// The app is back: says once which locked board was closed.
    func tellClosedLocked() {
        guard let title = LockLeave.closed else { return }
        LockLeave.closed = nil
        say("“\(title)” was closed while you were away. Opening it asks for \(FaceGuard.word) again.")
    }
}
