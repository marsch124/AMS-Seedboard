import SwiftUI
import SeedboardCore
import AMSIcons
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A hand-drawn mark from the shared icon library, whichever family it is in.
enum Glyph {
    case app(AppMark)
    case control(ControlMark)
    /// New in 0.2 (see NewMarks.swift).
    case new(NewMark)
}

struct GlyphView: View {
    let glyph: Glyph
    var size: CGFloat = 20
    var colour: Color?

    var body: some View {
        switch glyph {
        case .app(let mark): AppMarkView(mark, size: size, colour: colour)
        case .control(let mark): ControlMarkView(mark, size: size, colour: colour)
        case .new(let mark): AppMarkView(mark.standIn, size: size, colour: colour)
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
            // The board's own colour runs to every edge of the screen, also under the home bar.
            Paint(scheme).canvas.ignoresSafeArea()
            if session.board.isTimeline { TimelineView(session: session) } else { CanvasView(session: session) }

            if session.board.isEmpty && !session.board.isTimeline {
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
                        Text(session.board.isTimeline ? TimelineWords.linking(first: session.linkFrom == nil)
                             : (session.linkFrom == nil ? "Press the first shape, then the second." : "Now press the shape the arrow goes to."))
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
                if session.board.isTimeline && !session.linking { TimelineSelectionBar(session: session) }
                if let flash = model.flash {
                    Text(flash)
                        .font(Txt.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Part.boards.fill, in: Capsule())
                        .accessibilityIdentifier("board.flash")
                }
                // Wide enough: the tools in the middle, the zoom buttons at the right.
                // Otherwise the zoom buttons sit in their own row above the tools.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 8) {
                        // An iPhone on its side: Undo and Redo sit here, the top bar has no room for them.
                        Group {
                            if compact && !session.readOnly { UndoCluster(session: session) } else { Color.clear.frame(height: 1) }
                        }
                        .frame(width: 150, alignment: .leading)
                        Spacer(minLength: 0)
                        if !session.readOnly { ToolPill(session: session) }
                        Spacer(minLength: 0)
                        ZoomCluster(session: session).frame(width: 150, alignment: .trailing)
                    }
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            if compact && !session.readOnly { UndoCluster(session: session) }
                            Spacer(minLength: 0)
                            ZoomCluster(session: session)
                        }
                        if !session.readOnly {
                            ViewThatFits(in: .horizontal) {
                                ToolPill(session: session)
                                ScrollView(.horizontal, showsIndicators: false) { ToolPill(session: session) }
                            }
                        }
                    }
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
            // On the iPhone Undo and Redo sit at the bottom, so the board's name has room up here.
            if !compact {
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
            }
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
                .disabled(session.board.isTimeline)
                Button("Copy the board as text") {
                    model.copyText(session.board.outlineText)
                    model.say("The board's words are copied.")
                }
                if !session.board.isEmpty {
                    ShareLink(item: BoardPNG(board: session.board), preview: SharePreview(session.board.title)) {
                        Text("Share a picture…")
                    }
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
                #if os(macOS)
                HStack(spacing: 5) {
                    GlyphView(glyph: .app(.send), size: 15, colour: .white)
                    Text("Send to PARAGON")
                }
                #else
                Text(compact ? "Send" : "Send to PARAGON")
                    .lineLimit(1)
                    .fixedSize()
                #endif
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
        // A timeline board has its own tools (TimelineBars.swift).
        if session.board.isTimeline { TimelineToolPill(session: session) } else { ordinary }
    }

    private var ordinary: some View {
        Group {
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
        .fixedSize()
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
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
        // A timeline board steps through days, weeks and months, and has Today (TimelineBars.swift).
        if session.board.isTimeline { TimelineZoomCluster(session: session) } else { ordinary }
    }

    private var ordinary: some View {
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
        // A timeline board has its own bar for the chosen bar, at the bottom (TimelineBars.swift).
        if session.board.isTimeline { EmptyView() } else { ordinary }
    }

    @ViewBuilder
    private var ordinary: some View {
        let item = session.single
        let link = session.selectedLink.flatMap { id in session.board.links.first { $0.id == id } }
        if session.readOnly || (session.selection.isEmpty && link == nil) {
            EmptyView()
        } else {
            VStack(spacing: 5) {
                chips(item, link)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.primary.opacity(0.10)))
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board.selectionBar")

                if showColours {
                    colourRow(for: item, link: link)
                }
            }
            .onChange(of: session.selection) { _, _ in showColours = false }
        }
    }

    private func chips(_ item: Item?, _ link: SeedboardCore.Link?) -> some View {
        // The buttons wrap onto a second row on a narrow screen: none is ever cut off.
        WrapRow(spacing: 5) {
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
            #if !os(macOS)
            chip("Choose more", .control(.addCircle), "sel.more", .boards, on: session.choosingMore) { session.choosingMore.toggle() }
            #endif
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
            chip("Copy", .app(.duplicate), "sel.copy", .boards) { session.duplicateSelection() }
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
        case .bar, .milestone, .phase:
            // A timeline's rows have their own bar (TimelineBars.swift).
            EmptyView()
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
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
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
            Button("Undo") {
                // While words are being typed, Undo belongs to the typing.
                if session?.editing != nil {
                    #if os(macOS)
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                    #endif
                } else {
                    session?.undo()
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(session == nil || (session?.undoCount == 0 && session?.editing == nil))
            Button("Redo") { session?.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(session == nil || session?.redoCount == 0)
        }
        CommandMenu("Board") {
            Button("Copy the Chosen Things") { session?.duplicateSelection() }
                .keyboardShortcut("d", modifiers: .command)
            Button("To Do") { session?.toggleTodo() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Paste a List as a Mind Map") {
                #if os(macOS)
                let text = NSPasteboard.general.string(forType: .string)
                #else
                let text = UIPasteboard.general.string
                #endif
                if let text { session?.paste(text) }
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
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

/// Undo and Redo as a small pair of buttons (on the iPhone, where the top bar has no room for them).
struct UndoCluster: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: 2) {
            button(.undo, "board.undo", "Undo", on: session.undoCount > 0) { session.undo() }
            button(.redo, "board.redo", "Redo", on: session.redoCount > 0) { session.redo() }
        }
        .padding(4)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.primary.opacity(0.10)))
    }

    private func button(_ mark: AppMark, _ id: String, _ help: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppMarkView(mark, size: 18, colour: Part.arrows.text)
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!on)
        .opacity(on ? 1 : 0.35)
        .accessibilityLabel(help)
        .accessibilityIdentifier(id)
    }
}

/// Lays its children out in a row and starts a new row when the width runs out. Rows are centred.
struct WrapRow: Layout {
    var spacing: CGFloat = 5

    private func rows(_ subviews: Subviews, width: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var used: CGFloat = 0
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].isEmpty ? size.width : spacing + size.width
            if used + extra > width, !rows[rows.count - 1].isEmpty {
                rows.append([])
                used = 0
            }
            used += rows[rows.count - 1].isEmpty ? size.width : spacing + size.width
            rows[rows.count - 1].append((i, size))
        }
        return rows.filter { !$0.isEmpty }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        let all = rows(subviews, width: limit)
        let widths = all.map { row in row.map(\.size.width).reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0)) }
        let heights = all.map { row in row.map(\.size.height).max() ?? 0 }
        return CGSize(width: widths.max() ?? 0, height: heights.reduce(0, +) + spacing * CGFloat(max(all.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, width: bounds.width) {
            let width = row.map(\.size.width).reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0))
            let height = row.map(\.size.height).max() ?? 0
            var x = bounds.minX + (bounds.width - width) / 2
            for entry in row {
                subviews[entry.index].place(at: CGPoint(x: x, y: y + (height - entry.size.height) / 2), proposal: ProposedViewSize(entry.size))
                x += entry.size.width + spacing
            }
            y += height + spacing
        }
    }
}
