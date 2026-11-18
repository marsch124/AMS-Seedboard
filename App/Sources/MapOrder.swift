import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#endif

// Mind maps in 0.2: ideas in another order (keys, menu, dragging between sisters) and the bar
// above the screen keyboard while an idea is typed. The rules themselves are in SeedboardCore
// (`shiftIdea`, `ideaDrop`, `placeIdea`, `landingLine`).

// MARK: The session's part

extension BoardSession {
    /// True while the words of an idea are being typed.
    var typingInIdea: Bool { editing.flatMap { board.item($0)?.kind } == .idea }

    /// The idea that Move up and Move down act on: the one being typed in, or the one chosen
    /// idea. Never a middle idea, and none while something else is being typed.
    var ideaToShift: UUID? {
        if let id = editing { return board.item(id)?.kind == .idea && board.item(id)?.parent != nil ? id : nil }
        guard let item = single, item.kind == .idea, item.parent != nil else { return nil }
        return item.id
    }

    /// "2 of 5": the chosen idea's place among the sisters of its side. Empty for anything else.
    var chosenPlaceLine: String {
        guard let item = single, item.kind == .idea, let place = board.place(of: item.id) else { return "" }
        return "\(place.at) of \(place.of)"
    }

    /// How far an idea must be dragged from its family to be torn off: 120 points on screen.
    var tearOffReach: Double { MindMap.tearOff / Double(max(scale, 0.05)) }

    /// While an idea is dragged: the idea it would hang under, or the line where it would land.
    func dropHints(for id: UUID, at point: CGPoint) -> (target: UUID?, line: Landing?) {
        switch board.ideaDrop(id, at: point, reach: tearOffReach) {
        case .hang(let over):
            return (over, nil)
        case .reorder(let slot):
            return (nil, board.landingLine(for: slot, moving: id).map { Landing(from: $0.from, to: $0.to) })
        case .springBack, .tearOff:
            return (nil, nil)
        }
    }

    /// A dragged idea is let go: it lands between two sisters, hangs under another idea,
    /// becomes its own map, or goes back to where it was. Each is one step for Undo.
    func dropIdea(_ id: UUID, at point: CGPoint) {
        switch board.ideaDrop(id, at: point, reach: tearOffReach) {
        case .hang(let over):
            hang(id, under: over)
        case .reorder(let slot):
            if change({ $0.placeIdea(id, in: slot) }) { selection = [id] }
        case .tearOff:
            detach(id, at: point)
        case .springBack:
            break
        }
    }
}

// MARK: The landing line

/// The thin line that shows where a dragged idea will land, in board points.
struct Landing {
    var from: CGPoint
    var to: CGPoint

    /// Drawn into a context that is already in board points.
    func draw(_ ctx: inout GraphicsContext, colour: Color, scale: CGFloat) {
        var line = Path()
        line.move(to: from)
        line.addLine(to: to)
        ctx.stroke(line, with: .color(colour), style: StrokeStyle(lineWidth: 2.5 / scale, lineCap: .round))
        // A small ring at each end, so the line reads as "it goes in here" and not as a branch.
        let r = 3.5 / scale
        for end in [from, to] {
            let ring = Path(ellipseIn: CGRect(x: end.x - r, y: end.y - r, width: r * 2, height: r * 2))
            ctx.fill(ring, with: .color(colour))
        }
    }
}

// MARK: For the screen tests

/// The chosen idea's place among its sisters ("2 of 5") as words of its own, too small and
/// faint to see: the screen tests read the order from it.
struct IdeaPlaceMark: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        Text(session.chosenPlaceLine)
            .font(.system(size: 1))
            .foregroundStyle(.clear)
            .frame(width: 1, height: 1)
            .offset(x: 3)
            .allowsHitTesting(false)
            .accessibilityIdentifier("board.chosenPlace")
    }
}

// MARK: The Board menu

/// "Move the Idea Up" ⌘↑ and "Move the Idea Down" ⌘↓, for the Board menu.
struct IdeaOrderCommands: View {
    @FocusedObject private var session: BoardSession?

    var body: some View {
        Button("Move the Idea Up") { move(down: false) }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(!ready(down: false))
        Button("Move the Idea Down") { move(down: true) }
            .keyboardShortcut(.downArrow, modifiers: .command)
            .disabled(!ready(down: true))
    }

    private func ready(down: Bool) -> Bool {
        #if os(macOS)
        // Never switched off on the Mac: a menu key that is switched off can swallow ⌘↑ and ⌘↓,
        // and those move the cursor in every text field. `move` hands them on instead.
        return true
        #else
        guard let session, !session.readOnly, let id = session.ideaToShift else { return false }
        return session.board.canShiftIdea(id, down: down)
        #endif
    }

    private func move(down: Bool) {
        #if os(macOS)
        // Words are being typed somewhere that is not an idea of the board (a box, a note, the
        // name on a page): the keys belong to the words, as everywhere on the Mac.
        if let window = NSApp.keyWindow, let field = window.firstResponder as? NSText,
           session?.typingInIdea != true || window.sheetParent != nil {
            if down { field.moveToEndOfDocument(nil) } else { field.moveToBeginningOfDocument(nil) }
            return
        }
        #endif
        guard let session, let id = session.ideaToShift else { return }
        session.shiftIdea(id, down: down)
    }
}

// MARK: Typing an idea on iPhone and iPad

extension CanvasView {
    /// The one field every idea is typed in on iPhone and iPad.
    private static let ideaField = UUID()

    /// Which typing field this is. On iPhone and iPad all ideas share one field, so the screen
    /// keyboard stays up while the typing goes from idea to idea; everything else (and the Mac)
    /// gets a fresh field each time.
    func fieldIdentity(isIdea: Bool) -> UUID? {
        #if os(iOS)
        if isIdea { return Self.ideaField }
        #endif
        return session.editing
    }

    #if os(iOS)
    /// The bar above the screen keyboard. For an idea: Idea under (as Tab), Next idea (as Return),
    /// Out one level (as Shift and Tab), then Done. For anything else just Done.
    @ViewBuilder
    func keyboardBar(isIdea: Bool) -> some View {
        if isIdea {
            // Whole words where there is room (iPad), short ones on a narrow screen (iPhone).
            let wide = session.viewSize.width >= 520
            let id = session.editing
            let canGoOut = id.map { session.board.depth(of: $0) >= 2 } ?? false
            KeyBarButton(mark: .ideaUnder, words: wide ? "Idea under" : "Under", name: "Idea under", id: "board.key.under") {
                session.commitEdit(then: .child)
            }
            KeyBarButton(mark: .nextIdea, words: wide ? "Next idea" : "Next", name: "Next idea", id: "board.key.next") {
                session.commitEdit(then: .sister)
            }
            KeyBarButton(mark: .outLevel, words: wide ? "Out one level" : "Out", name: "Out one level", id: "board.key.out", on: canGoOut) {
                if let id { session.moveOut(id) }
            }
        }
        Spacer()
        Button("Done") { session.commitEdit() }
            .fontWeight(.semibold)
            .accessibilityIdentifier("board.fieldDone")
    }
    #endif
}

#if os(iOS)
/// One button of the keyboard bar: a hand-drawn mark with a short word beside it, in the mind map's colour.
private struct KeyBarButton: View {
    let mark: NewMark
    let words: String
    /// The whole name, read out by VoiceOver.
    let name: String
    let id: String
    var on = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                GlyphView(glyph: .new(mark), size: 17, colour: Part.mindMap.text)
                Text(words)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(Part.mindMap.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!on)
        .opacity(on ? 1 : 0.4)
        .accessibilityLabel(name)
        .accessibilityIdentifier(id)
    }
}
#endif
