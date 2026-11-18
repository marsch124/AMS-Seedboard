import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// The menu of a thing, an arrow or empty board (0.2, pick 18): a right-click on the Mac (the
// system's own menu), a secondary click of a trackpad or mouse on the iPad, and a still press of
// half a second with a finger or the Pencil (a small plate at the spot). And the pointer's
// feedback on the Mac: a resize arrow over a size knob, a pointing hand over a plus-handle or an
// arrow's end dot, and the plus-handle under the pointer grows.

@MainActor
enum BoardMenu {
    /// The press-and-hold menu that is open (iPhone and iPad).
    struct Open: Identifiable {
        let id = UUID()
        /// Where it was asked for, in the board view's own points.
        var spot: CGPoint
        var title: String
        var glyph: Glyph
        var part: Part
        var actions: [BarAction]
    }

    /// The board is shown by night (for the colours to pick from).
    static var night = false

    /// What the menu at this point of the board view holds. The thing or the arrow under the point
    /// is chosen on the way; on empty board nothing stays chosen.
    private static func lines(_ session: BoardSession, at p: CGPoint, finger: Bool) -> Open? {
        guard !session.board.placesItself else { return nil }
        if session.editing != nil { session.commitEdit() }
        if session.laneTyping != nil { session.commitLaneName() }
        if session.linking {
            session.linking = false
            session.linkFrom = nil
        }
        let board = session.toBoard(p)
        // A plus-handle, a size knob or an arrow's end dot is for dragging: it has no menu.
        if session.control(at: p, finger: finger, onThing: session.board.hit(board) != nil) != nil || session.linkEnd(at: board) != nil { return nil }
        let make = BarActions(session: session, prefix: "menu.", dots: nil, night: night)
        if let id = session.board.hit(board, scale: Double(session.scale), least: finger ? Fingers.button : 0) {
            if !session.selection.contains(id) { session.select(id, adding: session.choosingMore) }
            let actions = ShareLine.added(to: make.thingMenu(), session: session)
            if let item = session.single {
                return Open(spot: p, title: item.kind.word, glyph: item.kind == .idea ? .app(.seedMindMap) : (item.kind.isShape ? item.kind.mark : .app(.seedBoard)),
                            part: BarActions.part(of: item.kind), actions: actions)
            }
            return Open(spot: p, title: "\(session.selection.count) chosen", glyph: .app(.seedBoard), part: .boards, actions: actions)
        }
        if let id = session.board.hitLink(board, within: Double(9 / session.scale)),
           let link = session.board.links.first(where: { $0.id == id }) {
            session.selection = []
            session.selectedLink = id
            return Open(spot: p, title: "Arrow", glyph: .app(.seedArrow), part: .arrows, actions: make.arrowMenu(link))
        }
        session.clearSelection()
        return Open(spot: p, title: "Board", glyph: .app(.seedBoard), part: .boards, actions: make.emptyMenu(at: board))
    }

    /// Opens the menu for what lies at this point of the board view. `finger`: a finger asked (its
    /// press area is bigger than a pointer's). True when a menu opened.
    @discardableResult
    static func open(_ session: BoardSession, at p: CGPoint, finger: Bool) -> Bool {
        guard let found = lines(session, at: p, finger: finger), !found.actions.isEmpty else { return false }
        #if os(macOS)
        guard let view = PointerCatcher.PointerView.current else { return false }
        // The system's own menu: it stays until a line is picked or it is left.
        MacMenu.make(found.actions).popUp(positioning: nil, at: p, in: view)
        session.takeKeys()
        #else
        BarDesk.shared.menu = found
        #endif
        return true
    }

    static func close() {
        if BarDesk.shared.menu != nil { BarDesk.shared.menu = nil }
    }

    /// For pictures: `-menu` opens the menu of the thing chosen with `-pick` (or the arrow chosen
    /// with `-pickArrow`; with nothing chosen: the menu of empty board), once, a moment after the board is shown.
    private static var launchUsed = false

    static func openForPicture(_ session: BoardSession) {
        guard !launchUsed, LaunchOptions.arguments.contains("-menu") else { return }
        launchUsed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            var spot = CGPoint(x: session.viewSize.width * 0.3, y: session.viewSize.height * 0.25)
            if let item = session.single {
                spot = session.toScreen(item.centre)
            } else if let id = session.selectedLink, let arrow = session.board.arrow(id), !arrow.outline.isEmpty {
                spot = session.toScreen(arrow.outline[arrow.outline.count / 2])
            }
            open(session, at: spot, finger: false)
        }
    }
}

// MARK: iPhone and iPad: a small plate at the spot

/// Lies over the board while the press-and-hold menu is open: the plate beside the pressed spot,
/// and a clear sheet behind it — a press anywhere else closes the menu.
struct BoardMenuLayer: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = BarDesk.shared

    var body: some View {
        if let open = desk.menu {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { _ in BoardMenu.close() })
                    .accessibilityHidden(true)
                // Above the finger, so the hand does not hide it; below when there is no room above.
                BarSpot(box: CGRect(x: open.spot.x - 1, y: open.spot.y - 26, width: 2, height: 52)) {
                    ViewThatFits(in: .vertical) {
                        plate(open)
                        ScrollView { plate(open) }
                    }
                    .background(Theme.plate, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.primary.opacity(0.12)))
                    .shadow(color: .black.opacity(0.22), radius: 14, y: 4)
                    // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("board.menu")
                }
            }
            .id(open.id)
            .transition(.opacity)
        }
    }

    private func plate(_ open: BoardMenu.Open) -> some View {
        ActionList(title: open.title, glyph: open.glyph, part: open.part, actions: open.actions) {
            BoardMenu.close()
            session.takeKeys()
        }
    }
}

#if os(iOS)
/// Press and hold (pick 18): watches one press of a finger or the Pencil for `TouchSurface`.
/// A press that has not moved (4 points) for half a second opens the menu of what lies under it.
/// The finger may stay down: if it then moves more than 10 points the menu goes again and the
/// press is a drag after all (an idea lifts, a shape moves) — so the menu never fights a drag.
@MainActor
final class HoldWatch {
    weak var session: BoardSession?
    private var work: DispatchWorkItem?
    private var start = CGPoint.zero
    private var began = Date.distantPast
    /// The furthest the press has strayed from where it landed.
    private var far: CGFloat = 0
    /// This press opened the menu and is still down.
    private var open = false

    /// A press landed.
    func began(at point: CGPoint, kind: Press.Kind) {
        cancel()
        start = point
        began = Date()
        far = 0
        // A mouse or a trackpad has its secondary click.
        guard kind != .pointer else { return }
        let fire = DispatchWorkItem { [weak self] in self?.fire() }
        work = fire
        DispatchQueue.main.asyncAfter(deadline: .now() + Fingers.hold, execute: fire)
    }

    /// The press moved. False: the board must not hear of this move (the menu is open and the finger only trembles).
    func moved(to point: CGPoint) -> Bool {
        let now = hypot(point.x - start.x, point.y - start.y)
        far = max(far, now)
        if open {
            guard Fingers.leavesMenu(moved: Double(now)) else { return false }
            // A drag after all: the menu goes, the press goes on.
            open = false
            BoardMenu.close()
            return true
        }
        if Double(far) > Fingers.still {
            work?.cancel()
            work = nil
        }
        return true
    }

    /// The press was lifted. True: it had opened the menu — the board must not take it for a press.
    func ended() -> Bool {
        work?.cancel()
        work = nil
        defer { open = false }
        return open
    }

    /// The press was taken away (a second finger, the system).
    func cancel() {
        work?.cancel()
        work = nil
        open = false
    }

    private func fire() {
        work = nil
        guard let session, Fingers.opensMenu(moved: Double(far), after: Date().timeIntervalSince(began) + 0.02) else { return }
        open = BoardMenu.open(session, at: start, finger: true)
        if open { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }
}
#endif

// MARK: The Mac: the system's menu, and the pointer

#if os(macOS)
/// One line of the Mac's right-click menu: it runs its own step.
private final class StepItem: NSMenuItem {
    var step: (() -> Void)?

    @objc func run(_ sender: Any?) { step?() }
}

@MainActor
enum MacMenu {
    static func make(_ actions: [BarAction]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for action in actions {
            if action.gap, !menu.items.isEmpty { menu.addItem(.separator()) }
            let item = StepItem(title: action.word, action: nil, keyEquivalent: "")
            item.isEnabled = action.enabled
            item.state = action.on ? .on : .off
            item.identifier = NSUserInterfaceItemIdentifier(action.id)
            item.setAccessibilityIdentifier(action.id)
            if let swatch = action.swatch { item.image = dot(swatch, hollow: action.hollow) }
            switch action.kind {
            case .press(let run):
                item.step = run
                item.target = item
                item.action = #selector(StepItem.run(_:))
            case .choices(let inner):
                item.submenu = make(inner)
                // "Lanes" shows that the frame has some; a list has no tick of its own.
                item.state = .off
            case .shape, .lanes:
                continue
            }
            menu.addItem(item)
        }
        return menu
    }

    /// A small dot of a colour to pick.
    private static func dot(_ colour: Color, hollow: Bool) -> NSImage {
        NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
            NSColor(colour).setFill()
            ring.fill()
            if hollow {
                NSColor.tertiaryLabelColor.setStroke()
                ring.lineWidth = 1
                ring.stroke()
            }
            return true
        }
    }
}

/// Behind the board on the Mac: hears the right-click (and Control with a click) and where the
/// pointer is. Left clicks, drags and scrolling are not touched.
struct PointerCatcher: NSViewRepresentable {
    let session: BoardSession

    func makeNSView(context: Context) -> PointerView {
        let view = PointerView()
        view.session = session
        return view
    }

    func updateNSView(_ view: PointerView, context: Context) { view.session = session }

    final class PointerView: NSView {
        /// The board view that is on screen (one board is open at a time).
        static weak var current: PointerView?

        weak var session: BoardSession?
        private var monitor: Any?
        private var area: NSTrackingArea?
        /// The pointer wears one of this view's shapes right now.
        private var dressed = false

        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else {
                if PointerView.current === self { PointerView.current = nil }
                return
            }
            PointerView.current = self
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
                guard let self else { return event }
                var answer: NSEvent? = event
                MainActor.assumeIsolated { answer = self.clicked(event) }
                return answer
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let made = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
            addTrackingArea(made)
            area = made
        }

        /// A right-click on the bare board (or Control with a click) opens the menu there.
        private func clicked(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window, window.attachedSheet == nil, let session else { return event }
            guard event.type == .rightMouseDown || event.modifierFlags.contains(.control) else { return event }
            let p = convert(event.locationInWindow, from: nil)
            guard bounds.contains(p), !BarDesk.shared.covered(p), !session.board.placesItself else { return event }
            // While words are typed, a right-click on them belongs to the words.
            if let id = session.editing, let item = session.board.item(id), session.toScreen(item.frame).insetBy(dx: -8, dy: -8).contains(p) { return event }
            DispatchQueue.main.async { BoardMenu.open(session, at: p, finger: false) }
            return nil
        }

        override func mouseMoved(with event: NSEvent) {
            moved(to: convert(event.locationInWindow, from: nil))
        }

        override func mouseExited(with event: NSEvent) {
            left()
        }

        private func left() {
            let desk = BarDesk.shared
            desk.pointer = nil
            if desk.hot != nil { desk.hot = nil }
            undress()
        }

        private func undress() {
            guard dressed else { return }
            dressed = false
            NSCursor.arrow.set()
        }

        private func moved(to p: CGPoint) {
            let desk = BarDesk.shared
            guard let session, bounds.contains(p), !desk.covered(p), window?.attachedSheet == nil else { left(); return }
            desk.pointer = p
            guard !desk.dragging else { return }
            let hot = session.control(at: p, finger: false, onThing: false)
            if desk.hot != hot { desk.hot = hot }
            // Space with a drag has its own hand (`SpaceHand`): it is left alone.
            if NSCursor.current === NSCursor.openHand || NSCursor.current === NSCursor.closedHand { return }
            var shape: NSCursor?
            if case .size(let corner)? = hot {
                shape = PointerView.resize(corner)
            } else if hot != nil || overEndDot(session, session.toBoard(p)) {
                shape = .pointingHand
            }
            if let shape {
                shape.set()
                dressed = true
            } else {
                undress()
            }
        }

        /// True when the point (board points) is on an end dot of the chosen arrow.
        private func overEndDot(_ session: BoardSession, _ p: CGPoint) -> Bool {
            guard !session.readOnly, session.editing == nil, !session.linking, let id = session.selectedLink,
                  let arrow = ArrowCache.shared.arrows(of: session.board)[id],
                  let first = arrow.points.first, let last = arrow.points.last else { return false }
            let reach = 13 / session.scale
            return hypot(p.x - last.x, p.y - last.y) <= reach || hypot(p.x - first.x, p.y - first.y) <= reach
        }

        /// The arrow that says "drag me to size it" for one corner.
        private static func resize(_ corner: Corner) -> NSCursor {
            if #available(macOS 15.0, *) {
                let position: NSCursor.FrameResizePosition
                switch corner {
                case .topLeft: position = .topLeft
                case .topRight: position = .topRight
                case .bottomLeft: position = .bottomLeft
                case .bottomRight: position = .bottomRight
                }
                return NSCursor.frameResize(position: position, directions: .all)
            }
            return .crosshair
        }
    }
}
#endif
