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
        Button("Unfold All") { session?.unfoldAll(); session?.takeKeys() }
            .disabled(!canChange || session?.board.hasFolded != true)
        Button(session?.board.numberSteps == true ? "Stop Numbering the Steps" : "Number the Steps") {
            session?.toggleNumberSteps()
            session?.takeKeys()
        }
        .disabled(!canChange)
    }
}
