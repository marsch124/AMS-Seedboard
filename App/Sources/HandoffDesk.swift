import SwiftUI
import Combine
import CoreSpotlight
import SeedboardCore

// 0.5 (pick 28): Handoff. A board that is open on one device offers itself on the others — the Mac shows
// Seedboard's icon at the end of the Dock, the iPad in its Dock, the iPhone in the app switcher. Taking it
// up opens the same board at the same zoom and place. The rules are `Handoff` in SeedboardCore.

/// On the open board: the offer the other devices see. It says which board, when it was last changed here,
/// and where the view stands (written a moment after the owner stops moving it, not while he moves it).
struct BoardHandoff: ViewModifier {
    let session: BoardSession
    let id: UUID
    let title: String
    let changed: Date
    /// Not for sample boards, not for a starter's working copy, and not while this board itself still
    /// waits for its newest version.
    let offered: Bool
    @State private var view: LeftView?

    init(session: BoardSession) {
        self.session = session
        id = session.board.id
        title = session.board.title
        changed = session.board.changed
        offered = !LaunchOptions.sampleData && !session.starterDraft && HandoffDesk.shared.waiting != session.board.id
    }

    func body(content: Content) -> some View {
        let offer = Handoff.Offer(id: id, changed: changed, view: session.board.placesItself ? nil : view)
        return content
            .userActivity(Handoff.activityType, isActive: offered) { activity in
                activity.title = title
                activity.isEligibleForHandoff = true
                // The device's search has its own entry for the board (Spotlight.swift): never a second one.
                activity.isEligibleForSearch = false
                activity.targetContentIdentifier = "seedboard://board/\(id.uuidString)"
                let about = CSSearchableItemAttributeSet(contentType: .content)
                about.relatedUniqueIdentifier = id.uuidString
                activity.contentAttributeSet = about
                let info = Handoff.info(for: offer)
                activity.userInfo = info
                activity.requiredUserInfoKeys = ["id"]
            }
            .task(id: id) {
                view = session.place.leftView
                for await place in session.$place.debounce(for: .seconds(0.6), scheduler: DispatchQueue.main).values {
                    let now = place.leftView
                    if now != view { view = now }
                }
            }
    }
}

/// Takes an offer up. Handoff can be faster than iCloud: when this device's copy of the board is older than
/// the one that was offered, the board is shown but cannot be changed, with "Waiting for the newest version
/// from iCloud…", until that version is here — at most 20 seconds, then it opens with what is here.
@MainActor
final class HandoffDesk: ObservableObject {
    static let shared = HandoffDesk()

    /// The board that waits for its newest version; nil when none does.
    @Published private(set) var waiting: UUID?
    private var wanted: Date?
    private var began = Date()
    private var watch: AnyCancellable?
    private var leave: AnyCancellable?
    private var clock: DispatchWorkItem?

    func took(_ activity: NSUserActivity, model: AppModel) {
        guard let offer = Handoff.offer(from: activity.userInfo) else { return }
        Task { @MainActor in
            await model.whenLoaded()
            self.follow(offer, model: model)
        }
    }

    func follow(_ offer: Handoff.Offer, model: AppModel) {
        guard let url = URL(string: "seedboard://board/\(offer.id.uuidString)") else { return }
        end()
        // The same way a link to a board is followed: a board that is not on this device (yet) or was
        // removed gets the same answers.
        model.open(url: url)
        guard let board = model.boardNow(offer.id) else { return }
        guard let session = model.session, session.board.id == offer.id else { return }
        // The same zoom and the same spot in the middle as on the other device.
        if let view = offer.view, !board.placesItself { session.comeBack(to: view) }
        guard Handoff.step(here: board.changed, there: offer.changed, waited: 0) == .wait, let there = offer.changed else { return }
        wanted = there
        began = Date()
        waiting = offer.id
        session.commitEdit()
        session.objectWillChange.send()
        // The newest version arrives through the usual way (`AppModel.cloudBrought`); the list shows it.
        watch = model.$boards
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak model] _ in
                guard let self, let model else { return }
                self.look(model)
            }
        // He leaves the board: nothing waits any more.
        leave = model.$openID
            .dropFirst()
            .sink { [weak self] new in if new != self?.waiting { self?.end() } }
        let work = DispatchWorkItem { [weak self, weak model] in
            guard let self, let model else { return }
            self.look(model)
        }
        clock = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Handoff.longestWait, execute: work)
    }

    private func look(_ model: AppModel) {
        guard let id = waiting, let board = model.boardNow(id) else {
            end()
            return
        }
        if Handoff.step(here: board.changed, there: wanted, waited: Date().timeIntervalSince(began)) != .wait { end() }
    }

    /// The wait is over: the board can be changed again.
    private func end() {
        watch = nil
        leave = nil
        clock?.cancel()
        clock = nil
        wanted = nil
        guard waiting != nil else { return }
        waiting = nil
        AppModel.shared.session?.objectWillChange.send()
    }

    #if DEBUG
    /// For pictures: `-handoffWait` shows the open board as it waits for its newest version (20 seconds).
    func tryOut(_ model: AppModel) {
        guard LaunchOptions.arguments.contains("-handoffWait") else { return }
        Task { @MainActor in
            await model.whenLoaded()
            guard let board = model.session?.board else { return }
            self.follow(Handoff.Offer(id: board.id, changed: board.changed.addingTimeInterval(60)), model: model)
        }
    }
    #endif
}
