import SwiftUI
import SeedboardCore
import AMSIcons

/// A hand-drawn mark from the shared icon library, whichever family it is in.
enum Glyph {
    case app(AppMark)
    case control(ControlMark)
}

struct GlyphView: View {
    let glyph: Glyph
    var size: CGFloat = 20
    var colour: Color?

    var body: some View {
        switch glyph {
        case .app(let mark): AppMarkView(mark, size: size, colour: colour)
        case .control(let mark): ControlMarkView(mark, size: size, colour: colour)
        }
    }
}

/// One board: the drawing surface with its tools, the bar for what is chosen, and the top buttons.
struct BoardView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var scheme

    @State private var renaming = false
    @State private var newName = ""
    @State private var removing = false

    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        ZStack {
            CanvasView(session: session)

            if session.board.isEmpty {
                VStack(spacing: 4) {
                    Text("An empty board")
                        .font(Txt.sectionTitle)
                    Text("Press a tool below to start, or paste a list to get a mind map.")
                        .font(Txt.label)
                }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .allowsHitTesting(false)
                .accessibilityIdentifier("board.empty")
            }

            VStack(spacing: 6) {
                if session.readOnly {
                    banner("This board was made by a newer Seedboard. Update the app to change it.", part: .notes)
                } else if session.linking {
                    HStack(spacing: 8) {
                        Text(session.linkFrom == nil ? "Press the first shape, then the second." : "Now press the shape the arrow goes to.")
                            .font(Txt.label)
                        Button("Cancel") {
                            session.linking = false
                            session.linkFrom = nil
                        }
                        .buttonStyle(FilledButton(.arrows))
                        .accessibilityIdentifier("board.linkCancel")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.plate, in: Capsule())
                    .overlay(Capsule().stroke(Part.arrows.text.opacity(0.35)))
                } else {
                    SelectionBar(session: session)
                }
                Spacer(minLength: 0)
                if let flash = model.flash {
                    Text(flash)
                        .font(Txt.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Part.boards.fill, in: Capsule())
                        .accessibilityIdentifier("board.flash")
                }
                HStack(alignment: .bottom) {
                    if !compact { Color.clear.frame(width: 150, height: 1) }
                    Spacer(minLength: 0)
                    if !session.readOnly { ToolPill(session: session) }
                    Spacer(minLength: 0)
                    if !compact { ZoomCluster(session: session).frame(width: 150, alignment: .trailing) }
                }
                if compact {
                    ZoomCluster(session: session)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .navigationTitle(session.board.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .focusedSceneObject(session)
        .sheet(isPresented: $model.showSend) {
            SendSheet(session: session).environmentObject(model)
        }
        .alert("Name of the board", isPresented: $renaming) {
            TextField("Name", text: $newName)
                .accessibilityIdentifier("rename.field")
            Button("Cancel", role: .cancel) {}
            Button("Save") { session.rename(newName) }
        }
        .confirmationDialog("Remove “\(session.board.title)”?", isPresented: $removing, titleVisibility: .visible) {
            Button("Remove the board", role: .destructive) { model.remove(session.board.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is kept for 30 days in the Removed folder.")
        }
    }

    private func banner(_ words: String, part: Part) -> some View {
        Text(words)
            .font(Txt.label)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(part.soft, in: Capsule())
            .overlay(Capsule().stroke(part.text.opacity(0.4)))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { session.undo() } label: { GlyphView(glyph: .app(.undo), size: 20) }
                .disabled(session.undoCount == 0)
                .help("Undo")
                .accessibilityLabel("Undo")
                .accessibilityIdentifier("board.undo")
            Button { session.redo() } label: { GlyphView(glyph: .app(.redo), size: 20) }
                .disabled(session.redoCount == 0)
                .help("Redo")
                .accessibilityLabel("Redo")
                .accessibilityIdentifier("board.redo")
            Menu {
                Button("Rename…") {
                    newName = session.board.title
                    renaming = true
                }
                Button(session.board.pinned ? "Unpin" : "Pin to the top") { model.togglePin(session.board.id) }
                Divider()
                Button("Paste a list as a mind map") {
                    if let text = model.clipboardText() { session.paste(text) } else { model.say("Nothing to paste.") }
                }
                Button("Copy the board as text") {
                    model.copyText(session.board.outlineText)
                    model.say("The board's words are copied.")
                }
                ShareLink(item: BoardPNG(board: session.board), preview: SharePreview(session.board.title)) {
                    Text("Share a picture…")
                }
                Divider()
                Button("Remove the board…", role: .destructive) { removing = true }
            } label: {
                Text("More")
            }
            .help("More")
            .accessibilityLabel("More")
            .accessibilityIdentifier("board.more")

            Button { model.showSend = true } label: {
                HStack(spacing: 5) {
                    GlyphView(glyph: .app(.send), size: 15, colour: .white)
                    Text(compact ? "Send" : "Send to PARAGON")
                }
            }
            .buttonStyle(FilledButton(.boards))
            .help("Send this board to PARAGON")
            .accessibilityIdentifier("board.send")
        }
    }
}

/// The tools: press one and the new thing appears in the middle of the view, ready to type in.
struct ToolPill: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tool(.seedMindMap, .mindMap, "tool.mindmap", "Mind map (M)") { session.add(.idea) }
                tool(.seedBox, .shapes, "tool.box", "Box (B)") { session.add(.box) }
                tool(.seedDiamond, .shapes, "tool.diamond", "Diamond (D)") { session.add(.diamond) }
                tool(.seedArrow, .arrows, "tool.arrow", "Arrow between two shapes (A)", on: session.linking) {
                    session.commitEdit()
                    session.linking.toggle()
                    // With one shape chosen, the arrow starts there.
                    session.linkFrom = session.linking ? session.single.flatMap { $0.kind == .frame ? nil : $0.id } : nil
                }
                tool(.seedNote, .notes, "tool.note", "Sticky note (N)") { session.add(.note) }
                tool(.seedText, .text, "tool.text", "Text (T)") { session.add(.text) }
                tool(.seedFrame, .frames, "tool.frame", "Frame (F)") { session.add(.frame) }
            }
            .padding(6)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 7 * 46 + 12)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .accessibilityIdentifier("board.tools")
    }

    private func tool(_ mark: AppMark, _ part: Part, _ id: String, _ help: String, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppMarkView(mark, size: 24, colour: on ? .white : part.text)
                .frame(width: 40, height: 40)
                .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier(id)
    }
}

/// Smaller, bigger, and the whole board at once.
struct ZoomCluster: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: 2) {
            button(.app(.zoomOut), "zoom.out", "Smaller") { session.zoom(to: session.scale / 1.25) }
            Text("\(Int((session.scale * 100).rounded())) %")
                .font(Txt.pill)
                .monospacedDigit()
                .frame(width: 44)
                .accessibilityIdentifier("zoom.value")
            button(.app(.zoomIn), "zoom.in", "Bigger") { session.zoom(to: session.scale * 1.25) }
            button(.app(.seedFit), "zoom.fit", "Show the whole board") { withAnimation(.easeOut(duration: 0.2)) { session.fit() } }
        }
        .padding(4)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.primary.opacity(0.10)))
    }

    private func button(_ glyph: Glyph, _ id: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlyphView(glyph: glyph, size: 18, colour: Part.arrows.text)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier(id)
    }
}

/// What can be done with the chosen thing. Shown only while something is chosen.
struct SelectionBar: View {
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @State private var showColours = false

    var body: some View {
        let item = session.single
        let link = session.selectedLink.flatMap { id in session.board.links.first { $0.id == id } }
        if session.readOnly || (session.selection.isEmpty && link == nil) {
            EmptyView()
        } else {
            VStack(spacing: 5) {
                ViewThatFits(in: .horizontal) {
                    chips(item, link)
                    ScrollView(.horizontal, showsIndicators: false) { chips(item, link) }
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.primary.opacity(0.10)))
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                .accessibilityIdentifier("board.selectionBar")

                if showColours {
                    colourRow(for: item, link: link)
                }
            }
            .onChange(of: session.selection) { _, _ in showColours = false }
        }
    }

    private func chips(_ item: Item?, _ link: SeedboardCore.Link?) -> some View {
        HStack(spacing: 5) {
            if let item {
                itemChips(item)
            } else if let link {
                linkChips(link)
            } else {
                Text("\(session.selection.count) chosen")
                    .font(Txt.pill)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                chip("To do", .control(.ticked), "sel.todo", .paragon) { session.toggleTodo() }
                chip("Copy", .app(.duplicate), "sel.copy", .boards) { session.duplicateSelection() }
            }
            chip("Remove", .app(.bin), "sel.remove", .arrows) { session.deleteSelection() }
        }
        .padding(5)
    }

    @ViewBuilder
    private func itemChips(_ item: Item) -> some View {
        switch item.kind {
        case .idea:
            chip("Idea under", .control(.add), "sel.child", .mindMap) { session.addChild(of: item.id) }
            if item.parent != nil {
                chip("Next idea", .control(.add), "sel.sister", .mindMap) { session.addSister(of: item.id) }
            }
            if (session.facts.children[item.id] ?? 0) > 0 {
                chip(item.folded ? "Unfold" : "Fold", .control(.chevron), "sel.fold", .mindMap) { session.toggleFold() }
            }
            if item.parent == nil {
                chip(item.bothSides ? "One side" : "Both sides", .app(.seedMindMap), "sel.sides", .mindMap) { session.toggleBothSides() }
            } else {
                chip("Colour", .app(.palette), "sel.colour", .mindMap, on: showColours) { showColours.toggle() }
            }
            chip("To do", .control(.ticked), "sel.todo", .paragon, on: item.todo) { session.toggleTodo() }
        case .box, .round, .diamond, .oval:
            shape(.seedBox, .box, item)
            shape(.seedRound, .round, item)
            shape(.seedDiamond, .diamond, item)
            shape(.seedOval, .oval, item)
            chip("Colour", .app(.palette), "sel.colour", .shapes, on: showColours) { showColours.toggle() }
            chip("To do", .control(.ticked), "sel.todo", .paragon, on: item.todo) { session.toggleTodo() }
            chip("Copy", .app(.duplicate), "sel.copy", .boards) { session.duplicateSelection() }
        case .note:
            chip("Colour", .app(.palette), "sel.colour", .notes, on: showColours) { showColours.toggle() }
            chip("To do", .control(.ticked), "sel.todo", .paragon, on: item.todo) { session.toggleTodo() }
            chip("Copy", .app(.duplicate), "sel.copy", .boards) { session.duplicateSelection() }
        case .text:
            chip("To do", .control(.ticked), "sel.todo", .paragon, on: item.todo) { session.toggleTodo() }
            chip("Copy", .app(.duplicate), "sel.copy", .boards) { session.duplicateSelection() }
        case .frame:
            chip("Colour", .app(.palette), "sel.colour", .frames, on: showColours) { showColours.toggle() }
            chip("Copy", .app(.duplicate), "sel.copy", .boards) { session.duplicateSelection() }
        }
        chip("Words", .control(.edit), "sel.words", .text) { session.beginEdit(item.id) }
    }

    @ViewBuilder
    private func linkChips(_ link: SeedboardCore.Link) -> some View {
        chip("Words", .control(.edit), "sel.words", .text) { session.beginEdit(link.id) }
        ForEach(LinkStyle.allCases, id: \.self) { style in
            chip(style.word, .app(.seedArrow), "sel.style.\(style.rawValue)", .arrows, on: link.style == style) { session.setLinkStyle(style) }
        }
        chip("Turn round", .app(.repeat), "sel.turn", .arrows) { session.turnLinkRound() }
        chip("Colour", .app(.palette), "sel.colour", .arrows, on: showColours) { showColours.toggle() }
    }

    private func shape(_ mark: AppMark, _ kind: ItemKind, _ item: Item) -> some View {
        Button { session.setKind(kind) } label: {
            AppMarkView(mark, size: 20, colour: item.kind == kind ? .white : Part.shapes.text)
                .frame(width: 30, height: 28)
                .background(item.kind == kind ? Part.shapes.fill : Part.shapes.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(kind.word)
        .accessibilityLabel(kind.word)
        .accessibilityIdentifier("sel.shape.\(kind.rawValue)")
    }

    private func chip(_ word: String, _ glyph: Glyph, _ id: String, _ part: Part, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func colourRow(for item: Item?, link: SeedboardCore.Link?) -> some View {
        let paint = Paint(scheme)
        let isNote = item?.kind == .note
        let names = isNote ? Palette.notes : Palette.names
        let plain = item.map { $0.kind.isShape } ?? (link != nil)
        return HStack(spacing: 7) {
            if plain {
                dot(paint.plate, edge: paint.edge, id: "colour.none", label: "No colour") { session.setColour("") }
            }
            ForEach(names, id: \.self) { name in
                dot(isNote ? paint.note(name) : paint.line(name), edge: nil, id: "colour.\(name)", label: name.capitalized) { session.setColour(name) }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        .accessibilityIdentifier("board.colours")
    }

    private func dot(_ colour: Color, edge: Color?, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(colour)
                .overlay(Circle().stroke(edge ?? .clear, lineWidth: 1.5))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

/// The Board menu on the Mac and with an iPad keyboard.
struct BoardCommands: Commands {
    @FocusedObject private var session: BoardSession?

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { session?.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(session == nil || session?.undoCount == 0)
            Button("Redo") { session?.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(session == nil || session?.redoCount == 0)
        }
        CommandMenu("Board") {
            Button("Copy the Chosen Things") { session?.duplicateSelection() }
                .keyboardShortcut("d", modifiers: .command)
            Button("To Do") { session?.toggleTodo() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Bigger") { if let session { session.zoom(to: session.scale * 1.25) } }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller") { if let session { session.zoom(to: session.scale / 1.25) } }
                .keyboardShortcut("-", modifiers: .command)
            Button("Show the Whole Board") { session?.fit() }
                .keyboardShortcut("0", modifiers: .command)
        }
    }
}
