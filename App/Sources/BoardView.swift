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
            if session.board.isSequence { SequenceView(session: session) } else
            if session.board.isTimeline { TimelineView(session: session) } else { CanvasView(session: session) }

            // 0.5: an empty board invites — the sprout, "What is on your mind?", three ways to begin (EmptyBoard.swift).
            EmptyInvite(session: session, desk: session.ink)

            VStack(spacing: 6) {
                // 0.5: what PARAGON says about a board that is a note or a project there (SentLine.swift).
                SentLine(session: session)
                // A starter is being changed: this board is its working copy (StartersPage.swift).
                if session.starterDraft { StarterChangeBanner() }
                if HandoffDesk.shared.waiting == session.board.id {
                    // Taken up from another device before iCloud brought its newest version (HandoffDesk.swift).
                    banner(Handoff.waitingLine, part: .boards).accessibilityIdentifier("board.handoffWait")
                } else if session.readOnly {
                    banner("This board was made by a newer Seedboard. Update the app to change it.", part: .notes)
                } else if session.linking {
                    HStack(spacing: 8) {
                        Text(session.board.isSequence ? SequenceWords.linking(first: session.linkFrom == nil) :
                             session.board.isTimeline ? TimelineWords.linking(first: session.linkFrom == nil)
                             : (session.linkFrom == nil ? "Press the first shape, then the second." : "Now press the shape the arrow goes to."))
                            .font(Txt.label)
                        Button("Cancel") {
                            session.linking = false
                            session.linkFrom = nil
                            session.takeKeys()
                        }
                        .buttonStyle(FilledButton(.arrows))
                        .accessibilityIdentifier("board.linkCancel")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.plate, in: Capsule())
                    .overlay(Capsule().stroke(Part.arrows.text.opacity(0.35)))
                    .transition(.message)
                } else {
                    // The iPhone's one-row bar; on the Mac and the iPad the bar floats beside the chosen thing (ChosenBar.swift).
                    ChosenBarTop(session: session)
                }
                Spacer(minLength: 0)
                if let notice = session.notice {
                    // A step the owner may not have meant (an idea torn off its map): one press takes it back.
                    HStack(spacing: 10) {
                        Text(notice.words)
                            .font(Txt.label)
                            .foregroundStyle(.white)
                        Button {
                            session.undo()
                            session.takeKeys()
                        } label: {
                            Text("Undo")
                                .font(Txt.label.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.22), in: Capsule())
                                .pressRoom(0, 11)
                        }
                        .buttonStyle(PressStyle(tint: .white))
                        .accessibilityIdentifier("board.noticeUndo")
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 5)
                    .padding(.vertical, 5)
                    .background(Part.mindMap.fill, in: Capsule())
                    // Its own element with its button inside, so the button keeps its own name for the screen tests.
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("board.notice")
                    .transition(.message)
                }
                // On a timeline and a "Who does what" board the top holds the dates and the names: the line sits down here.
                SentLine(session: session, low: true)
                if session.board.isTimeline && !session.linking { TimelineSelectionBar(session: session) }
                if session.board.isSequence && !session.linking { SequenceSelectionBar(session: session) }
                // The one line at the bottom (FeelLooks.swift); with no board in sight the window shows it (RootView).
                FlashLine()
                // The Draw tool's plate: pen and rubber, thickness, colours (InkViews.swift).
                DrawPlate(session: session, desk: session.ink)
                // Wide enough: the tools in the middle, the zoom buttons at the right.
                // Otherwise the zoom buttons sit in their own row above the tools.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 8) {
                        // An iPhone on its side: Undo and Redo sit here, the top bar has no room for them.
                        Group {
                            if compact && !session.readOnly { UndoCluster(session: session) } else { Color.clear.frame(height: 1) }
                        }
                        .frame(width: Finger.side, alignment: .leading)
                        Spacer(minLength: 0)
                        if !session.readOnly { ToolPill(session: session) }
                        Spacer(minLength: 0)
                        ZoomCluster(session: session).frame(width: Finger.side, alignment: .trailing)
                    }
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            if compact && !session.readOnly { UndoCluster(session: session) }
                            Spacer(minLength: 0)
                            ZoomCluster(session: session)
                        }
                        if !session.readOnly {
                            // Nine tools: on a narrow iPhone the tiles shrink a little (40 → 36 → 32) before the row would have to scroll.
                            ViewThatFits(in: .horizontal) {
                                ToolPill(session: session)
                                ToolPill(session: session).environment(\.toolSide, 36)
                                ToolPill(session: session).environment(\.toolSide, 32)
                                ScrollView(.horizontal, showsIndicators: false) { ToolPill(session: session).environment(\.toolSide, 32) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // 0.5: the messages in here slide up and fade in, and fade out (`.transition(.message)`).
            .animation(.message, value: model.flash)
            .animation(.message, value: session.notice)
            .animation(.message, value: session.linking)
        }
        .navigationTitle(session.starterDraft ? (model.changing?.name ?? session.board.title) : session.board.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .focusedSceneObject(session)
        // 0.5: the open board offers itself on his other devices (Handoff).
        .modifier(BoardHandoff(session: session))
        // File ▸ Rename… and Remove Board… open the same two questions as the More button (Menus.swift).
        .modifier(MenuAsks(rename: { newName = session.board.title; renaming = true }, remove: { removing = true }))
        // Doors (0.5): "‹ name" to go back, the page "Door to a board…", the name of a new board (DoorPage.swift).
        .modifier(DoorHost(session: session))
        // The Share plate (SharePlate.swift).
        .modifier(ShareHost(session: session))
        // When the Send page closes, the board has the keys again.
        .sheet(isPresented: $model.showSend, onDismiss: { session.takeKeys() }) {
            SendSheet(session: session).environmentObject(model)
        }
        // "Crop the picture" (CropPage.swift).
        .sheet(isPresented: Binding(get: { session.cropping != nil }, set: { if !$0 { session.cropping = nil } }), onDismiss: { session.takeKeys() }) {
            if let id = session.cropping { CropPage(session: session, id: id) }
        }
        .alert("Name of the board", isPresented: $renaming) {
            TextField("Name", text: $newName)
                .accessibilityIdentifier("rename.field")
            Button("Cancel", role: .cancel) { session.takeKeys() }
            Button("Save") {
                // On a starter's working copy the name is the starter's.
                if session.starterDraft { model.renameChange(newName) } else { session.rename(newName) }
                session.takeKeys()
            }
        }
        .confirmationDialog("Remove “\(session.board.title)”?", isPresented: $removing, titleVisibility: .visible) {
            Button("Remove the board", role: .destructive) { model.remove(session.board.id) }
            Button("Cancel", role: .cancel) { session.takeKeys() }
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
                Button { session.undo(); session.takeKeys() } label: { GlyphView(glyph: .app(.undo), size: 20) }
                    .disabled(session.undoCount == 0)
                    .help("Undo")
                    .accessibilityLabel("Undo")
                    .accessibilityIdentifier("board.undo")
                Button { session.redo(); session.takeKeys() } label: { GlyphView(glyph: .app(.redo), size: 20) }
                    .disabled(session.redoCount == 0)
                    .help("Redo")
                    .accessibilityLabel("Redo")
                    .accessibilityIdentifier("board.redo")
            }
            Menu {
                Button("Rename…") {
                    newName = session.starterDraft ? (model.changing?.name ?? session.board.title) : session.board.title
                    renaming = true
                }
                // After each choice in the menu the board has the keys again.
                if !session.starterDraft {
                    Button(session.board.pinned ? "Unpin" : "Pin to the top") {
                        model.togglePin(session.board.id)
                        session.takeKeys()
                    }
                    if !session.readOnly {
                        Button("Save as a starter…") {
                            session.commitEdit()
                            model.ask(.save(session.board))
                        }
                    }
                }
                Divider()
                // On a timeline the list becomes bars (0.5, TimelineOfIt.swift).
                Button(session.board.isTimeline ? "Paste a list as bars" : "Paste a list as a mind map") {
                    if let text = model.clipboardText() { session.paste(text) } else { model.say("Nothing to paste.", tone: .problem) }
                    session.takeKeys()
                }
                .disabled(session.board.isSequence)
                Button("Copy the board as text") {
                    model.copyText(session.board.outlineText)
                    model.say("The board's words are copied.")
                    session.takeKeys()
                }
                // 0.5: a new timeline board from this board's ideas and shapes (not on a board that places its things itself).
                if !session.board.placesItself && !session.starterDraft {
                    Button("Make a timeline of it…") { model.makeTimeline(of: session) }
                        .disabled(session.board.isEmpty)
                        .accessibilityIdentifier("more.makeTimeline")
                }
                if !session.board.isEmpty {
                    // "Share…" (and "Print…" on iPhone and iPad): SharePlate.swift.
                    ShareLines(session: session)
                }
                if !session.starterDraft {
                    Divider()
                    Button("Remove the board…", role: .destructive) { removing = true }
                }
            } label: {
                Text("More")
            }
            .help("More")
            .accessibilityLabel("More")
            .accessibilityIdentifier("board.more")
        }
        // 0.5: Send stands by itself, off the top bar's glass — the glass made its purple paler (FeelLooks.swift).
        OffGlassItem {
            if !session.starterDraft {
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
            .buttonStyle(ParagonButton())
            .help("Send this board to PARAGON")
            .accessibilityIdentifier("board.send")
            }
        }
    }
}

/// The side of one tool tile: 40 points, smaller when the row of nine would not fit an iPhone's width.
private struct ToolSideKey: EnvironmentKey { static let defaultValue: CGFloat = 40 }

extension EnvironmentValues {
    var toolSide: CGFloat {
        get { self[ToolSideKey.self] }
        set { self[ToolSideKey.self] = newValue }
    }
}

enum ToolSize {
    /// The mark inside a tile of this side.
    static func mark(_ side: CGFloat) -> CGFloat { side >= 40 ? 24 : side >= 36 ? 22 : 20 }
    /// The gap between two tiles of this side.
    static func gap(_ side: CGFloat) -> CGFloat { side >= 40 ? 6 : side >= 36 ? 4 : 3 }
}

/// The tools: press one and the new thing appears in the middle of the view, ready to type in.
struct ToolPill: View {
    @ObservedObject var session: BoardSession
    @Environment(\.toolSide) private var side

    var body: some View {
        // A timeline board has its own tools (TimelineBars.swift).
        if session.board.isSequence { SequenceToolPill(session: session) } else
        if session.board.isTimeline { TimelineToolPill(session: session) } else { ordinary }
    }

    private var ordinary: some View {
        Group {
            HStack(spacing: ToolSize.gap(side)) {
                tool(.seedMindMap, .mindMap, "tool.mindmap", "Mind map (M)") { session.add(.idea) }
                ShapeTool(session: session)
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
                PictureTool(session: session)
                DrawTool(session: session, desk: session.ink)
            }
            .padding(side >= 40 ? 6 : 5)
        }
        .fixedSize()
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.tools")
        .modifier(BoardShield("tools"))
    }

    private func tool(_ mark: AppMark, _ part: Part, _ id: String, _ help: String, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            AppMarkView(mark, size: ToolSize.mark(side), colour: on ? .white : part.text)
                .frame(width: side, height: side)
                .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .pressRoom(3, 3)
        }
        .buttonStyle(PressStyle(tint: part.text))
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
            button(.app(.zoomOut), "zoom.out", "Smaller") { session.zoomStep(by: 1 / 1.25) }
            Text("\(Int((session.scale * 100).rounded())) %")
                .font(Txt.pill)
                .monospacedDigit()
                .frame(width: 44)
                .accessibilityIdentifier("zoom.value")
            button(.app(.zoomIn), "zoom.in", "Bigger") { session.zoomStep(by: 1.25) }
            button(.app(.seedFit), "zoom.fit", "Show the whole board") { session.fit() }
                .padding(.leading, Finger.pairGap - 2)
        }
        .padding(4)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .plateShadow()
        .modifier(BoardShield("zoom"))
    }

    private func button(_ glyph: Glyph, _ id: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            GlyphView(glyph: glyph, size: 18, colour: Part.arrows.text)
                .frame(width: Finger.zoom.width, height: Finger.zoom.height)
                .contentShape(Rectangle())
                .pressRoom(4, 4)
        }
        .buttonStyle(PressStyle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier(id)
    }
}

/// Undo and Redo for the words being typed: they belong to the text field that has the keys.
enum TextUndo {
    static func undo() {
        #if os(macOS)
        NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        #else
        typingField?.undoManager?.undo()
        #endif
    }

    static func redo() {
        #if os(macOS)
        NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        #else
        typingField?.undoManager?.redo()
        #endif
    }

    #if !os(macOS)
    fileprivate static weak var found: UIResponder?

    /// The view that has the keys right now.
    private static var typingField: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.seedboardHasTheKeys(_:)), to: nil, from: nil, for: nil)
        return found
    }
    #endif
}

#if !os(macOS)
extension UIResponder {
    @objc fileprivate func seedboardHasTheKeys(_ sender: Any?) { TextUndo.found = self }
}
#endif

/// The Board menu on the Mac and with a keyboard on the iPad or iPhone. (File, Edit ▸ Duplicate,
/// View ▸ zoom and Insert are `SeedMenus` in Menus.swift.)
struct BoardCommands: Commands {
    @FocusedObject private var session: BoardSession?

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                // While words are being typed, Undo belongs to the typing.
                if session?.editing != nil { TextUndo.undo() } else { session?.undo() }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(session == nil || (session?.undoCount == 0 && session?.editing == nil))
            Button("Redo") {
                if session?.editing != nil { TextUndo.redo() } else { session?.redo() }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(session == nil || (session?.redoCount == 0 && session?.editing == nil))
        }
        CommandMenu("Board") {
            Button("To Do") { session?.toggleTodo() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(session?.selection.isEmpty ?? true)
            Button("Line Up") { session?.lineUp() }.disabled((session?.tidyCount ?? 0) < 2)
            Button("Even Gaps") { session?.evenGaps() }.disabled((session?.tidyCount ?? 0) < 3)
            Button("Same Size") { session?.sameSize() }.disabled((session?.sizeCount ?? 0) < 2)
            IdeaOrderCommands()
            Button(session?.board.isTimeline == true ? "Paste a List as Bars" : "Paste a List as a Mind Map") {
                #if os(macOS)
                let text = NSPasteboard.general.string(forType: .string)
                #else
                let text = UIPasteboard.general.string
                #endif
                if let text { session?.paste(text) }
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(session == nil || session?.readOnly == true || session?.editing != nil || session?.board.isSequence == true)
        }
    }
}

/// Undo and Redo as a small pair of buttons (on the iPhone, where the top bar has no room for them).
struct UndoCluster: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: Finger.pairGap) {
            button(.undo, "board.undo", "Undo", on: session.undoCount > 0) { session.undo() }
            button(.redo, "board.redo", "Redo", on: session.redoCount > 0) { session.redo() }
        }
        .padding(4)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .plateShadow()
    }

    private func button(_ mark: AppMark, _ id: String, _ help: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            AppMarkView(mark, size: 18, colour: Part.arrows.text)
                .frame(width: Finger.undo.width, height: Finger.undo.height)
                .contentShape(Rectangle())
                .pressRoom(4, 4)
        }
        .buttonStyle(PressStyle())
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
