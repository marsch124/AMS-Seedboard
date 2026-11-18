import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#endif

/// The board itself: draws it, and turns presses, drags, pinches and keys into changes.
struct CanvasView: View {
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @FocusState private var typing: Bool
    @FocusState private var keys: Bool

    @State private var drag: Drag = .idle
    @State private var marquee: CGRect?
    @State private var rubber: Rubber?
    @State private var ghost: CGSize?
    @State private var dropTarget: UUID?
    @State private var lastTapAt = Date.distantPast
    @State private var lastTapID: UUID?
    @State private var pinchBase: CGFloat?
    /// A pinch began during this press: the rest of the press is not a drag or a tap.
    @State private var pinched = false
    @State private var pressing = false
    @State private var lastTapBare = false

    private struct Rubber { var from: CGPoint; var to: CGPoint }

    private enum Target { case item(UUID), link(UUID), plus(UUID, Direction), size(UUID), empty }

    private enum Drag {
        case idle
        case waiting(Target)
        case moving(Set<UUID>)
        case idea(UUID)
        case sizing(UUID, CGRect)
        case plus(UUID, Direction)
        case joining(UUID)
        case marquee
        case panning(CGSize)
    }

    private var paint: Paint { Paint(scheme) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paint.canvas))
                    var sheet = ctx
                    sheet.translateBy(x: session.offset.width, y: session.offset.height)
                    sheet.scaleBy(x: session.scale, y: session.scale)
                    var painter = BoardPainter(board: session.board, facts: session.facts, paint: paint)
                    painter.scale = session.scale
                    painter.selection = session.selection
                    painter.selectedLink = session.selectedLink
                    painter.editing = session.editing
                    painter.dropTarget = dropTarget
                    painter.handles = !session.readOnly
                    if case .idea(let id) = drag, let ghost { painter.ghost = (id, ghost) }
                    painter.draw(&sheet)
                    if let from = session.linkFrom, let item = session.board.item(from) {
                        let box = Path(roundedRect: item.frame.insetBy(dx: -6, dy: -5), cornerRadius: 9)
                        sheet.stroke(box, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 2.5 / session.scale, dash: [6 / session.scale, 4 / session.scale]))
                    }
                    if let rubber {
                        var line = Path()
                        line.move(to: rubber.from)
                        line.addLine(to: rubber.to)
                        sheet.stroke(line, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 2.2 / session.scale, lineCap: .round, dash: [7 / session.scale, 5 / session.scale]))
                    }
                    if let marquee {
                        let box = Path(roundedRect: marquee, cornerRadius: 3)
                        ctx.fill(box, with: .color(paint.chosen.opacity(0.10)))
                        ctx.stroke(box, with: .color(paint.chosen), lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
                #if !os(macOS)
                .simultaneousGesture(pinchGesture)
                #endif
                .accessibilityElement()
                .accessibilityIdentifier("board.canvas")
                .accessibilityLabel("Board")
                .accessibilityValue(session.board.countLine)

                // The count as words of its own, for the screen tests (too small and faint to see).
                Text(session.board.countLine)
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("board.count")

                editor
            }
            #if os(macOS)
            .background(ScrollCatcher(session: session))
            .onPasteCommand(of: [.plainText]) { providers in
                providers.first?.loadObject(ofClass: NSString.self) { text, _ in
                    guard let text = text as? String else { return }
                    Task { @MainActor in session.paste(text) }
                }
            }
            #endif
            .onAppear { session.placeIfNeeded(geo.size) }
            .onChange(of: geo.size) { _, new in session.resized(new) }
        }
        .clipped()
        .focusable()
        .focused($keys)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in handleKey(press) }
        // A press the system took away (an edge swipe, a call, leaving the app) never ends by itself.
        .onChange(of: phase) { _, _ in resetPress() }
        .onDisappear { resetPress() }
        .onChange(of: session.editing, initial: true) { _, new in
            DispatchQueue.main.async {
                if new != nil { typing = true } else { keys = true }
            }
        }
    }

    private func resetPress() {
        session.liveEnd(keep: true)
        drag = .idle
        marquee = nil
        rubber = nil
        ghost = nil
        dropTarget = nil
        pinchBase = nil
        pinched = false
        pressing = false
    }

    // MARK: Typing in place

    @ViewBuilder
    private var editor: some View {
        if let id = session.editing {
            if let item = session.board.item(id) {
                itemField(item)
            } else if let link = session.board.links.first(where: { $0.id == id }),
                      let a = session.board.item(link.from), let b = session.board.item(link.to) {
                let label = session.toScreen(Route.path(from: a.frame, to: b.frame, style: link.style).label)
                field(isIdea: false)
                    .font(.system(size: 13 * session.scale, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(width: 170)
                    .background(paint.plate, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(paint.chosen, lineWidth: 1.5))
                    .position(label)
            }
        }
    }

    private func field(isIdea: Bool) -> some View {
        TextField("", text: Binding(get: { session.draft }, set: { session.typed($0) }), axis: .vertical)
            .textFieldStyle(.plain)
            .foregroundStyle(paint.ink)
            .focused($typing)
            .id(session.editing)
            .accessibilityIdentifier("board.field")
            .onKeyPress(.return, phases: .down) { press in
                // Shift or Option with Return makes a new line; Return alone ends the typing.
                if press.modifiers.contains(.shift) || press.modifiers.contains(.option) { return .ignored }
                session.commitEdit(then: isIdea ? .sister : .nothing)
                return .handled
            }
            .onKeyPress(.tab, phases: .down) { _ in
                session.commitEdit(then: isIdea ? .child : .nothing)
                return .handled
            }
            .onKeyPress(.escape, phases: .down) { _ in
                session.cancelEdit()
                return .handled
            }
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { session.commitEdit() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("board.fieldDone")
                }
            }
            #endif
    }

    private func itemField(_ item: Item) -> some View {
        let s = session.scale
        let r = session.toScreen(item.frame)
        let depth = session.facts.depth[item.id] ?? 0
        let look = Lettering.style(for: item, depth: depth)
        let side = session.facts.side[item.id] ?? .right
        var align: Alignment = .center
        var textAlign: TextAlignment = .center
        var width = r.width
        var x = r.midX
        var pad: CGFloat = 4 * s
        var topPad: CGFloat = 0
        var darkInk = false
        switch item.kind {
        case .idea where depth > 0:
            width = r.width + 60 * s
            if side == .right {
                align = .leading; textAlign = .leading; x = r.minX + width / 2
            } else {
                align = .trailing; textAlign = .trailing; x = r.maxX - width / 2
            }
            pad = 3 * s
        case .text:
            width = r.width + 60 * s
            align = .leading; textAlign = .leading; x = r.minX + width / 2
            pad = 4 * s
        case .note:
            align = .topLeading; textAlign = .leading
            pad = 10 * s; topPad = 10 * s
            darkInk = !paint.night
        case .frame:
            align = .topLeading; textAlign = .leading
            pad = 12 * s; topPad = 6 * s
        case .diamond:
            pad = r.width * 0.22
        case .oval:
            pad = r.width * 0.14
        default:
            pad = 12 * s
        }
        let size = item.kind == .frame ? 13 : look.size
        return field(isIdea: item.kind == .idea)
            .font(Lettering.font(size: size * s, bold: look.bold))
            .multilineTextAlignment(textAlign)
            .foregroundStyle(item.kind == .frame ? paint.line(item.colour.isEmpty ? "teal" : item.colour)
                             : (darkInk ? Color(red: 0.12, green: 0.14, blue: 0.19) : paint.ink))
            .padding(.horizontal, pad)
            .padding(.top, topPad)
            .frame(width: max(width, 40), height: max(r.height, 20), alignment: align)
            .position(x: x, y: r.midY)
    }

    // MARK: Presses and drags

    private var shiftDown: Bool {
        #if os(macOS)
        return NSEvent.modifierFlags.contains(.shift)
        #else
        return false
        #endif
    }

    private func target(at p: CGPoint) -> Target {
        let board = session.board
        if !session.readOnly, session.editing == nil, session.selection.count == 1,
           let id = session.selection.first, let item = board.item(id), !session.linking {
            let slack = 9 / session.scale
            for handle in BoardPainter.handles(for: item, side: session.facts.side[id] ?? .right, scale: session.scale) {
                if handle.rect.insetBy(dx: -slack, dy: -slack).contains(p) {
                    switch handle.kind {
                    case .plus(let d): return .plus(id, d)
                    case .size: return .size(id)
                    }
                }
            }
        }
        if let id = board.hit(p) { return .item(id) }
        if let id = board.hitLink(p, within: Double(9 / session.scale)) { return .link(id) }
        return .empty
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                pressing = true
                guard !pinched else { return }
                switch drag {
                case .idle:
                    let t = target(at: session.toBoard(value.startLocation))
                    // Pressing somewhere else ends the typing.
                    if session.editing != nil { session.commitEdit() }
                    if case .item(let id) = t, !session.linking, !session.selection.contains(id), !shiftDown, !session.choosingMore {
                        session.select(id)
                    }
                    drag = .waiting(t)
                case .waiting(let t):
                    guard hypot(value.translation.width, value.translation.height) > 4 else { return }
                    begin(t, value)
                    update(value)
                default:
                    update(value)
                }
            }
            .onEnded { value in
                defer {
                    drag = .idle
                    marquee = nil
                    rubber = nil
                    ghost = nil
                    dropTarget = nil
                }
                pressing = false
                guard !pinched else {
                    session.liveEnd(keep: true)
                    if pinchBase == nil { pinched = false }
                    return
                }
                finish(value)
            }
    }

    private func begin(_ t: Target, _ value: DragGesture.Value) {
        let board = session.board
        switch t {
        case .item(let id):
            guard !session.readOnly else { drag = .panning(session.offset); return }
            if session.linking {
                drag = .joining(id)
            } else if let item = board.item(id), item.kind == .idea, item.parent != nil {
                drag = .idea(id)
            } else {
                let chosen = session.selection.contains(id) ? session.selection : [id]
                session.liveStart()
                drag = .moving(board.carried(by: chosen))
            }
        case .plus(let id, let d):
            drag = .plus(id, d)
        case .size(let id):
            guard let item = board.item(id) else { drag = .idle; return }
            session.liveStart()
            drag = .sizing(id, item.frame)
        case .link, .empty:
            #if os(macOS)
            drag = .marquee
            #else
            drag = .panning(session.offset)
            #endif
        }
    }

    private func update(_ value: DragGesture.Value) {
        let s = session.scale
        let delta = CGSize(width: value.translation.width / s, height: value.translation.height / s)
        let here = session.toBoard(value.location)
        switch drag {
        case .moving(let ids):
            session.live { $0.move(ids, by: delta) }
        case .idea(let id):
            ghost = delta
            if let over = session.board.hit(here), over != id, session.board.item(over)?.kind == .idea,
               !session.board.descendants(of: id).contains(over) {
                dropTarget = over
            } else {
                dropTarget = nil
            }
        case .sizing(let id, let base):
            session.live { $0.resize(id, to: CGRect(x: base.minX, y: base.minY, width: base.width + delta.width, height: base.height + delta.height)) }
        case .plus(let id, _), .joining(let id):
            if let item = session.board.item(id) { rubber = Rubber(from: item.centre, to: here) }
        case .marquee:
            let a = value.startLocation, b = value.location
            let box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            marquee = box
            let p0 = session.toBoard(box.origin)
            session.selectedLink = nil
            session.selection = session.board.items(in: CGRect(x: p0.x, y: p0.y, width: box.width / s, height: box.height / s))
        case .panning(let base):
            session.offset = CGSize(width: base.width + value.translation.width, height: base.height + value.translation.height)
        case .idle, .waiting:
            break
        }
    }

    private func finish(_ value: DragGesture.Value) {
        let here = session.toBoard(value.location)
        switch drag {
        case .waiting(let t):
            tap(t, at: here)
        case .moving, .sizing:
            session.liveEnd(keep: true)
        case .idea(let id):
            if let over = dropTarget {
                session.change { $0.reparent(id, under: over) }
            } else if hypot(value.translation.width, value.translation.height) > 50 {
                session.change { $0.detach(id, at: here) }
            }
        case .plus(let id, let d):
            guard let item = session.board.item(id) else { return }
            if item.kind == .idea {
                session.addChild(of: id)
            } else if let over = session.board.hit(here), over != id, session.board.item(over)?.kind != .frame {
                session.join(id, over)
            } else {
                // Dropped on empty board: the next shape appears there, already joined.
                var made: UUID?
                session.change { board in
                    let new = board.add(item.kind, centre: here, colour: item.colour)
                    board.link(from: id, to: new)
                    made = new
                }
                if let made { session.beginEdit(made, isNew: true) }
            }
        case .joining(let id):
            // Dropped on a frame (it takes no arrows) or on nothing: the arrow tool stays on.
            if let over = session.board.hit(here), over != id, session.board.item(over)?.kind != .frame {
                session.join(id, over)
                session.linking = false
                session.linkFrom = nil
            }
        case .marquee, .panning, .idle:
            break
        }
    }

    private func tap(_ t: Target, at p: CGPoint) {
        let now = Date()
        let double: (UUID?) -> Bool = { id in lastTapID == id && now.timeIntervalSince(lastTapAt) < 0.42 }
        switch t {
        case .plus(let id, let d):
            if session.board.item(id)?.kind == .idea { session.addChild(of: id) } else { session.addNext(from: id, direction: d) }
        case .size:
            break
        case .item(let id):
            if session.linking {
                if session.board.item(id)?.kind == .frame {
                    // A frame takes no arrows: the press is passed over, the arrow tool stays on.
                } else if let from = session.linkFrom, from != id {
                    session.join(from, id)
                    session.linking = false
                    session.linkFrom = nil
                } else if session.board.item(id)?.kind != .frame {
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
            if double(id) {
                session.beginEdit(id)
            } else {
                session.selection = []
                session.selectedLink = id
            }
            lastTapID = id
            lastTapAt = now
        case .empty:
            if session.linking {
                session.linking = false
                session.linkFrom = nil
            } else if double(nil), lastTapBare, session.selection.isEmpty, session.selectedLink == nil {
                // Two presses on empty board (with nothing chosen before the first): a sticky note right there.
                session.add(.note, at: p)
                lastTapAt = .distantPast
                lastTapBare = false
                return
            } else {
                lastTapBare = session.selection.isEmpty && session.selectedLink == nil
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
                if pinchBase == nil {
                    pinchBase = session.scale
                    pinched = true
                    // Whatever one finger had begun is settled as it stands.
                    session.liveEnd(keep: true)
                    drag = .idle
                    marquee = nil
                    rubber = nil
                    ghost = nil
                    dropTarget = nil
                }
                session.zoom(to: (pinchBase ?? 1) * value.magnification, around: value.startLocation)
            }
            .onEnded { _ in
                pinchBase = nil
                if !pressing { pinched = false }
            }
    }
    #endif

    // MARK: Keys

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard session.editing == nil else { return .ignored }
        let command = press.modifiers.contains(.command)
        let item = session.single
        if command {
            if press.characters == "a" { session.selectAll(); return .handled }
            return .ignored
        }
        switch press.key {
        case .tab:
            if let item, item.kind == .idea { session.addChild(of: item.id); return .handled }
            return .ignored
        case .return:
            if let item {
                if item.kind == .idea { session.addSister(of: item.id) } else { session.beginEdit(item.id) }
                return .handled
            }
            if let link = session.selectedLink { session.beginEdit(link); return .handled }
            return .ignored
        case .delete, .deleteForward:
            session.deleteSelection()
            return .handled
        case .escape:
            session.clearSelection()
            session.linking = false
            return .handled
        case .upArrow: session.arrow(.up, big: press.modifiers.contains(.shift)); return .handled
        case .downArrow: session.arrow(.down, big: press.modifiers.contains(.shift)); return .handled
        case .leftArrow: session.arrow(.left, big: press.modifiers.contains(.shift)); return .handled
        case .rightArrow: session.arrow(.right, big: press.modifiers.contains(.shift)); return .handled
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
        if session.selectedLink == nil {
            switch typed.lowercased() {
            case "m": session.add(.idea)
            case "b", "r": session.add(.box)
            case "u": session.add(.round)
            case "d": session.add(.diamond)
            case "o": session.add(.oval)
            case "n": session.add(.note)
            case "t": session.add(.text)
            case "f": session.add(.frame)
            case "a", "l": session.linking.toggle(); session.linkFrom = nil
            default: return .ignored
            }
            return .handled
        }
        return .ignored
    }
}

#if os(macOS)
/// The Mac's two-finger scroll moves the board, a pinch (or ⌘ with scrolling) zooms it.
struct ScrollCatcher: NSViewRepresentable {
    let session: BoardSession

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.session = session
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) { view.session = session }

    final class CatcherView: NSView {
        weak var session: BoardSession?
        private var monitor: Any?

        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, let window = self.window, event.window === window, let session = self.session else { return event }
                let p = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(p) else { return event }
                MainActor.assumeIsolated {
                    if event.type == .magnify {
                        session.zoom(to: session.scale * (1 + event.magnification), around: p)
                    } else if event.modifierFlags.contains(.command) {
                        session.zoom(to: session.scale * exp(min(max(event.scrollingDeltaY, -60), 60) * 0.01), around: p)
                    } else {
                        let k: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
                        session.pan(by: CGSize(width: event.scrollingDeltaX * k, height: event.scrollingDeltaY * k))
                    }
                }
                return nil
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
#endif
