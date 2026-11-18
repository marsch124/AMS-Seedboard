import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A "Who does what" board: draws it, and turns presses, drags, pinches and keys into changes.
/// `BoardView` shows this instead of the free canvas when the board is a sequence; the top bar,
/// Undo, the zoom buttons and Send to PARAGON are the same as on every board.
struct SequenceView: View {
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @FocusState private var typing: Bool
    @FocusState private var keys: Bool

    @State private var drag: Drag = .idle
    @State private var rubber: Rubber?
    /// The name a pulled line would land on.
    @State private var dropWho: UUID?
    /// Where a pulled message, a dragged step or a dragged name will land: a thin line is drawn there.
    @State private var landing: Landing?
    /// How far the step or the name being dragged is from its place.
    @State private var lifted: CGSize?
    /// A pull: how far it has been from its own dashed line, in screen points (a loop back makes a message to itself).
    @State private var farthest: CGFloat = 0
    @State private var lastTapAt = Date.distantPast
    @State private var lastTapID: UUID?
    @State private var pinchBase: CGFloat?
    /// A pinch began during this press: the rest of the press is not a drag or a tap.
    @State private var pinched = false
    @State private var pressing = false
    /// When the press began: on a touch screen a message lifts only after a short hold.
    @State private var pressBegan = Date.distantPast

    /// How long a finger must rest on a message before it lifts.
    private static let hold: TimeInterval = 0.25

    private struct Rubber { var from: CGPoint; var to: CGPoint }

    private enum Target { case who(UUID), step(UUID), line(UUID), empty }

    private enum Drag {
        case idle
        case waiting(Target)
        /// A message is pulled from this name's dashed line.
        case pulling(UUID)
        /// A step is dragged up or down to another place in the order.
        case lifting(UUID)
        /// A name is dragged sideways to another place in the row.
        case carrying(UUID)
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
                    var painter = SequencePainter(board: session.board, paint: paint)
                    painter.scale = session.scale
                    painter.selection = session.selection
                    painter.editing = session.editing
                    let corner = session.toBoard(.zero)
                    painter.visible = CGRect(x: corner.x, y: corner.y, width: size.width / session.scale, height: size.height / session.scale)
                    painter.pinInset = session.sequencePinInset
                    painter.linkFrom = session.linking ? session.linkFrom : nil
                    painter.dropWho = dropWho
                    painter.rubber = rubber.map { ($0.from, $0.to) }
                    switch drag {
                    case .lifting(let id), .carrying(let id):
                        if let lifted { painter.lifted = (id, lifted) }
                    default:
                        break
                    }
                    painter.draw(&sheet)
                    if let landing { landing.draw(&sheet, colour: paint.chosen, scale: session.scale) }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
                #if !os(macOS)
                .simultaneousGesture(pinchGesture)
                #endif
                .accessibilityElement()
                .accessibilityIdentifier("sequence.canvas")
                .accessibilityLabel("Who does what")
                .accessibilityValue(session.board.countLine)

                // The count and the chosen thing as words of their own, for the screen tests (too small and faint to see).
                Text(session.board.countLine)
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("board.count")
                Text(session.sequenceChosenLine)
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .offset(x: 3)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("sequence.chosen")

                if session.board.isEmpty {
                    VStack(spacing: 4) {
                        Text("Nobody here yet")
                            .font(Txt.sectionTitle)
                        Text(session.readOnly ? "Nothing is on it yet."
                             : "Press Who below and type a name; Tab adds the next one. Then pull from one dashed line to another for a message.")
                            .font(Txt.label)
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("sequence.empty")
                }

                editor
            }
            #if os(macOS)
            .background(ScrollCatcher(session: session))
            #else
            .background(TrackpadCatcher(session: session))
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
        // After a button, a menu or a page the board takes the keys back.
        .onReceive(session.keysWanted) { _ in
            DispatchQueue.main.async {
                if session.editing == nil { keys = true }
            }
        }
    }

    private func resetPress() {
        drag = .idle
        rubber = nil
        dropWho = nil
        landing = nil
        lifted = nil
        pinchBase = nil
        pinched = false
        pressing = false
    }

    // MARK: Typing in place

    @ViewBuilder
    private var editor: some View {
        if let id = session.editing, let item = session.board.item(id), item.kind.isSequence {
            let layout = session.sequenceLayout
            let s = session.scale
            let look = SequenceLook.style(item.kind)
            let line = CGFloat(layout.metrics.lineHeight)
            if item.kind == .who, let box = layout.boxes[id] {
                // A name: typed inside its own box.
                let r = session.toScreen(box.offsetBy(dx: 0, dy: session.sequenceShift(layout)))
                field(item)
                    .font(.system(size: look.size * s, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: max(r.width - 10 * s, 60), height: r.height)
                    .position(x: r.midX, y: r.midY)
            } else if let row = layout.row(id) {
                // Words: typed where they stand, on a small plate.
                let words = session.toScreen(row.words)
                let leading = row.loop || item.kind == .section
                let width = max(words.width + 70 * s, 150 * s)
                field(item)
                    .font(.system(size: look.size * s, weight: look.bold ? .semibold : .regular))
                    .multilineTextAlignment(leading ? .leading : .center)
                    .padding(.horizontal, 5 * s)
                    .frame(width: width, height: line * s + 8 * s)
                    .background(paint.plate, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(paint.chosen, lineWidth: 1.5))
                    .position(x: leading ? words.minX - 5 * s + width / 2 : words.midX, y: words.midY)
            }
        }
    }

    private func field(_ item: Item) -> some View {
        TextField(SequenceLook.placeholder(item.kind), text: Binding(get: { session.draft }, set: { session.typed($0) }))
            .textFieldStyle(.plain)
            .foregroundStyle(paint.ink)
            .focused($typing)
            .id(item.id)
            .accessibilityIdentifier("board.field")
            .onSubmit { session.commitEdit() }
            .onKeyPress(.escape, phases: .down) { _ in
                session.cancelEdit()
                return .handled
            }
            .onKeyPress(.tab, phases: .down) { _ in
                next(after: item)
                return .handled
            }
            #if os(iOS)
            .submitLabel(.done)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if item.kind == .who {
                        Button("Next name") { next(after: item) }
                            .accessibilityIdentifier("board.key.nextWho")
                    } else if item.kind == .message {
                        Button("Next message") { next(after: item) }
                            .accessibilityIdentifier("board.key.nextMessage")
                    }
                    Spacer()
                    Button("Done") { session.commitEdit() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("board.fieldDone")
                }
            }
            #endif
    }

    /// Tab while typing: after a name the next name, after a message the next message under it
    /// (going the other way); anything else just ends the typing.
    private func next(after item: Item) {
        switch item.kind {
        case .who:
            session.nextWhoAfterTyping()
        case .message:
            session.commitEdit()
            session.addNextMessage(after: item.id)
        default:
            session.commitEdit()
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

    /// What lies under a point of the board: a name box first, then the words of a step, then a
    /// dashed line (so a message can always be pulled from it), then the arrow of a message.
    private func target(at p: CGPoint) -> Target {
        let layout = session.sequenceLayout
        let s = max(session.scale, 0.05)
        let down = session.sequenceShift(layout)
        for id in layout.whos.reversed() {
            if let box = layout.boxes[id]?.offsetBy(dx: 0, dy: down), box.insetBy(dx: -4 / s, dy: -4 / s).contains(p) { return .who(id) }
        }
        // Nothing is pressed through the strip the pinned names stand on.
        if down > 0, p.y < CGFloat(layout.boxBottom) + down + 7 / s { return .empty }
        let slack = 9 / s
        for row in layout.rows.reversed() where row.box.insetBy(dx: -slack * 0.6, dy: -slack * 0.4).contains(p) { return .step(row.id) }
        if p.y > CGFloat(layout.boxBottom), p.y < CGFloat(layout.lineBottom) + 16 / s,
           let who = layout.who(nearX: Double(p.x), reach: Double(11 / s)) {
            return .line(who)
        }
        let m = layout.metrics
        for row in layout.rows.reversed() {
            switch row.kind {
            case .message where row.loop:
                let loop = CGRect(x: row.fromX, y: row.lineY, width: m.loopWidth, height: m.loopHeight)
                if loop.insetBy(dx: -slack, dy: -slack).contains(p) { return .step(row.id) }
            case .message:
                if abs(p.y - CGFloat(row.lineY)) <= slack, p.x >= CGFloat(min(row.fromX, row.toX)), p.x <= CGFloat(max(row.fromX, row.toX)) {
                    return .step(row.id)
                }
            case .section:
                if abs(p.y - CGFloat(row.lineY)) <= slack * 0.7 { return .step(row.id) }
            default:
                break
            }
        }
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
                    pressBegan = value.time
                    // Pressing somewhere else ends the typing.
                    if session.editing != nil { session.commitEdit() }
                    // Every press on the board gives it the keys.
                    keys = true
                    switch t {
                    case .who(let id), .step(let id):
                        if !session.linking, !session.selection.contains(id), !shiftDown, !session.choosingMore { session.select(id) }
                    default:
                        break
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
                    rubber = nil
                    dropWho = nil
                    landing = nil
                    lifted = nil
                }
                pressing = false
                guard !pinched else {
                    if pinchBase == nil { pinched = false }
                    return
                }
                finish(value)
            }
    }

    /// What a drag does is told by where it starts and which way it goes first: sideways from a
    /// dashed line pulls a message, sideways on a name moves it in the row, up or down on a step
    /// moves it in the order. Any other slide moves the view.
    private func begin(_ t: Target, _ value: DragGesture.Value) {
        let sideways = abs(value.translation.width) >= abs(value.translation.height)
        guard !session.readOnly else { drag = .panning(session.offset); return }
        switch t {
        case .line(let id) where sideways:
            farthest = 0
            drag = .pulling(id)
        case .who(let id) where sideways && !session.linking:
            session.select(id)
            drag = .carrying(id)
        case .step(let id) where !sideways && !session.linking:
            #if os(iOS)
            // A slide that starts on a step moves the view. The step lifts only after a short hold,
            // so sliding down a long diagram never puts a message somewhere else by accident.
            guard value.time.timeIntervalSince(pressBegan) >= Self.hold else {
                drag = .panning(session.offset)
                return
            }
            Feel.lift()
            #endif
            session.select(id)
            drag = .lifting(id)
        default:
            drag = .panning(session.offset)
        }
    }

    private func update(_ value: DragGesture.Value) {
        let s = max(session.scale, 0.05)
        let here = session.toBoard(value.location)
        switch drag {
        case .pulling(let from):
            let layout = session.sequenceLayout
            guard let x = layout.x[from] else { return }
            farthest = max(farthest, abs(here.x - CGFloat(x)) * s)
            var over = layout.who(nearX: Double(here.x), reach: min(Double(44 / s), layout.metrics.laneGap * 0.4))
            // Back on its own line only after a clear way out: a small loop, a message to itself.
            if over == from, farthest < 30 { over = nil }
            dropWho = over
            let level = min(max(here.y, CGFloat(layout.firstTop)), CGFloat(layout.lineBottom))
            let end = over == from ? CGFloat(x) + CGFloat(layout.metrics.loopWidth) : (over.flatMap { layout.x[$0] }.map { CGFloat($0) } ?? here.x)
            rubber = Rubber(from: CGPoint(x: x, y: level), to: CGPoint(x: end, y: level))
            // The thin line shows between which two steps the message will stand.
            let y = CGFloat(layout.landingY(slot: layout.slot(atY: Double(here.y))))
            landing = Landing(from: CGPoint(x: min(CGFloat(x), end) - 8, y: y), to: CGPoint(x: max(CGFloat(x), end) + 8, y: y))
        case .lifting(let id):
            let layout = session.sequenceLayout
            lifted = CGSize(width: 0, height: value.translation.height / s)
            let slot = layout.slot(atY: Double(here.y), moving: id)
            if slot == layout.index(of: id) {
                landing = nil
            } else {
                let y = CGFloat(layout.landingY(slot: slot, moving: id))
                landing = Landing(from: CGPoint(x: layout.left - 8, y: y), to: CGPoint(x: layout.right + 8, y: y))
            }
        case .carrying(let id):
            let layout = session.sequenceLayout
            lifted = CGSize(width: value.translation.width / s, height: 0)
            let slot = layout.whoSlot(atX: Double(here.x), moving: id)
            if slot == session.board.whoIndex(of: id) {
                landing = nil
            } else {
                let x = CGFloat(layout.whoLandingX(slot: slot, moving: id))
                let down = session.sequenceShift(layout)
                landing = Landing(from: CGPoint(x: x, y: CGFloat(layout.boxTop) + down - 4),
                                  to: CGPoint(x: x, y: CGFloat(layout.boxBottom) + down + 30))
            }
        case .panning(let base):
            // The same step as every other way of moving the view, so the board knows the owner moved it.
            session.slide(from: base, by: value.translation)
        case .idle, .waiting:
            break
        }
    }

    private func finish(_ value: DragGesture.Value) {
        let here = session.toBoard(value.location)
        switch drag {
        case .waiting(let t):
            tap(t)
        case .pulling(let from):
            // Let go on nothing: nothing happens.
            if let to = dropWho {
                session.addMessage(from: from, to: to, at: session.sequenceLayout.slot(atY: Double(here.y)))
            }
        case .lifting(let id):
            let slot = session.sequenceLayout.slot(atY: Double(here.y), moving: id)
            session.change { $0.moveStep(id, to: slot) }
        case .carrying(let id):
            let slot = session.sequenceLayout.whoSlot(atX: Double(here.x), moving: id)
            session.change { $0.moveWho(id, to: slot) }
        case .panning, .idle:
            break
        }
    }

    private func tap(_ t: Target) {
        let now = Date()
        let double: (UUID?) -> Bool = { id in lastTapID == id && now.timeIntervalSince(lastTapAt) < 0.42 }
        switch t {
        case .who(let id), .line(let id):
            if session.linking {
                session.pressWhoForMessage(id)
            } else if double(id), case .who = t {
                session.beginEdit(id)
            } else if shiftDown || session.choosingMore {
                session.select(id, adding: true)
            } else {
                session.select(id)
            }
            lastTapID = id
            lastTapAt = now
        case .step(let id):
            if session.linking {
                // A message is being made: only names count.
            } else if double(id) {
                session.beginEdit(id)
            } else if shiftDown || session.choosingMore {
                session.select(id, adding: true)
            } else {
                session.select(id)
            }
            lastTapID = id
            lastTapAt = now
        case .empty:
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
                if pinchBase == nil {
                    pinchBase = session.scale
                    pinched = true
                    // Whatever one finger had begun is dropped.
                    drag = .idle
                    rubber = nil
                    dropWho = nil
                    landing = nil
                    lifted = nil
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
        let item = session.single
        if press.modifiers.contains(.command) {
            if press.characters == "a" { session.selectAll(); return .handled }
            return .ignored
        }
        // Option with an arrow key moves the chosen step in the order, or the chosen name in the row.
        let moving = press.modifiers.contains(.option)
        switch press.key {
        case .return:
            guard let item else { return .ignored }
            if item.kind == .message { session.addNextMessage(after: item.id) } else { session.beginEdit(item.id) }
            return .handled
        case .tab:
            // Tab on a chosen name: the next name beside it.
            guard let item, item.kind == .who else { return .ignored }
            session.addWho(after: item.id)
            return .handled
        case .delete, .deleteForward:
            session.deleteSelection()
            return .handled
        case .escape:
            session.clearSelection()
            session.linking = false
            return .handled
        case .upArrow, .downArrow:
            let step = press.key == .upArrow ? -1 : 1
            if moving { session.shiftStep(by: step) } else { session.selectStep(by: step) }
            return .handled
        case .leftArrow, .rightArrow:
            let step = press.key == .leftArrow ? -1 : 1
            if moving { session.shiftWho(by: step) } else { session.selectWho(by: step) }
            return .handled
        case .space:
            if let item { session.beginEdit(item.id); return .handled }
            return .ignored
        default:
            break
        }
        guard !press.modifiers.contains(.control), !moving else { return .ignored }
        let typed = press.characters
        guard let first = typed.unicodeScalars.first, typed.count == 1,
              !CharacterSet.controlCharacters.contains(first), first.value < 0xF700 || first.value > 0xF8FF else { return .ignored }
        if let item {
            // Just start typing: the words go on after what is there.
            session.beginEdit(item.id)
            session.typed(session.draft + typed)
            return .handled
        }
        if session.selection.isEmpty {
            switch typed.lowercased() {
            case "w": session.addWho()
            case "m": if session.linking { session.linking = false; session.linkFrom = nil } else { session.startMessage(from: nil) }
            case "n": session.addBand()
            case "s": session.addSection()
            default: return .ignored
            }
            return .handled
        }
        return .ignored
    }
}
