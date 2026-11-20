import SwiftUI
import SeedboardCore
import AMSIcons

// 0.9, "marks": the lines in the board's More menu, the small legend card in the corner and the page "Colour legend".

/// More ▸ Sort by dots, Clear all dots, Colour legend…, Hide legend, Background.
struct MarksMoreLines: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        Divider()
        Button("Sort by dots") { session.sortByDots(); session.takeKeys() }
            .disabled(!session.marksOn || session.board.sortableByDots().count < 2)
            .accessibilityIdentifier("more.sortDots")
        Button("Clear all dots") { session.clearAllDots(); session.takeKeys() }
            .disabled(!session.marksOn || !session.board.hasDots)
            .accessibilityIdentifier("more.clearDots")
        Button {
            session.commitEdit()
            MarksDesk.shared.legendOpen = true
        } label: { MarkLabel("Colour legend…", .legend) }
        .disabled(!session.marksOn)
        .accessibilityIdentifier("more.legend")
        if session.board.legend != nil {
            Button("Hide legend") { session.setLegend([:]); session.takeKeys() }
                .disabled(!session.marksOn)
                .accessibilityIdentifier("more.hideLegend")
        }
        Menu("Background") {
            Picker("Background", selection: Binding(get: { session.board.backdropKind }, set: { session.setBackdrop($0); session.takeKeys() })) {
                ForEach(Backdrop.allCases, id: \.self) { Text($0.word).tag($0) }
            }
            .pickerStyle(.inline)
            .disabled(!session.marksOn)
        }
        .accessibilityIdentifier("more.background")
        // 0.19 (18): the paper colour, with Plain, Paper, Warm grey and Night blue (Canvas19.swift).
        Button("Background colour…") { session.commitEdit(); BackdropColourDesk.shared.show = true }
            .disabled(!session.marksOn)
            .accessibilityIdentifier("more.paper")
    }
}

/// A small card at the bottom left, above the tools: each colour that has words, a dot and the words. A press opens the page.
struct LegendCardRow: View {
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        let rows = session.board.placesItself ? [] : session.board.legendRows
        if !rows.isEmpty {
            HStack(spacing: 0) {
                Button {
                    guard session.marksOn else { return }
                    session.commitEdit()
                    MarksDesk.shared.legendOpen = true
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                    GlyphView(glyph: .new(.legend), size: 14, colour: Color.primary.opacity(0.7))
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(rows, id: \.colour) { row in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Paint(scheme).note(row.colour))
                                    .overlay(Circle().stroke(Paint(scheme).edge, lineWidth: 1))
                                    .frame(width: 10, height: 10)
                                // 0.11: with "Differentiate Without Colour" the colour's name stands before its words.
                                Text(differentiate ? "\(row.colour.capitalized): \(row.words)" : row.words)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Theme.plate, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.primary.opacity(0.12)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .help("Colour legend")
                .accessibilityIdentifier("legend.card")
                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)
        }
    }
}

/// "Colour legend": the sticky-note colours in use, each with a field for what it means. Cancel and Save.
struct LegendPage: View {
    @ObservedObject var session: BoardSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var words: [String: String] = [:]
    @FocusState private var focus: String?

    private var colours: [String] { session.board.legendColours }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                GlyphView(glyph: .new(.legend), size: 24, colour: Part.notes.text)
                    .accessibilityHidden(true)
                Text("Colour legend")
                    .font(Txt.big)
                    .foregroundStyle(Part.notes.text)
            }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("legend.heading")
                .padding(.top, 12)
            Text(colours.isEmpty ? "There are no sticky notes yet." : "Say what each colour of sticky note means.")
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(colours, id: \.self) { name in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Paint(scheme).note(name))
                                .overlay(Circle().stroke(Paint(scheme).edge, lineWidth: 1))
                                .frame(width: 22, height: 22)
                                .accessibilityHidden(true)
                            TextField("What does \(name) mean?", text: Binding(get: { words[name] ?? "" }, set: { words[name] = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .focused($focus, equals: name)
                                .submitLabel(.done)
                                .accessibilityLabel("What does \(name) mean?")
                                .accessibilityIdentifier("legend.field.\(name)")
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .accessibilityIdentifier("legend.list")
            Divider()
            HStack {
                if session.board.legend != nil {
                    Button("Hide legend", role: .destructive) {
                        session.setLegend([:])
                        dismiss()
                    }
                    .accessibilityIdentifier("legend.hide")
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("legend.cancel")
                Button("Save") {
                    session.setLegend(words)
                    dismiss()
                }
                .buttonStyle(FilledButton(.notes))
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("legend.save")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onAppear {
            words = session.board.legend ?? [:]
            focus = colours.first
        }
        #if os(macOS)
        .frame(width: 400, height: 380)
        #else
        .presentationDetents([.medium, .large])
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legend.page")
    }
}
