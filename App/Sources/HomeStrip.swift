import SwiftUI
import SeedboardCore
import AMSIcons

// 0.5 (pick 7): the home page shows the owner's boards first. The starters are ONE strip that slides sideways
// (HomeView.swift); this is the strip's card.

/// One way to begin, in the strip: the starter's small drawing and its name. 132 wide, no grey line, no second line.
struct StarterStripCard: View {
    let starter: ShelfStarter
    let pick: () -> Void
    let ask: (StarterAsk) -> Void

    static let width: CGFloat = 132
    static let gap: CGFloat = 8

    var body: some View {
        Button(action: pick) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    BoardThumb(starter: starter)
                    if (starter.board ?? starter.builtin.map { Thumbs.board(of: $0) } ?? Board()).isEmpty {
                        // An empty sheet: a quiet plus in the middle says "start from nothing".
                        ControlMarkView(.add, size: 22, colour: Part.boards.text.opacity(0.75))
                    }
                }
                Text(starter.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.top, 3)
                    .padding(.bottom, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: StarterStripCard.width)
            .modifier(CardPlate())
        }
        .buttonStyle(PressStyle())
        .starterMenu(starter, ask: ask)
        .help(starter.hint)
        .accessibilityLabel("\(starter.name). \(starter.hint)")
    }
}
