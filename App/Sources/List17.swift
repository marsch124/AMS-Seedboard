import SwiftUI
import SeedboardCore
import AMSIcons

// Seedboard 0.17 — the list as coloured cards (his pick "2 Coloured cards", 20 Nov 2026).
// iPhone and iPad: a big green "Seedboard" with a count line, the gear alone at the top right, every part on a
// soft card in its own colour whose heading folds it. The Mac keeps its plain headings; they fold too.

/// Which parts of the list are folded, kept per device.
enum ListFold {
    static func key(_ part: String) -> String { "fold.list.\(part)" }
}

/// The list's own big heading (iPhone and iPad): "Seedboard" in the app's green, and a count line under it.
struct ListTitle: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Seedboard")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Part.boards.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("boards.title")
            if model.loaded && !model.boards.isEmpty {
                Text(ListTitle.line(boards: model.pinned.count + model.recent.count + model.sent.count,
                                    pinned: model.pinned.count, sent: model.sent.count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("boards.countLine")
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "14 boards · 2 pinned · 4 in PARAGON" — the parts with nothing in them are left out.
    static func line(boards: Int, pinned: Int, sent: Int) -> String {
        var parts = [boards == 1 ? "1 board" : "\(boards) boards"]
        if pinned > 0 { parts.append("\(pinned) pinned") }
        if sent > 0 { parts.append("\(sent) in PARAGON") }
        // Each part stays whole on a narrow iPad list: it breaks only between the parts.
        return parts.map { $0.replacingOccurrences(of: " ", with: "\u{00A0}") }.joined(separator: " · ")
    }
}

/// The gear alone, for the top right of the list (everyone knows it means Settings).
struct ListGear: View {
    let press: () -> Void
    var body: some View {
        Button(action: press) {
            ControlMarkView(.settings, size: 22, colour: Part.boards.text)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("boards.settings")
    }
}

/// The round arrow on a card's heading: down while open, right while folded.
struct FoldArrow: View {
    let folded: Bool
    let part: Part
    /// The Mac's plain heading: the arrow alone, no round.
    var round = true
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 3, y: 5)); p.addLine(to: CGPoint(x: 7, y: 9)); p.addLine(to: CGPoint(x: 11, y: 5))
        }
        .stroke(part.text, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: 14, height: 14)
        .rotationEffect(.degrees(folded ? -90 : 0))
        .frame(width: 24, height: 24)
        .background(round ? part.text.opacity(0.15) : Color.clear, in: Circle())
    }
}

/// One part of the list on its own soft card. Its heading (words, count, arrow) folds and unfolds it.
struct ListCard<Content: View>: View {
    let title: String
    let key: String
    let count: Int
    var part: Part = .boards
    /// While searching everything is open: the folds stay as they were for afterwards.
    var forceOpen = false
    /// The Mac: plain heading, no card.
    var plain = false
    @ViewBuilder let content: () -> Content
    @AppStorage private var folded: Bool

    init(title: String, key: String, count: Int, part: Part = .boards, forceOpen: Bool = false, plain: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.key = key; self.count = count; self.part = part
        self.forceOpen = forceOpen; self.plain = plain; self.content = content
        _folded = AppStorage(wrappedValue: false, ListFold.key(key))
    }

    private var shut: Bool { folded && !forceOpen }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { folded.toggle() }
            } label: {
                HStack(spacing: 7) {
                    Text(title.uppercased())
                        .font(.caption.weight(.bold))
                        .kerning(0.5)
                        .foregroundStyle(part.text)
                    if !plain {
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(part.fill, in: Capsule())
                    } else if shut {
                        Text("\(count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    FoldArrow(folded: shut, part: part, round: !plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, plain ? 10 : 7)
                .padding(.bottom, shut ? (plain ? 2 : 7) : 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("\(title), \(count). \(shut ? "Folded" : "Open")")
            .accessibilityHint(shut ? "Press to unfold" : "Press to fold")
            .accessibilityIdentifier("boards.fold.\(key)")
            if !shut {
                content()
                    .padding(.bottom, plain ? 0 : 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
        .background {
            if !plain { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(part.text.opacity(0.10)) }
        }
        .padding(.top, plain ? 0 : 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("boards.card.\(key)")
    }
}

/// The iPhone list's Starters: one strip of small cards that slides sideways.
struct ListStarters: View {
    @EnvironmentObject private var model: AppModel
    let open: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(model.shelf.strip) { starter in
                    StarterStripCard(starter: starter, pick: { open(model.newBoard(from: starter)) }, ask: { model.ask($0) }, width: 104)
                        .accessibilityIdentifier("boards.starter.\(starter.id)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
    }
}
