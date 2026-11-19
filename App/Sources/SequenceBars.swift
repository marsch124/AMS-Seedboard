import SwiftUI
import SeedboardCore
import AMSIcons

// The bars of a "Who does what" board. `BoardView` shows these in place of the ordinary tools and
// selection bar when the board is a sequence; the zoom buttons and everything else are the same.

/// The tools: Who, Message, Note, Section. Each has its word under it.
struct SequenceToolPill: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: 6) {
            tool("Who", .new(.person), .sequence, "tool.who", "Who: a new name at the right end of the row (W)") { session.addWho() }
            tool("Message", .app(.seedArrow), .arrows, "tool.message",
                 "Message: press who it comes from, then who it goes to (M). Or pull from one dashed line to another.", on: session.linking) {
                if session.linking {
                    session.linking = false
                    session.linkFrom = nil
                } else if let item = session.single, item.kind == .message {
                    // With a message chosen: the next one right under it, going the other way.
                    session.addNextMessage(after: item.id)
                } else {
                    // With a name chosen, the message starts there.
                    session.startMessage(from: session.single.flatMap { $0.kind == .who ? $0.id : nil })
                }
            }
            tool("Note", .app(.seedNoteBand), .notes, "tool.note", "Note: a soft band across the lines (N)") { session.addBand() }
            tool("Section", .app(.seedSection), .frames, "tool.section", "Section: a heading line across the diagram (S)") { session.addSection() }
        }
        .padding(6)
        .fixedSize()
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.tools")
    }

    private func tool(_ word: String, _ glyph: Glyph, _ part: Part, _ id: String, _ help: String, on: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            VStack(spacing: 1) {
                GlyphView(glyph: glyph, size: 22, colour: on ? .white : part.text)
                Text(word)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(on ? Color.white : Color.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 7)
            .frame(minWidth: 50)
            .frame(height: 44)
            .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(tint: part.text))
        .help(help)
        .accessibilityLabel(word)
        .accessibilityIdentifier(id)
    }
}

/// What can be done with the chosen message, name, note or section.
/// It stands at the bottom, above the tools: at the top it would cover the names.
struct SequenceSelectionBar: View {
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @State private var showColours = false

    var body: some View {
        if session.readOnly || session.selection.isEmpty {
            EmptyView()
        } else {
            let item = session.single
            VStack(spacing: 5) {
                WrapRow(spacing: 5) {
                    if let item {
                        chips(for: item)
                    } else {
                        Text("\(session.selection.count) chosen")
                            .font(Txt.pill)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                        chip("To do", .control(.circle), "sel.todo", .paragon) { session.sequenceToggleTodo() }
                        if !session.chosenMessages.isEmpty { blockMenu }
                        chip("Duplicate", .app(.duplicate), "sel.copy", .boards) { session.sequenceDuplicate() }
                    }
                    #if !os(macOS)
                    chip("Choose more", .control(.addCircle), "sel.more", .boards, on: session.choosingMore) { session.choosingMore.toggle() }
                    #endif
                    chip("Remove", .app(.bin), "sel.remove", .arrows) { session.deleteSelection() }
                }
                .padding(5)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.primary.opacity(0.10)))
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board.selectionBar")

                if showColours, let item { colourRow(for: item) }
            }
            .onChange(of: session.selection) { _, _ in showColours = false }
        }
    }

    @ViewBuilder
    private func chips(for item: Item) -> some View {
        switch item.kind {
        case .who:
            chip("Name", .control(.edit), "sel.name", .text) { session.beginEdit(item.id) }
            chip("Colour", .app(.palette), "sel.colour", .sequence, on: showColours) { showColours.toggle() }
            chip("Message to…", .app(.seedArrow), "sel.messageTo", .arrows) { session.startMessage(from: item.id) }
        case .message:
            chip("Words", .control(.edit), "sel.words", .text) { session.beginEdit(item.id) }
            chip("Answer", .new(.answer), "sel.answer", .sequence, on: item.isAnswer) { session.toggleAnswer() }
            chip("Turn round", .app(.repeat), "sel.turn", .arrows) { session.turnMessageRound() }
            chip("Colour", .app(.palette), "sel.colour", .sequence, on: showColours) { showColours.toggle() }
            chip("To do", .control(.circle), "sel.todo", .paragon, on: item.todo) { session.sequenceToggleTodo() }
            blockMenu
            moveChips
            chip("Duplicate", .app(.duplicate), "sel.copy", .boards) { session.sequenceDuplicate() }
        case .block:
            chip("Words", .control(.edit), "sel.words", .text) { session.beginEdit(item.id) }
            chip("Colour", .app(.palette), "sel.colour", .sequence, on: showColours) { showColours.toggle() }
            chip("Remove block", .app(.bin), "sel.removeBlock", .arrows) { session.sequenceRemoveBlock() }
        default:
            chip("Words", .control(.edit), "sel.words", .text) { session.beginEdit(item.id) }
            chip("Colour", .app(.palette), "sel.colour", .sequence, on: showColours) { showColours.toggle() }
            moveChips
            chip("Duplicate", .app(.duplicate), "sel.copy", .boards) { session.sequenceDuplicate() }
        }
    }

    /// Block: a frame round the chosen messages. A small menu of its words.
    private var blockMenu: some View {
        Menu {
            Button("Repeat") { session.sequenceAddBlock(word: "repeat") }.accessibilityIdentifier("sel.block.repeat")
            Button("If") { session.sequenceAddBlock(word: "if") }.accessibilityIdentifier("sel.block.if")
            Button("Maybe") { session.sequenceAddBlock(word: "maybe") }.accessibilityIdentifier("sel.block.maybe")
            Button("Other words…") { session.sequenceAddBlock(word: nil) }.accessibilityIdentifier("sel.block.other")
        } label: {
            HStack(spacing: 4) {
                GlyphView(glyph: .app(.seedFrame), size: 15, colour: Part.frames.text)
                Text("Block")
                    .font(Txt.pill)
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Part.frames.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(PressStyle(tint: Part.frames.text))
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Block")
        .accessibilityIdentifier("sel.block")
    }

    /// Another place in the order without dragging (the Mac has Option with the arrow keys).
    @ViewBuilder
    private var moveChips: some View {
        #if !os(macOS)
        let up = session.canShiftStep(by: -1), down = session.canShiftStep(by: 1)
        chip("Move up", .new(.moveUp), "sel.moveUp", .sequence) { session.shiftStep(by: -1) }
            .disabled(!up).opacity(up ? 1 : 0.4)
        chip("Move down", .new(.moveDown), "sel.moveDown", .sequence) { session.shiftStep(by: 1) }
            .disabled(!down).opacity(down ? 1 : 0.4)
        #endif
    }

    private func chip(_ word: String, _ glyph: Glyph, _ id: String, _ part: Part, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            HStack(spacing: 4) {
                GlyphView(glyph: glyph, size: 15, colour: on ? .white : part.text)
                Text(word)
                    .font(Txt.pill)
                    .foregroundStyle(on ? Color.white : Color.primary)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(tint: part.text))
        .accessibilityIdentifier(id)
    }

    /// The app's palette; the colour the thing shows now wears a ring. A message has "no colour"
    /// first: it then takes the colour of the name it comes from.
    private func colourRow(for item: Item) -> some View {
        let paint = Paint(scheme)
        let plain = item.kind != .who
        let inUse = item.kind == .band && item.colour.isEmpty ? "yellow" : item.colour
        return HStack(spacing: 7) {
            if plain {
                dot(paint.plate, edge: paint.edge, id: "colour.none", label: "No colour") { session.setColour("") }
                    .modifier(InUseRing(on: inUse.isEmpty))
            }
            ForEach(Palette.names, id: \.self) { name in
                dot(paint.line(name), edge: nil, id: "colour.\(name)", label: name.capitalized) { session.setColour(name) }
                    .modifier(InUseRing(on: inUse == name))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.colours")
    }

    private func dot(_ colour: Color, edge: Color?, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            Circle()
                .fill(colour)
                .overlay(Circle().stroke(edge ?? .clear, lineWidth: 1.5))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(PressStyle(wash: nil))
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
