import SwiftUI
import SeedboardCore

// Seedboard 0.16: one question, asked once per device, turns purple milestones (made before 0.15) orange.
// Purple means PARAGON in this app. Rules in SeedboardCore (Orange16.swift).

struct OrangeFound: Equatable {
    var milestones: Int
    var timelines: Int
}

@MainActor
final class OrangeDesk: ObservableObject {
    static let shared = OrangeDesk()
    @Published var found: OrangeFound?
    /// 0.17: purple main branches of mind maps (asked after the milestones, never both at once).
    @Published var branches: OrangeFound?
}

extension AppModel {
    /// After loading: asks once, when any timeline still has purple milestones.
    func askOrangeOnce() {
        let keep = UserDefaults.standard
        guard loaded, !keep.bool(forKey: OrangeMilestones.askedKey), OrangeDesk.shared.found == nil else { askBranchesOnce(); return }
        let n = OrangeMilestones.count(boards)
        guard n.milestones > 0 else { askBranchesOnce(); return }
        keep.set(true, forKey: OrangeMilestones.askedKey)
        OrangeDesk.shared.found = OrangeFound(milestones: n.milestones, timelines: n.timelines)
    }

    /// "Make Orange": every purple milestone on every timeline that can be changed.
    func makeMilestonesOrange() {
        var turned = 0
        for board in boards where board.isTimeline && board.canBeChanged && board.purpleMilestones > 0 {
            turned += board.purpleMilestones
            edit(board.id) { $0.makeMilestonesOrange() }
        }
        guard turned > 0 else { return }
        say(turned == 1 ? "1 milestone is orange now." : "\(turned) milestones are orange now.")
    }

    /// 0.17: asks once, when any mind map still has purple main branches.
    func askBranchesOnce() {
        let keep = UserDefaults.standard
        guard loaded, !keep.bool(forKey: PurpleBranches.askedKey), OrangeDesk.shared.found == nil, OrangeDesk.shared.branches == nil else { return }
        let n = PurpleBranches.count(boards)
        guard n.branches > 0 else { return }
        keep.set(true, forKey: PurpleBranches.askedKey)
        OrangeDesk.shared.branches = OrangeFound(milestones: n.branches, timelines: n.maps)
    }

    /// "New Colours": every purple main branch on every board that can be changed.
    func recolourPurpleBranches() {
        var turned = 0
        for board in boards where board.canBeChanged && board.purpleBranches > 0 {
            turned += board.purpleBranches
            edit(board.id) { $0.recolourPurpleBranches() }
        }
        guard turned > 0 else { return }
        say(turned == 1 ? "1 branch has a new colour." : "\(turned) branches have a new colour.")
    }
}

/// The question itself. Attached to the window (RootView).
struct OrangeHost: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var desk = OrangeDesk.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: model.loaded, initial: true) { _, now in if now { model.askOrangeOnce() } }
            .alert("Make purple milestones orange?",
                   isPresented: Binding(get: { desk.found != nil }, set: { if !$0 { desk.found = nil } }),
                   presenting: desk.found) { _ in
                Button("Make Orange") { model.makeMilestonesOrange() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("orange.make")
                Button("Keep Purple", role: .cancel) {}
                    .accessibilityIdentifier("orange.keep")
            } message: { found in
                Text(OrangeMilestones.line((found.milestones, found.timelines)))
            }
            // The milestone question is gone: now the branches may ask (0.17).
            .onChange(of: desk.found == nil) { _, gone in if gone { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.askBranchesOnce() } } }
            .alert("Recolour purple branches?",
                   isPresented: Binding(get: { desk.branches != nil }, set: { if !$0 { desk.branches = nil } }),
                   presenting: desk.branches) { _ in
                Button("New Colours") { model.recolourPurpleBranches() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("branches.recolour")
                Button("Keep Purple", role: .cancel) {}
                    .accessibilityIdentifier("branches.keep")
            } message: { found in
                Text(PurpleBranches.line((found.milestones, found.timelines)))
            }
    }
}

extension View {
    func orangeHost() -> some View { modifier(OrangeHost()) }
}
