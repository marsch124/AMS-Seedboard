import SwiftUI
import SeedboardCore
import AMSIcons

// The bar for what is chosen (0.2, pick 7). On the Mac and the iPad it floats 12 points above
// the chosen thing (below it when there is no room above), follows the board while it slides and
// zooms, and is out of the way while the thing is dragged or typed in. On the iPhone it is one row
// at the top. It is never more than one row: what does not fit goes into a "…" list. One tint per
// bar — the colour of the chosen kind's part; only "To do" stays purple and "Remove" red, set
// apart at the end by a hairline.

/// How a button of the bar looks.
struct ChipLook: View {
    let action: BarAction
    let worded: Bool
    let tint: Part
    /// Shown as switched on although the action is not (its list is open).
    var lit = false

    var body: some View {
        let part: Part = action.tone == .todo ? .paragon : (action.tone == .remove ? .kept : tint)
        let on = action.on || lit
        HStack(spacing: 4) {
            GlyphView(glyph: action.glyph, size: 15, colour: on ? .white : part.text)
            if worded {
                Text(action.word)
                    .font(Txt.pill)
                    .foregroundStyle(on ? Color.white : Color.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, worded ? 8 : 0)
        .frame(minWidth: Finger.chipHeight)
        .frame(height: Finger.chipHeight)
        .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .opacity(action.enabled ? 1 : 0.4)
    }
}

/// The bar itself: one row of buttons, and under it the colour dots while "Colour" is on.
struct ChosenBar: View {
    @ObservedObject var session: BoardSession
    /// The Mac and the iPad (more buttons carry their word) or the iPhone.
    let wide: Bool
    @Environment(\.colorScheme) private var scheme
    /// For pictures: `-colours` (with `-pick`) opens the colour dots.
    @State private var showColours = LaunchOptions.arguments.contains("-colours")
    /// For pictures: `-more` (with `-pick`) opens the "…" list.
    @State private var showMore = LaunchOptions.arguments.contains("-more")
    /// The button whose short list is open ("Line", "Ends"). For pictures: `-plate line` or `-plate ends`.
    @State private var choosing: String? = LaunchOptions.value(for: "-plate").flatMap { ["line", "ends"].contains($0) ? "sel." + $0 : nil }

    var body: some View {
        let night = scheme == .dark
        let make = BarActions(session: session, dots: (showColours, { showColours.toggle() }), night: night)
        if let model = make.bar(), !model.actions.isEmpty {
            VStack(spacing: 5) {
                row(model)
                    .padding(5)
                    .background(Theme.plate, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.primary.opacity(0.10)))
                    .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                    // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("board.selectionBar")

                if showColours {
                    let link = session.selectedLink.flatMap { id in session.board.links.first { $0.id == id } }
                    // The dots keep the names they had in 0.1 ("colour.pink").
                    ColourRow(colours: BarActions(session: session, prefix: "", night: night).colourChoices(for: session.single, link: link),
                              edge: Paint(scheme).edge)
                }
            }
            .onChange(of: session.selection) { _, _ in showColours = false }
        }
    }

    // MARK: One row, whatever the width

    /// Where the buttons at the end begin ("To do" and "Remove", after the hairline).
    private func tailStart(_ actions: [BarAction]) -> Int {
        actions.firstIndex { $0.gap } ?? actions.count
    }

    /// The buttons that may go into the "…" list, the first to go first.
    private func droppable(_ actions: [BarAction]) -> [String] {
        let head = Array(actions[..<tailStart(actions)].enumerated())
        return head.filter { $0.element.drop > 0 }
            .sorted { ($0.element.drop, $0.offset) > ($1.element.drop, $1.offset) }
            .map(\.element.id)
    }

    /// How many buttons carry their word.
    private enum Words {
        /// The main ones and, on the Mac and the iPad, the ones that have room there.
        case all
        /// The main ones.
        case main
        /// Only the first main one; the line of words in front ("3 chosen") is left out too.
        case first
    }

    /// One row, whatever the width. The first of these that fits is shown: every button with all
    /// the words; with fewer words; with one word; then one button fewer each time, the rest
    /// behind a "…"; and at the very last the row slides sideways rather than break in two.
    private func row(_ model: ChosenBarModel) -> some View {
        let order = droppable(model.actions)
        return ViewThatFits(in: .horizontal) {
            if wide { line(model, dropped: [], words: .all) }
            line(model, dropped: [], words: .main)
            line(model, dropped: [], words: .first)
            ForEach(Array(order.indices), id: \.self) { n in
                line(model, dropped: Set(order.prefix(n + 1)), words: .main)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                line(model, dropped: Set(order), words: .first)
            }
        }
    }

    private func line(_ model: ChosenBarModel, dropped: Set<String>, words: Words) -> some View {
        let split = tailStart(model.actions)
        let head = model.actions[..<split].filter { !dropped.contains($0.id) }
        let tail = Array(model.actions[split...])
        let rest = model.actions[..<split].filter { dropped.contains($0.id) }
        let first = model.actions.first { $0.show == .word }?.id
        func worded(_ action: BarAction) -> Bool {
            switch words {
            case .all: return action.show != .icon
            case .main: return action.show == .word
            case .first:
                // A button that opens a list ("Line", "Ends") is not clear without its word.
                if case .choices = action.kind { return action.show == .word }
                return action.id == first
            }
        }
        return HStack(spacing: Finger.chipGap) {
            if let label = model.label, words != .first {
                Text(label)
                    .font(Txt.pill)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("sel.count")
            }
            ForEach(head) { chip($0, model.part, worded($0)) }
            if !rest.isEmpty { more(rest, model.part) }
            if !tail.isEmpty {
                Rectangle()
                    .fill(Color.primary.opacity(0.16))
                    .frame(width: 1, height: Finger.chipHeight - 10)
                    .accessibilityHidden(true)
                ForEach(tail) { chip($0, model.part, worded($0)) }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func chip(_ action: BarAction, _ tint: Part, _ worded: Bool) -> some View {
        switch action.kind {
        case .press(let run):
            Button(action: run) {
                ChipLook(action: action, worded: worded, tint: tint)
                    .pressRoom(0, 4)
            }
            .buttonStyle(PressStyle())
            .disabled(!action.enabled)
            .help(action.word)
            .accessibilityLabel(action.word)
            .accessibilityIdentifier(action.id)
        case .choices(let choices):
            Button { choosing = action.id } label: {
                ChipLook(action: action, worded: worded, tint: tint, lit: choosing == action.id)
                    .pressRoom(0, 4)
            }
            .buttonStyle(PressStyle())
            .help(action.word)
            .accessibilityLabel(action.word)
            .accessibilityIdentifier(action.id)
            .modifier(PlatePresenter(shown: Binding(get: { choosing == action.id }, set: { if !$0 { choosing = nil } }),
                                     edge: .bottom, height: ActionList.height(choices.count), closed: { session.takeKeys() }) {
                ActionList(title: action.word, glyph: action.glyph, part: tint, actions: choices, fixed: false) { choosing = nil }
            })
        case .shape(let item):
            ShapeChip(session: session, item: item)
        case .lanes(let item):
            LanesChip(session: session, item: item)
        }
    }

    /// "…": the buttons that found no room in the row, as a list.
    private func more(_ rest: [BarAction], _ tint: Part) -> some View {
        let dots = BarAction(id: "sel.overflow", word: "More", glyph: .control(.more), kind: .choices(rest))
        return Button { showMore = true } label: {
            // Lit while its list is open, and while something in it is switched on ("Choose more").
            ChipLook(action: dots, worded: false, tint: tint, lit: showMore || rest.contains { $0.on })
                .pressRoom(0, 4)
        }
        .buttonStyle(PressStyle())
        .help("More")
        .accessibilityLabel("More")
        .accessibilityIdentifier(dots.id)
        .modifier(PlatePresenter(shown: $showMore, edge: .bottom, height: ActionList.height(rest.count), closed: { session.takeKeys() }) {
            ActionList(title: "More", glyph: .control(.more), part: tint, actions: rest, fixed: false) { showMore = false }
        })
    }
}

/// The colours to pick from as a row of dots; the one in use wears a ring.
struct ColourRow: View {
    let colours: [BarAction]
    let edge: Color
    /// Called after a colour was picked.
    var picked: () -> Void = {}
    /// Inside a list the row has no plate of its own.
    var bare = false

    var body: some View {
        // iPhone and iPad: bigger dots, well apart; on a narrow screen they take a second row.
        let row = Finger.on || bare ? AnyLayout(WrapRow(spacing: Finger.dotGap)) : AnyLayout(HStackLayout(spacing: Finger.dotGap))
        let plate = Finger.on ? AnyShape(RoundedRectangle(cornerRadius: 21, style: .continuous)) : AnyShape(Capsule())
        let dots = row {
            ForEach(colours) { colour in
                Button {
                    if case .press(let run) = colour.kind { run() }
                    picked()
                } label: {
                    Circle()
                        .fill(colour.swatch ?? .clear)
                        .overlay(Circle().stroke(colour.hollow ? edge : .clear, lineWidth: 1.5))
                        .frame(width: Finger.dot, height: Finger.dot)
                        .pressRoom(7, 7)
                }
                .buttonStyle(PressStyle())
                .modifier(InUseRing(on: colour.on))
                .accessibilityLabel(colour.word)
                .accessibilityIdentifier(colour.id)
            }
        }
        if bare {
            dots.padding(.horizontal, 6).padding(.vertical, 8)
        } else {
            dots
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Theme.plate, in: plate)
                .overlay(plate.stroke(Color.primary.opacity(0.10)))
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board.colours")
        }
    }
}

/// A list of things to do, one under the other: the "…" list of the bar, the short lists behind
/// "Line" and "Ends", and the press-and-hold menu of iPhone and iPad. A line that leads to more
/// (Colour, Shape, Lanes) opens its list in the same place, with a way back.
struct ActionList: View {
    let title: String
    let glyph: Glyph
    let part: Part
    let actions: [BarAction]
    /// A fixed width (a pop-up); otherwise as wide as the sheet.
    var fixed = true
    /// Called when the list should go: after a line was pressed, and by Cancel.
    let close: () -> Void

    @State private var path: [BarAction] = []
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var scheme

    static let rowHeight: CGFloat = Finger.on ? 40 : 26

    /// The height of the iPhone's sheet for this many lines.
    static func height(_ lines: Int) -> CGFloat { CGFloat(min(max(lines, 2), 9)) * (rowHeight + 2) + 76 }

    private var lines: [BarAction] {
        if let last = path.last, case .choices(let inner) = last.kind { return inner }
        return actions
    }

    var body: some View {
        let lines = self.lines
        VStack(alignment: .leading, spacing: 2) {
            heading
            if !lines.isEmpty, lines.allSatisfy({ $0.swatch != nil }) {
                ColourRow(colours: lines, edge: Paint(scheme).edge, picked: close, bare: true)
            } else {
                ForEach(lines) { line in
                    if line.gap, line.id != lines.first?.id {
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 1)
                            .padding(.vertical, 2)
                            .accessibilityHidden(true)
                    }
                    row(line)
                }
            }
        }
        .padding(8)
        .frame(width: width)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plate.actions")
    }

    private var width: CGFloat? {
        #if os(macOS)
        return 230
        #else
        return fixed || sizeClass != .compact ? 250 : nil
        #endif
    }

    private var heading: some View {
        HStack(spacing: 6) {
            if let last = path.last {
                Button { path.removeLast() } label: {
                    HStack(spacing: 4) {
                        GlyphView(glyph: .app(.back), size: 15, colour: part.text)
                        Text(last.word)
                            .font(Txt.sectionTitle)
                            .foregroundStyle(part.text)
                    }
                    .contentShape(Rectangle())
                    .pressRoom(6, 8)
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Back")
                .accessibilityIdentifier("plate.back")
            } else {
                GlyphView(glyph: glyph, size: 16, colour: part.text)
                Text(title)
                    .font(Txt.sectionTitle)
                    .foregroundStyle(part.text)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button("Cancel", action: close)
                .buttonStyle(PressStyle())
                .font(Txt.label.weight(.semibold))
                .foregroundStyle(part.text)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("plate.cancel")
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }

    private func row(_ line: BarAction) -> some View {
        let tone: Part = line.tone == .todo ? .paragon : (line.tone == .remove ? .kept : part)
        var leads = false
        if case .choices = line.kind { leads = true }
        return Button {
            switch line.kind {
            case .press(let run):
                run()
                close()
            case .choices:
                path.append(line)
            case .shape, .lanes:
                break
            }
        } label: {
            HStack(spacing: 8) {
                GlyphView(glyph: line.glyph, size: 17, colour: tone.text)
                Text(line.word)
                    .font(Txt.label)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 10)
                if leads {
                    GlyphView(glyph: .control(.chevron), size: 13, colour: .secondary)
                } else if line.on {
                    GlyphView(glyph: .control(.check), size: 14, colour: tone.text)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: ActionList.rowHeight)
            .background(line.on && !leads ? tone.soft : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(!line.enabled)
        .opacity(line.enabled ? 1 : 0.4)
        .accessibilityLabel(line.word)
        .accessibilityAddTraits(line.on ? .isSelected : [])
        .accessibilityIdentifier(line.id)
    }
}

// MARK: Where the bar stands

/// Places its one child beside a box: above it, else below, always inside (`BarPlace.spot`).
struct BarSpot: Layout {
    /// The chosen thing's box, in this layout's own points.
    var box: CGRect
    /// Kept free at the bottom (the tools lie there).
    var bottom: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let bar = subviews.first else { return }
        let room = CGRect(x: 0, y: 0, width: bounds.width, height: max(bounds.height - bottom, 60))
        let offer = ProposedViewSize(width: max(room.width - 2 * BarPlace.air, 40), height: max(room.height - 2 * BarPlace.air, 40))
        let size = bar.sizeThatFits(offer)
        let spot = BarPlace.spot(box: box, bar: size, room: room)
        bar.place(at: CGPoint(x: bounds.minX + spot.origin.x, y: bounds.minY + spot.origin.y), anchor: .topLeading, proposal: offer)
    }
}

/// The bar of the Mac and the iPad: it floats beside the chosen thing.
struct FloatingBar: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = BarDesk.shared

    /// The tools at the bottom keep this much of the board's room.
    static let toolsRoom: CGFloat = 64

    private var box: CGRect? {
        // Out of the way while the thing is dragged or typed in; it comes back afterwards.
        guard !desk.dragging, !session.readOnly, !session.linking, session.editing == nil, session.laneTyping == nil else { return nil }
        return session.chosenBox
    }

    var body: some View {
        if let box {
            BarSpot(box: box, bottom: FloatingBar.toolsRoom) {
                ChosenBar(session: session, wide: true)
                    .modifier(BoardShield("chosenBar"))
            }
        }
    }
}

/// The bar of the iPhone (and of a narrow iPad window): one row at the top, under the title bar.
/// `BoardView` shows it; on the Mac and a wide iPad it is nothing — the bar floats (`FloatingBar`).
struct ChosenBarTop: View {
    @ObservedObject var session: BoardSession
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact, !session.board.placesItself {
            ChosenBar(session: session, wide: false)
        }
    }
}

/// Everything of picks 7 and 18 that lies over the board's drawing: the frame round what is chosen
/// with its controls, the floating bar, and the press-and-hold menu. One line in `CanvasView`.
struct BoardExtras: View {
    @ObservedObject var session: BoardSession
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            ChosenLayer(session: session)
            if sizeClass != .compact { FloatingBar(session: session) }
            BoardMenuLayer(session: session)
        }
        .background(GeometryReader { geo in
            Color.clear.onChange(of: geo.frame(in: .global).origin, initial: true) { _, origin in BarDesk.shared.origin = origin }
        })
        .onChange(of: scheme, initial: true) { _, now in BoardMenu.night = now == .dark }
        .onAppear { BoardMenu.openForPicture(session) }
        .onDisappear {
            BarDesk.shared.dragging = false
            BarDesk.shared.hot = nil
            BarDesk.shared.menu = nil
            BarDesk.shared.pointer = nil
        }
    }
}
