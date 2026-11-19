import SwiftUI
import SeedboardCore

// 0.11 (pick 12): VoiceOver reaches every thing and arrow of an ordinary board. The drawing stays one picture;
// these invisible elements lie over it in outline order (Core: Access11.swift), each with its sentence and with
// Choose, Edit words and, where the thing can be moved, Move left / right / up / down by 10 points.

struct BoardAccessChildren: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        let things = session.board.spokenThings
        VStack(spacing: 0) {
            ForEach(things, id: \.id) { thing in
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(thing.sentence)
                    .accessibilityAddTraits(isChosen(thing) ? [.isSelected, .isButton] : .isButton)
                    .accessibilityAction(named: "Choose") { choose(thing) }
                    .accessibilityAction(named: "Edit words") { if !session.readOnly && thing.canEdit { session.beginEdit(thing.id) } }
                    .accessibilityAction(named: "Move left") { move(thing, .left) }
                    .accessibilityAction(named: "Move right") { move(thing, .right) }
                    .accessibilityAction(named: "Move up") { move(thing, .up) }
                    .accessibilityAction(named: "Move down") { move(thing, .down) }
            }
        }
    }

    private func isChosen(_ thing: SpokenThing) -> Bool {
        thing.isArrow ? session.selectedLink == thing.id : session.selection.contains(thing.id)
    }

    private func choose(_ thing: SpokenThing) {
        if thing.isArrow {
            session.selection = []
            session.selectedLink = thing.id
        } else {
            session.select(thing.id)
        }
    }

    private func move(_ thing: SpokenThing, _ step: Board.Step) {
        guard thing.canMove, !session.readOnly else { return }
        session.select(thing.id)
        session.arrow(step, big: false)
    }
}
