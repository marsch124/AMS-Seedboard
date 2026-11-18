import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#endif

/// A timeline board: draws it, and turns presses, drags, pinches and keys into changes.
/// `BoardView` shows this instead of the free canvas when the board is a timeline; the top bar,
/// Undo and Send to PARAGON are the same as on every board.
struct TimelineView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var phase
    @FocusState private var typing: Bool
    @FocusState private var keys: Bool

    @State private var drag: Drag = .idle
    @State private var rubber: Rubber?
    @State private var dropTarget: UUID?
    /// A bar is being moved or stretched: its dates show over it.
    @State private var showDates = false
    @State private var pushed = 0
    @State private var lastTapAt = Date.distantPast
    @State private var lastTapID: UUID?
    @State private var pinchLast: CGFloat?
    /// A pinch began during this press: the rest of the press is not a drag or a tap.
    @State private var pinched = false
    @State private var pressing = false
    @State private var today = Day.today()
    @State private var launchApplied = false

    private struct Rubber { var from: CGPoint; var to: CGPoint }

    private enum Target { case bar(UUID), grip(UUID, BarEdge), dot(UUID), name(UUID), link(UUID), header, empty }

    private enum Drag {
        case idle
        case waiting(Target)
        /// The bars that move, the one under the finger, and the row it was in.
        case moving(Set<UUID>, UUID, Int)
        /// The bar, the end that is pulled, and the day that end was on.
        case stretching(UUID, BarEdge, Day)
        case joining(UUID)
        /// A row dragged up or down by its name, and the row it was in.
        case rowMove(UUID, Int)
        case panning(CGSize)
    }

    private var paint: Paint { Paint(scheme) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    var painter = TimelinePainter(board: session.board, paint: paint, geometry: session.timelineGeometry, size: size)
                    painter.today = today
                    painter.selection = session.selection
                    painter.selectedLink = session.selectedLink
                    painter.editing = session.editing
                    painter.handles = !session.readOnly && !session.linking
                    painter.linkFrom = session.linkFrom
                    painter.dropTarget = dropTarget
                    painter.rubber = rubber.map { ($0.from, $0.to) }
                    painter.showDates = showDates
                    painter.draw(&ctx)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
                #if !os(macOS)
                .simultaneousGesture(pinchGesture)
                #endif
                .accessibilityElement()
                .accessibilityIdentifier("timeline.canvas")
                .accessibilityLabel("Timeline")
                .accessibilityValue(session.board.countLine)

                // The count as words of its own, for the screen tests (too small and faint to see).
                Text(session.board.countLine)
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("board.count")

                if session.board.isEmpty {
                    VStack(spacing: 4) {
                        Text("An empty timeline")
                            .font(Txt.sectionTitle)
                        Text(session.readOnly ? "Nothing is on it yet." : "Press Bar below to start. Return on a bar adds the next one after it.")
                            .font(Txt.label)
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("timeline.empty")
                }

                editor
            }
            #if os(macOS)
            .background(ScrollCatcher(session: session))
            #endif
            .onAppear { place(geo.size) }
            .onChange(of: geo.size) { _, new in place(new) }
        }
        .clipped()
        .focusable()
        .focused($keys)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in handleKey(press) }
        // A press the system took away (an edge swipe, a call, leaving the app) never ends by itself.
        .onChange(of: phase) { _, _ in
            today = .today()
            resetPress()
        }
        .onDisappear { resetPress() }
        .onChange(of: session.editing, initial: true) { _, new in
            DispatchQueue.main.async {
                if new != nil { typing = true } else { keys = true }
            }
        }
    }

    /// The room for the timeline is known or has changed.
    private func place(_ size: CGSize) {
        session.timeline.narrow = sizeClass == .compact
        session.resized(size)
        session.clampTimeline()
        // For pictures: `-scale days|weeks|months` opens the timeline at that scale with today in view.
        guard !launchApplied, size.width > 10 else { return }
        launchApplied = true
        if let word = LaunchOptions.value(for: "-scale"), let scale = TimeScale(rawValue: word) {
            session.setTimeScale(scale)
            session.timelineShowToday()
        }
    }

    private func resetPress() {
        session.liveEnd(keep: true)
        drag = .idle
        rubber = nil
        dropTarget = nil
        showDates = false
        pinchLast = nil
        pinched = false
        pressing = false
    }

    // MARK: Typing a name in place

    @ViewBuilder
    private var editor: some View {
        if let id = session.editing, let item = session.board.item(id), let row = session.board.timelineRow(of: id) {
            let g = session.timelineGeometry
            let grouped = session.board.phaseGroups.contains { row > $0.firstRow && row <= $0.lastRow }
            let left = TimelinePainter.nameLeft(item, grouped: grouped) - 4
            let width = max(CGFloat(g.namesWidth) - left - 5, 40)
            TextField(item.kind.word, text: Binding(get: { session.draft }, set: { session.typed($0) }))
                .textFieldStyle(.plain)
                .font(.system(size: TimelineLook.nameSize, weight: item.kind == .phase ? .semibold : .regular))
                .foregroundStyle(paint.ink)
                .focused($typing)
                .id(id)
                .accessibilityIdentifier("board.field")
                .onSubmit { session.commitEdit() }
                .onKeyPress(.escape, phases: .down) { _ in
                    session.cancelEdit()
                    return .handled
                }
                .onKeyPress(.tab, phases: .down) { _ in
                    session.commitEdit()
                    return .handled
                }
                #if os(iOS)
                .submitLabel(.done)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { session.commitEdit() }
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("board.fieldDone")
                    }
                }
                #endif
                .padding(.horizontal, 4)
                .frame(width: width, height: CGFloat(g.rowHeight) - 8)
                .background(paint.plate, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(paint.chosen, lineWidth: 1.5))
                .position(x: left + width / 2, y: CGFloat(g.y(ofRow: row) + g.rowHeight / 2))
        }
    }

    // MARK: Presses and drags

    private var shiftDown: Bool {
        #if os(macOS)
        return NSEvent.modifierFlags.contains(.shift)
        #else
        return false
        #endif
    }

    private func box(_ item: Item, _ row: Int, _ g: TimelineGeometry) -> CGRect? {
        guard let span = item.span else { return nil }
        return item.kind == .milestone ? g.diamond(on: span.start, row: row) : g.bar(from: span.start, to: span.end, row: row)
    }

    private func target(at p: CGPoint) -> Target {
        let g = session.timelineGeometry
        let rows = session.board.timelineRows
        if p.y < g.headerHeight { return .header }
        let row = g.row(atY: p.y)
        if p.x < g.namesWidth {
            return rows.indices.contains(row) ? .name(rows[row].id) : .empty
        }
        // The grips and the dot of the one chosen bar come first.
        if !session.readOnly, session.editing == nil, !session.linking, let chosen = session.single,
           let at = rows.firstIndex(where: { $0.id == chosen.id }), let bar = box(chosen, at, g), abs(p.y - bar.midY) <= 14 {
            if chosen.kind == .bar {
                // On a short bar the grips are caught on their outer side, so its middle can still be moved.
                let inner = min(8, bar.width / 4)
                if p.x >= bar.maxX - inner, p.x <= bar.maxX + 9 { return .grip(chosen.id, .end) }
                if p.x >= bar.minX - 12, p.x <= bar.minX + inner { return .grip(chosen.id, .start) }
            }
            if abs(p.x - TimelinePainter.dot(of: bar).x) <= 11 { return .dot(chosen.id) }
        }
        for (n, item) in rows.enumerated() where abs(n - row) <= 1 {
            if let bar = box(item, n, g), bar.insetBy(dx: -4, dy: -5).contains(p) { return .bar(item.id) }
        }
        // A phase's own thin bar chooses the phase.
        if rows.indices.contains(row), rows[row].kind == .phase,
           let group = session.board.phaseGroups.first(where: { $0.id == rows[row].id }), let start = group.start, let end = group.end,
           g.bar(from: start, to: end, row: row).insetBy(dx: -4, dy: 0).contains(p) {
            return .name(rows[row].id)
        }
        let places = rows.enumerated().reduce(into: [UUID: CGRect]()) { $0[$1.element.id] = box($1.element, $1.offset, g) }
        for link in session.board.links.reversed() {
            guard let a = places[link.from], let b = places[link.to] else { continue }
            if Route.distance(from: p, to: g.arrow(from: a, to: b)) <= 7 { return .link(link.id) }
        }
        return .empty
    }

    /// The bar or milestone under the point (not `except`), for a pulled "comes after" line.
    private func bar(at p: CGPoint, except: UUID) -> UUID? {
        let g = session.timelineGeometry
        for (n, item) in session.board.timelineRows.enumerated() where item.id != except {
            if let bar = box(item, n, g), bar.insetBy(dx: -8, dy: -7).contains(p) { return item.id }
        }
        return nil
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                pressing = true
                guard !pinched else { return }
                switch drag {
                case .idle:
                    let t = target(at: value.startLocation)
                    // Pressing somewhere else ends the typing.
                    if session.editing != nil { session.commitEdit() }
                    switch t {
                    case .bar(let id), .name(let id):
                        if !session.linking, !session.selection.contains(id), !shiftDown, !session.choosingMore { session.select(id) }
                    default:
                        break
                    }
                    drag = .waiting(t)
                case .waiting(let t):
                    guard hypot(value.translation.width, value.translation.height) > 4 else { return }
                    begin(t)
                    update(value)
                default:
                    update(value)
                }
            }
            .onEnded { value in
                defer {
                    drag = .idle
                    rubber = nil
                    dropTarget = nil
                    showDates = false
                }
                pressing = false
                guard !pinched else {
                    session.liveEnd(keep: true)
                    if pinchLast == nil { pinched = false }
                    return
                }
                finish(value)
            }
    }

    private func begin(_ t: Target) {
        let board = session.board
        pushed = 0
        switch t {
        case .bar(let id):
            guard !session.readOnly else { drag = .panning(session.offset); return }
            if session.linking {
                drag = .joining(id)
            } else if let row = board.timelineRow(of: id) {
                let chosen = session.selection.contains(id) ? session.selection : [id]
                session.liveStart()
                showDates = chosen.count == 1
                drag = .moving(chosen, id, row)
            }
        case .grip(let id, let edge):
            guard let span = board.item(id)?.span else { drag = .idle; return }
            session.liveStart()
            showDates = true
            drag = .stretching(id, edge, edge == .start ? span.start : span.end)
        case .dot(let id):
            drag = .joining(id)
        case .name(let id):
            guard !session.readOnly, !session.linking, let row = board.timelineRow(of: id) else { drag = .panning(session.offset); return }
            session.liveStart()
            drag = .rowMove(id, row)
        case .link, .header, .empty:
            drag = .panning(session.offset)
        }
    }

    private func update(_ value: DragGesture.Value) {
        let g = session.timelineGeometry
        let across = g.days(forDrag: Double(value.translation.width))
        let down = Int((Double(value.translation.height) / g.rowHeight).rounded())
        switch drag {
        case .moving(let ids, let lead, let row):
            // A bar dragged sideways keeps its row until the finger is clearly (0.7 of a row) above or below it.
            let high = Double(value.translation.height)
            let rowsDown = Int(((abs(high) - 0.2 * g.rowHeight) / g.rowHeight).rounded()) * (high < 0 ? -1 : 1)
            var count = 0
            session.live { board in
                count = board.shift(ids, byDays: across)
                // One bar alone also changes its row when it is dragged up or down.
                if ids.count == 1, rowsDown != 0 { board.moveRow(lead, to: row + rowsDown) }
            }
            pushed = count
        case .stretching(let id, let edge, let from):
            var count = 0
            session.live { count = $0.stretch(id, edge, to: from + across) }
            pushed = count
        case .rowMove(let id, let row):
            session.live { $0.moveRow(id, to: row + down) }
        case .joining(let id):
            if let from = session.timelineRect(of: id) {
                rubber = Rubber(from: CGPoint(x: from.maxX, y: from.midY), to: value.location)
            }
            dropTarget = bar(at: value.location, except: id)
        case .panning(let base):
            session.slide(from: base, by: value.translation)
            session.clampTimeline()
        case .idle, .waiting:
            break
        }
    }

    private func finish(_ value: DragGesture.Value) {
        switch drag {
        case .waiting(let t):
            tap(t)
        case .moving, .stretching:
            session.liveEnd(keep: true)
            if let words = TimelineWords.pushed(pushed) { model.say(words) }
        case .rowMove:
            session.liveEnd(keep: true)
        case .joining(let id):
            // Dropped on nothing: nothing happens (the "comes after" tool stays on).
            if let over = dropTarget {
                join(over, after: id)
                session.linking = false
                session.linkFrom = nil
            }
        case .panning:
            // A step of zero: the timeline counts as moved by its owner.
            session.pan(by: .zero)
        case .idle:
            break
        }
    }

    private func join(_ follower: UUID, after forerunner: UUID) {
        if let words = session.timelineJoin(follower, after: forerunner) { model.say(words) }
    }

    private func tap(_ t: Target) {
        let now = Date()
        let double: (UUID?) -> Bool = { id in lastTapID == id && now.timeIntervalSince(lastTapAt) < 0.42 }
        switch t {
        case .grip:
            break
        case .dot(let id):
            // A press on the dot starts "comes after" from this bar: the next bar pressed is joined.
            session.linking = true
            session.linkFrom = id
        case .bar(let id), .name(let id):
            if session.linking {
                if let from = session.linkFrom, from != id {
                    join(id, after: from)
                    session.linking = false
                    session.linkFrom = nil
                } else if session.board.item(id)?.span != nil {
                    session.linkFrom = id
                }
            } else if double(id) {
                session.beginEdit(id)
            } else if shiftDown || session.choosingMore {
                session.select(id, adding: true)
            } else {
                session.select(id)
            }
            lastTapID = id
            lastTapAt = now
        case .link(let id):
            session.selection = []
            session.selectedLink = id
            lastTapID = id
            lastTapAt = now
        case .header, .empty:
            if session.linking {
                session.linking = false
                session.linkFrom = nil
            } else {
                session.clearSelection()
            }
            lastTapID = nil
            lastTapAt = now
        }
    }

    #if !os(macOS)
    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchLast == nil {
                    pinchLast = 1
                    pinched = true
                    // Whatever one finger had begun is settled as it stands.
                    session.liveEnd(keep: true)
                    drag = .idle
                    rubber = nil
                    dropTarget = nil
                    showDates = false
                }
                let ratio = value.magnification / max(pinchLast ?? 1, 0.01)
                pinchLast = value.magnification
                session.zoom(to: session.scale * ratio, around: value.startLocation)
            }
            .onEnded { _ in
                pinchLast = nil
                if !pressing { pinched = false }
            }
    }
    #endif

    // MARK: Keys

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard session.editing == nil else { return .ignored }
        let item = session.single
        if press.modifiers.contains(.command) {
            if press.characters == "a" { session.selectAll(); return .handled }
            return .ignored
        }
        let week = press.modifiers.contains(.shift)
        switch press.key {
        case .return:
            guard item != nil else { return .ignored }
            session.addBarAfterSelection()
            return .handled
        case .delete, .deleteForward:
            session.deleteSelection()
            return .handled
        case .escape:
            session.clearSelection()
            session.linking = false
            return .handled
        case .upArrow: session.timelineSelectRow(by: -1); return .handled
        case .downArrow: session.timelineSelectRow(by: 1); return .handled
        case .leftArrow, .rightArrow:
            guard !session.selection.isEmpty else { return .ignored }
            let count = session.timelineNudge(days: (press.key == .leftArrow ? -1 : 1) * (week ? 7 : 1))
            if let words = TimelineWords.pushed(count) { model.say(words) }
            return .handled
        case .space:
            if let item { session.beginEdit(item.id); return .handled }
            return .ignored
        default:
            break
        }
        guard !press.modifiers.contains(.control), !press.modifiers.contains(.option) else { return .ignored }
        let typed = press.characters
        guard let first = typed.unicodeScalars.first, typed.count == 1,
              !CharacterSet.controlCharacters.contains(first), first.value < 0xF700 || first.value > 0xF8FF else { return .ignored }
        if let item {
            // Just start typing: the words go on after what is there.
            session.beginEdit(item.id)
            session.typed(session.draft + typed)
            return .handled
        }
        if session.selectedLink == nil, session.selection.isEmpty {
            switch typed.lowercased() {
            case "b": session.addTimeline(.bar)
            case "m": session.addTimeline(.milestone)
            case "p": session.addTimeline(.phase)
            case "a": session.linking.toggle(); session.linkFrom = nil
            case "t": withAnimation(.easeOut(duration: 0.2)) { session.timelineShowToday() }
            default: return .ignored
            }
            return .handled
        }
        return .ignored
    }
}
