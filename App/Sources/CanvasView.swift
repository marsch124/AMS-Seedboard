import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
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
    /// iPhone and iPad: what kind of press is going on, and what was chosen before it landed.
    @State private var notes = PressNotes()
    @State private var lastTapBare = false
    /// When the press began: on a touch screen an idea lifts only after a short hold.
    @State private var pressBegan = Date.distantPast
    /// The middle idea of the one map being dragged: it may be dropped on an idea of another map.
    @State private var hanging: UUID?
    /// Where the idea being dragged will land among its sisters: a thin line is drawn there.
    @State private var landing: Landing?

    /// Shift and Tab arrives as its own key on the Mac.
    private static let backTab = KeyEquivalent("\u{19}")
    /// How long a finger must rest on an idea before it lifts.
    private static let hold: TimeInterval = 0.25
    /// The guide lines while a drag catches (pick 11).
    @State private var snap = SnapShow()

    private struct Rubber { var from: CGPoint; var to: CGPoint }

    private enum Target {
        case item(UUID), link(UUID), plus(UUID, Direction), size(UUID), empty
        /// An end dot of the chosen arrow (true: its start).
        case end(UUID, Bool)
    }

    private enum Drag {
        case idle
        case waiting(Target)
        case moving(Set<UUID>)
        case idea(UUID)
        case sizing(UUID, CGRect)
        case plus(UUID, Direction)
        case joining(UUID)
        /// An end of an arrow is dragged to another side or another shape (true: its start).
        case end(UUID, Bool)
        case marquee
        case panning(CGSize)
    }

    private var paint: Paint { Paint(scheme) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paint.canvas))
                    SnapShow.grid(ctx, size: size, offset: session.offset, scale: session.scale, paint: paint)
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
                    painter.frames = snap.frames(for: session)
                    if case .idea(let id) = drag, let ghost { painter.ghost = (id, ghost) }
                    painter.draw(&sheet)
                    snap.shown(for: session).draw(sheet, paint: paint, scale: session.scale)
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
                    if case .idea = drag, let landing { landing.draw(&sheet, colour: paint.chosen, scale: session.scale) }
                    if let marquee {
                        let box = Path(roundedRect: marquee, cornerRadius: 3)
                        ctx.fill(box, with: .color(paint.chosen.opacity(0.10)))
                        ctx.stroke(box, with: .color(paint.chosen), lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
                #if os(macOS)
                .gesture(dragGesture)
                #else
                // iPhone and iPad: Apple's own recognisers lie over the drawing (TouchLayer.swift).
                .overlay(touchLayer)
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
                IdeaPlaceMark(session: session)

                editor
                LaneOverlay(session: session)
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
        // The menus' side of the keys: Delete, Select All, Space with a drag (Menus.swift).
        .modifier(BoardKeys(session: session, has: keys))
        // A press the system took away (an edge swipe, a call, leaving the app) never ends by itself.
        .onChange(of: phase) { _, _ in resetPress() }
        .onDisappear { resetPress() }
        .onChange(of: session.editing, initial: true) { _, new in
            session.typing(in: new)
            DispatchQueue.main.async {
                if new != nil { typing = true } else { keys = true }
            }
        }
        // After a button, a menu or a page the board takes the keys back, so the letter keys,
        // the arrow keys and the Board menu's keys go on working.
        .onReceive(session.keysWanted) { _ in
            DispatchQueue.main.async {
                if session.editing == nil { keys = true }
            }
        }
    }

    private func resetPress() {
        session.liveEnd(keep: true)
        drag = .idle
        snap = SnapShow()
        marquee = nil
        rubber = nil
        ghost = nil
        dropTarget = nil
        hanging = nil
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
            } else if let spot = session.wordsField(for: id) {
                // An arrow's words: typed where they stand, beside the line near its start.
                field(isIdea: false)
                    .font(.system(size: 13 * session.scale, weight: .medium))
                    .multilineTextAlignment(spot.leading ? .leading : .trailing)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(width: 170)
                    .background(paint.plate, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(paint.chosen, lineWidth: 1.5))
                    .position(spot.centre)
            }
        }
    }

    private func field(isIdea: Bool) -> some View {
        TextField("", text: Binding(get: { session.draft }, set: { session.typed($0) }), axis: .vertical)
            .textFieldStyle(.plain)
            // A flow shape: Tab (or ⌘ with an arrow key) makes the next shape. Everything else passes on.
            .onKeyPress(keys: [.tab, .rightArrow, .leftArrow, .downArrow, .upArrow], phases: .down) { press in
                session.flowKey(press) ? .handled : .ignored
            }
            .foregroundStyle(paint.ink)
            .focused($typing)
            .id(fieldIdentity(isIdea: isIdea))
            .accessibilityIdentifier("board.field")
            .onKeyPress(.return, phases: .down) { press in
                // Shift or Option with Return makes a new line (in an idea too); Return alone ends the typing.
                if press.modifiers.contains(.shift) || press.modifiers.contains(.option) {
                    session.wantLineBreak()
                    return .ignored
                }
                session.commitEdit(then: isIdea ? .sister : .nothing)
                return .handled
            }
            .onKeyPress(keys: [.tab, Self.backTab], phases: .down) { press in
                if press.modifiers.contains(.shift) || press.key == Self.backTab {
                    // Shift and Tab: the idea moves out one level, and the typing goes on.
                    if isIdea, let id = session.editing { session.moveOut(id) }
                    return .handled
                }
                session.commitEdit(then: isIdea ? .child : .nothing)
                return .handled
            }
            .onKeyPress(.escape, phases: .down) { _ in
                session.cancelEdit()
                return .handled
            }
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { keyboardBar(isIdea: isIdea) }
            }
            #endif
    }

    private func itemField(_ item: Item) -> some View {
        let s = session.scale
        let r = session.toScreen(item.typingFrame)
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
            darkInk = true   // a note is bright paper by night too
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
        return notes.shift
        #endif
    }

    /// A finger is pressing (not a mouse, a trackpad or the Pencil): press areas are finger size.
    private var byFinger: Bool { Finger.on && !notes.precise }

    private func target(at p: CGPoint) -> Target {
        if let end = session.linkEnd(at: p) { return .end(end.link, end.start) }
        let board = session.board
        if !session.readOnly, session.editing == nil, session.selection.count == 1,
           let id = session.selection.first, let item = board.item(id), !session.linking {
            // Press areas are counted on screen: 9 points round each control, for a finger at least
            // 32 points at every zoom; the nearest control wins.
            let handles = BoardPainter.handles(for: item, side: session.facts.side[id] ?? .right, scale: session.scale)
            if let i = Fingers.control(at: session.toScreen(p), boxes: handles.map { session.toScreen($0.rect) },
                                       onThing: board.hit(p) != nil, least: byFinger ? Fingers.control : 0) {
                switch handles[i].kind {
                case .plus(let d): return .plus(id, d)
                case .size: return .size(id)
                }
            }
        }
        if let id = board.hit(p, scale: Double(session.scale), least: byFinger ? Fingers.button : 0) { return .item(id) }
        if let id = board.hitLink(p, within: Double(9 / session.scale)) { return .link(id) }
        return .empty
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { pressMoved(Press($0)) }
            .onEnded { pressEnded(Press($0)) }
    }

    /// A press landed or moved: the Mac's click and drag, or TouchLayer's finger, Pencil or pointer.
    private func pressMoved(_ value: Press) {
                pressing = true
                guard !pinched else { return }
                switch drag {
                case .idle:
                    let t = target(at: session.toBoard(value.startLocation))
                    pressBegan = value.time
                    // Pressing somewhere else ends the typing.
                    if session.editing != nil { session.commitEdit() }
                    // Every press on the board gives it the keys.
                    keys = true
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

    /// The press was lifted.
    private func pressEnded(_ value: Press) {
                defer {
                    snap = SnapShow()
                    drag = .idle
                    marquee = nil
                    rubber = nil
                    ghost = nil
                    dropTarget = nil
                    hanging = nil
                }
                pressing = false
                guard !pinched else {
                    session.liveEnd(keep: true)
                    if pinchBase == nil { pinched = false }
                    return
                }
                finish(value)
    }

    private func begin(_ t: Target, _ value: Press) {
        let board = session.board
        switch t {
        case .item(let id):
            guard !session.readOnly else { drag = .panning(session.offset); return }
            if session.linking {
                drag = .joining(id)
            } else if let item = board.item(id), item.kind == .idea, item.parent != nil {
                #if os(iOS)
                // A slide that starts on an idea moves the view. The idea lifts only after a short hold,
                // so it is never torn off its map by accident.
                guard value.precise || value.time.timeIntervalSince(pressBegan) >= Self.hold else {
                    drag = .panning(session.offset)
                    return
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                drag = .idea(id)
            } else {
                let chosen = session.selection.contains(id) ? session.selection : [id]
                session.liveStart()
                drag = .moving(board.carried(by: chosen))
                // One map dragged by its middle idea can be dropped on an idea of another map.
                if let item = board.item(id), item.kind == .idea, item.parent == nil, chosen.count == 1 { hanging = id }
            }
        case .plus(let id, let d):
            drag = .plus(id, d)
        case .size(let id):
            guard let item = board.item(id) else { drag = .idle; return }
            session.liveStart()
            drag = .sizing(id, item.frame)
        case .end(let id, let start):
            drag = .end(id, start)
        case .link, .empty:
            #if os(macOS)
            drag = .marquee
            #else
            // A mouse or a trackpad draws the choosing box, as on the Mac; a finger slides the board.
            drag = value.pointer ? .marquee : .panning(session.offset)
            #endif
        }
    }

    private func update(_ value: Press) {
        let s = session.scale
        let delta = CGSize(width: value.translation.width / s, height: value.translation.height / s)
        let here = session.toBoard(value.location)
        switch drag {
        case .moving(let ids):
            snap.guides = session.liveMove(ids, by: delta, reach: SnapShow.reach(s))
            snap.over = session.board.spots(ofDragged: ids)
            if hanging != nil { dropTarget = session.board.idea(at: here, notIn: ids) }
        case .idea(let id):
            ghost = delta
            // The idea it would hang under gets a ring; a place between two sisters gets a thin line.
            (dropTarget, landing) = session.dropHints(for: id, at: here)
        case .sizing(let id, let base):
            snap.guides = session.liveResize(id, to: CGRect(x: base.minX, y: base.minY, width: base.width + delta.width, height: base.height + delta.height), reach: SnapShow.reach(s))
        case .plus(let id, _):
            // The new shape lands in line with its neighbours: the outline and the guides show where.
            let land = session.board.landing(from: id, at: here, reach: SnapShow.reach(s))
            snap = SnapShow(guides: land?.guides ?? [], landing: land?.frame)
            if let item = session.board.item(id) { rubber = Rubber(from: item.centre, to: land?.centre ?? here) }
        case .joining(let id):
            if let item = session.board.item(id) { rubber = Rubber(from: item.centre, to: here) }
        case .marquee:
            let a = value.startLocation, b = value.location
            let box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            marquee = box
            let p0 = session.toBoard(box.origin)
            session.selectedLink = nil
            session.selection = session.board.items(in: CGRect(x: p0.x, y: p0.y, width: box.width / s, height: box.height / s))
        case .panning(let base):
            // The same step as every other way of moving the view, so the board knows the owner moved it.
            session.slide(from: base, by: value.translation)
        case .end(let id, let start):
            // A dashed line from the end that stays; the shape the end would land on lights up.
            let pull = session.endPull(id, start: start, to: here)
            rubber = pull.map { Rubber(from: $0.from, to: here) }
            dropTarget = pull?.over
        case .idle, .waiting:
            break
        }
    }

    private func finish(_ value: Press) {
        let here = session.toBoard(value.location)
        switch drag {
        case .waiting(let t):
            tap(t, at: here)
        case .moving:
            if let centre = hanging, let over = dropTarget {
                // Dropped on an idea of another map: the map goes back to where it was and hangs there.
                session.liveEnd(keep: false)
                session.hang(centre, under: over)
            } else {
                session.liveEnd(keep: true)
            }
        case .sizing:
            session.liveEnd(keep: true)
        case .idea(let id):
            session.dropIdea(id, at: here)
        case .plus(let id, let d):
            guard let item = session.board.item(id) else { return }
            if item.kind == .idea {
                session.addChild(of: id)
            } else if let over = session.board.hit(here), over != id, session.board.item(over)?.kind != .frame {
                session.join(id, over)
            } else {
                // Dropped on empty board: the next shape appears there, already joined.
                var made: UUID?
                let spot = session.board.landing(from: id, at: here, reach: SnapShow.reach(session.scale))?.centre ?? here
                session.change { board in
                    let kind = item.kind.nextInFlow
                    let new = board.add(kind, centre: spot, colour: kind == item.kind ? item.colour : "")
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
        case .end(let id, let start):
            session.moveLinkEnd(id, start: start, to: here)
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
        case .size, .end:
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
            } else if double(id), session.beginLaneName(of: id, at: p) {
                // Two presses on a lane's name band: its name is typed in place (LanesView.swift).
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
            } else if Finger.twoPressesFit, double(nil) {
                // iPhone and iPad: two presses on empty board show the whole board (the Mac makes a sticky note).
                withAnimation(.easeOut(duration: 0.2)) { session.fit() }
                lastTapAt = .distantPast
                return
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

    #if os(iOS)
    // MARK: iPhone and iPad (TouchLayer.swift)

    /// Apple's own recognisers over the drawing. One finger, the Pencil or the pointer comes back
    /// here as a press; two fingers, scrolling and a trackpad's pinch move the view by themselves.
    private var touchLayer: some View {
        // Pencil drawing plugs in here: `ink:` (see InkHook).
        TouchLayer(session: session, onPress: { phase, value in
            notes.shift = value.shift
            notes.precise = value.precise
            switch phase {
            case .began:
                notes.selection = session.selection
                notes.link = session.selectedLink
                pressMoved(value)
            case .moved:
                pressMoved(value)
            case .ended:
                pressEnded(value)
            case .lost(let takeBack):
                pressLost(value, takeBack: takeBack)
            }
        })
    }

    /// The press was taken away. By a second finger (or the page's edge swipe): two fingers only ever
    /// slide and zoom the board, so a small shove of a thing is taken back without an undo step, and
    /// what was chosen before is chosen again. Otherwise things stay as they stand.
    private func pressLost(_ value: Press, takeBack: Bool) {
        if takeBack {
            var kept = false
            switch drag {
            case .moving, .sizing:
                kept = !Fingers.isShove(moved: Double(hypot(value.translation.width, value.translation.height)),
                                        after: value.time.timeIntervalSince(pressBegan))
                session.liveEnd(keep: kept)
            default:
                break
            }
            if !kept {
                session.selection = notes.selection.filter { session.board.item($0) != nil }
                session.selectedLink = notes.link.flatMap { id in session.board.links.contains { $0.id == id } ? id : nil }
            }
        }
        resetPress()
    }
    #endif

    // MARK: Keys

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard session.editing == nil else { return .ignored }
        // A flow shape: Tab (or ⌘ with an arrow key) makes the next shape.
        if session.flowKey(press) { return .handled }
        let command = press.modifiers.contains(.command)
        let item = session.single
        if command {
            if press.characters == "a" { session.selectAll(); return .handled }
            // ⌘↑ and ⌘↓: the chosen idea goes one place up or down among its sisters.
            if press.key == .upArrow || press.key == .downArrow, let item, item.kind == .idea {
                session.shiftIdea(item.id, down: press.key == .downArrow)
                return .handled
            }
            return .ignored
        }
        switch press.key {
        case .tab, Self.backTab:
            if let item, item.kind == .idea {
                // Tab: an idea under this one. Shift and Tab: this idea moves out one level.
                if press.modifiers.contains(.shift) || press.key == Self.backTab {
                    session.moveOut(item.id)
                } else {
                    session.addChild(of: item.id)
                }
                return .handled
            }
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
