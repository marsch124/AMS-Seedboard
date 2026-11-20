import SwiftUI
import SeedboardCore

// 0.9 (lane "maps"): Mac menu lines for mind maps and flowcharts — Balance the Map, Fold Branch / Unfold Branch,
// Unfold All, Number the Steps. They sit in the Board menu after the idea-order lines. No new keys.

struct MapCommands: View {
    @FocusedObject private var session: BoardSession?

    private var canChange: Bool { session.map { !$0.readOnly && !$0.board.placesItself && $0.editing == nil } ?? false }
    private var chosenIdea: Item? { session?.single.flatMap { $0.kind == .idea ? $0 : nil } }

    var body: some View {
        Divider()
        Button("Balance the Map") { session?.balanceMap(); session?.takeKeys() }
            .disabled(!canChange || chosenIdea.map { !(session?.board.canBalance($0.id) ?? false) } ?? true)
        Button(chosenIdea?.folded == true ? "Unfold Branch" : "Fold Branch") { session?.toggleFold(); session?.takeKeys() }
            .disabled(!canChange || chosenIdea.map { (session?.facts.children[$0.id] ?? 0) == 0 } ?? true)
        // 0.11: the whole map at once, to its main branches and back.
        Button(chosenIdea.map { session?.board.showsMainBranchesOnly(session?.board.centre(of: $0.id) ?? $0.id) } == true ? "Open All Branches" : "Main Branches Only") {
            if let idea = chosenIdea, let session { session.toggleMainBranches(session.board.centre(of: idea.id)) }
            session?.takeKeys()
        }
        .disabled(!canChange || chosenIdea.map { !(session?.board.canFoldToMainBranches(session?.board.centre(of: $0.id) ?? $0.id) ?? false) } ?? true)
        Button("Unfold All") { session?.unfoldAll(); session?.takeKeys() }
            .disabled(!canChange || session?.board.hasFolded != true)
        Button(session?.board.numberSteps == true ? "Stop Numbering the Steps" : "Number the Steps") {
            session?.toggleNumberSteps()
            session?.takeKeys()
        }
        .disabled(!canChange)
        // 0.19: numbered branches, the look of a map, a branch to the other side, ideas grown from an idea.
        Button(session?.board.numberBranches == true ? "Stop Numbering the Branches" : "Number the Branches") {
            session?.toggleNumberBranches()
            session?.takeKeys()
        }
        .disabled(!canChange)
        Menu("Map Look") {
            ForEach(MapLook.allCases, id: \.self) { look in
                Button((session?.board.look == look ? "✓ " : "") + look.word) { session?.setMapLook(look); session?.takeKeys() }
            }
        }
        .disabled(!canChange)
        Button("Move to the Other Side") { session?.moveToOtherSide(); session?.takeKeys() }
            .disabled(!canChange || chosenIdea.map { !(session?.board.canMoveToOtherSide($0.id) ?? false) } ?? true)
        Button("Grow Ideas from This") { if let idea = chosenIdea { session?.growIdeas(from: idea.id) } }
            .disabled(!canChange || chosenIdea.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? true)
        Button("Straighten the Arrow") { session?.straightenLink(); session?.takeKeys() }
            .disabled(session.map { $0.readOnly || $0.selectedLink == nil || $0.board.arrow($0.selectedLink!)?.isBent != true } ?? true)
    }
}
