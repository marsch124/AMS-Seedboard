import SwiftUI
import Combine
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 18: a timeline opens at the scale and place it was left. Kept in THIS device's own settings
// (never in the board, never synced). The rule is in SeedboardCore (`TimelineLeft`, TimelinePlan.swift).
// With `-sampleData` nothing is written down; with any launch word that sets the scene nothing is brought back.

@MainActor
final class TimelineKeep {
    static let shared = TimelineKeep()

    private static let key = "seedboard.timelineViews"
    private var views = TimelineKeep.read()
    private weak var session: BoardSession?
    private var watch: AnyCancellable?
    private var leaving: [NSObjectProtocol] = []

    private static func read() -> TimelineViews {
        guard let data = UserDefaults.standard.data(forKey: key),
              let found = try? JSONDecoder().decode(TimelineViews.self, from: data) else { return TimelineViews() }
        return found
    }

    private var remembers: Bool { Reopen.remembers(arguments: LaunchOptions.arguments) }

    /// A timeline is on screen and its room is known (`TimelineView.place`). The first time for this opening,
    /// its view comes back; from then on the view is written down a moment after the owner stops moving it.
    func opened(_ new: BoardSession) {
        guard new !== session, new.board.isTimeline, new.viewSize.width > 10 else { return }
        write()
        session = new
        watch = nil
        if Reopen.bringsBack(arguments: LaunchOptions.arguments) {
            if let left = views.view(of: new.board.id), let back = TimelineGeometry.comeBack(to: left) {
                new.timelineComeBack(scale: back.scale, slide: back.slide)
            } else if new.place.movedByOwner {
                // Nothing of this timeline is written down here: it is shown whole, as a timeline opens.
                new.timelineFit(opening: true)
            }
        }
        guard remembers else { return }
        watch = new.$place
            .dropFirst()
            .debounce(for: .seconds(0.6), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.write() }
        guard leaving.isEmpty else { return }
        #if os(macOS)
        let names = [NSApplication.willResignActiveNotification, NSApplication.willTerminateNotification]
        #else
        let names = [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification]
        #endif
        leaving = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.write() }
            }
        }
    }

    /// Writes down the view of the timeline that is open, as it stands now.
    private func write() {
        guard remembers, let session, session.board.isTimeline, session.viewSize.width > 10 else { return }
        let before = views
        if session.place.movedByOwner {
            views.note(session.timelineGeometry.left, of: session.board.id)
        } else {
            // Shown whole (never moved, or "Show the whole timeline" was the last thing): it opens whole again.
            views.forget(session.board.id)
        }
        guard views != before, let data = try? JSONEncoder().encode(views) else { return }
        UserDefaults.standard.set(data, forKey: TimelineKeep.key)
    }
}

extension BoardSession {
    /// The timeline stands again as it was left: the same scale, the same day beside the names, the same rows.
    func timelineComeBack(scale: TimeScale, slide: CGSize) {
        timeline.scale = scale
        timeline.pinch = 1
        offset = slide
        // A step of zero: it counts as moved by its owner (it was, last time), and the rows are kept in their room.
        pan(by: .zero)
    }
}
