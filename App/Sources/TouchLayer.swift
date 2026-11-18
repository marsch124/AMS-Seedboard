#if os(iOS)
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// The touch layer of iPhone and iPad: Apple's own gesture recognisers on a clear view over the
// drawing. (The Mac keeps its click-and-drag gesture and its scroll catcher in CanvasView.)
//
//   one finger, the Pencil, a mouse or trackpad click  →  a `Press`, handed to the board's choose / move code
//   two fingers                                        →  slide and zoom together, round the point between them
//   trackpad two-finger scroll, mouse wheel            →  slide the board; with ⌘ zoom round the pointer
//   trackpad pinch                                     →  zoom round the pointer
//   a stroke the drawing code asks for (`InkHook`)     →  every sample, before the normal handling

// MARK: The hook for drawing

/// One point of a stroke: the Pencil's, or a finger's or pointer's when the drawing code asked for it.
struct InkSample {
    /// In the board view's own points — the same room as `Press.location` (`session.toBoard` gives board points).
    var location: CGPoint
    /// 0 … 1 for the Pencil (its force over the most it can give); 1 for a finger or a pointer.
    var force: CGFloat
    /// How upright the Pencil is (π/2 = straight up) and which way it leans, in radians; 0 for others.
    var altitude: CGFloat
    var azimuth: CGFloat
    /// The touch's own clock, in seconds.
    var time: TimeInterval
    var kind: Press.Kind
}

/// How drawing plugs into the touch layer. Each stroke is offered here first.
struct InkHook {
    /// Asked once, when a Pencil, a single finger or the pointer lands. True: the stroke belongs to
    /// the drawing code and never reaches the choose / move code. False: it is a normal press.
    var claims: (InkSample) -> Bool
    /// A claimed stroke began (the same sample `claims` saw).
    var began: (InkSample) -> Void
    /// It went on. `real`: every sample since the last call (the Pencil gives several per screen
    /// frame); `predicted`: where it is likely to go next — draw them, then throw them away.
    var moved: (_ real: [InkSample], _ predicted: [InkSample]) -> Void
    /// It ended. `cancelled`: taken away (a second finger landed, a call came) — the stroke is not kept.
    var ended: (_ cancelled: Bool) -> Void
}

extension Press.Kind {
    init(_ type: UITouch.TouchType) {
        switch type {
        case .pencil: self = .pencil
        case .indirectPointer: self = .pointer
        default: self = .finger
        }
    }
}

extension InkSample {
    init(_ touch: UITouch, in view: UIView) {
        let pencil = touch.type == .pencil
        location = touch.preciseLocation(in: view)
        force = pencil && touch.maximumPossibleForce > 0 ? min(max(touch.force / touch.maximumPossibleForce, 0), 1) : 1
        altitude = pencil ? touch.altitudeAngle : 0
        azimuth = pencil ? touch.azimuthAngle(in: view) : 0
        time = touch.timestamp
        kind = Press.Kind(touch.type)
    }
}

// MARK: The layer

struct TouchLayer: UIViewRepresentable {
    let session: BoardSession
    /// One finger, the Pencil or the pointer: landed, moved, lifted or taken away.
    var onPress: (PressPhase, Press) -> Void
    /// Drawing, when there is any.
    var ink: InkHook?

    func makeUIView(context: Context) -> TouchSurface {
        let view = TouchSurface()
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: TouchSurface, context: Context) {
        view.session = session
        view.hold.session = session
        view.onPress = onPress
        view.ink = ink
    }
}

final class TouchSurface: UIView, UIGestureRecognizerDelegate {
    weak var session: BoardSession?
    var onPress: ((PressPhase, Press) -> Void)?
    var ink: InkHook? { didSet { inkStroke.hook = ink } }

    /// A press begins the moment it lands (a long press of no time), so a thing is chosen at once.
    private let fingerPress = UILongPressGestureRecognizer()
    /// The Pencil has a recogniser of its own, so it is never held up by a resting hand.
    private let pencilPress = UILongPressGestureRecognizer()
    private let inkStroke = InkRecognizer()
    private let twoPan = UIPanGestureRecognizer()
    private let pinch = UIPinchGestureRecognizer()
    /// Takes no touches at all: only the scrolling of a trackpad or a mouse wheel.
    private let scroll = UIPanGestureRecognizer()
    private let hover = UIHoverGestureRecognizer()
    /// A trackpad's or mouse's secondary click: the menu of what lies under the pointer (BoardMenu.swift).
    private let secondary = UITapGestureRecognizer()
    /// Press and hold: a still press of half a second opens the same menu (BoardMenu.swift).
    let hold = HoldWatch()

    /// One press as it goes on.
    private final class Track {
        var live = false
        /// The press goes on for the recogniser, but the board no longer hears of it.
        var ignored = false
        var start = CGPoint.zero
        var last = CGPoint.zero
        var kind = Press.Kind.finger
    }
    private let fingerTrack = Track()
    private let pencilTrack = Track()

    /// Which recognisers may have a touch — decided once, when it lands.
    private struct Verdict {
        var press = false
        var ink = false
        var two = false
    }
    private struct Seen {
        weak var touch: UITouch?
        var landed: TimeInterval
        var type: UITouch.TouchType
        var verdict: Verdict
    }
    /// The touches that are down on the board right now.
    private var seen: [ObjectIdentifier: Seen] = [:]

    /// The point between the two fingers at the step before.
    private var lastMid: CGPoint?
    private var pinchByTrackpad = false
    private var pointerAt: CGPoint?
    private let watched = NSHashTable<UIGestureRecognizer>.weakObjects()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true

        let direct = NSNumber(value: UITouch.TouchType.direct.rawValue)
        let pencil = NSNumber(value: UITouch.TouchType.pencil.rawValue)
        let pointer = NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)

        fingerPress.minimumPressDuration = 0
        fingerPress.allowedTouchTypes = [direct, pointer]
        fingerPress.addTarget(self, action: #selector(pressed(_:)))

        pencilPress.minimumPressDuration = 0
        pencilPress.allowedTouchTypes = [pencil]
        pencilPress.addTarget(self, action: #selector(pressed(_:)))

        // Exactly two fingers; never the Pencil, never the pointer.
        twoPan.minimumNumberOfTouches = 2
        twoPan.maximumNumberOfTouches = 2
        twoPan.allowedTouchTypes = [direct]
        twoPan.addTarget(self, action: #selector(panned(_:)))

        // Two fingers on the glass — and a trackpad's pinch, which comes without any touch.
        pinch.allowedTouchTypes = [direct]
        pinch.addTarget(self, action: #selector(pinched(_:)))

        // No touch types at all: this one only hears the scrolling of a trackpad (two fingers on
        // it) and of a mouse wheel, which are no touches.
        scroll.allowedTouchTypes = []
        scroll.allowedScrollTypesMask = .all
        scroll.addTarget(self, action: #selector(scrolled(_:)))

        hover.addTarget(self, action: #selector(hovered(_:)))

        secondary.allowedTouchTypes = [pointer]
        secondary.buttonMaskRequired = .secondary
        secondary.addTarget(self, action: #selector(secondaryClicked(_:)))

        for recogniser in [fingerPress, pencilPress, inkStroke, twoPan, pinch, scroll, hover, secondary] as [UIGestureRecognizer] {
            recogniser.delegate = self
            recogniser.cancelsTouchesInView = false
            recogniser.delaysTouchesEnded = false
            addGestureRecognizer(recogniser)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        guard newWindow == nil else { return }
        for edge in watched.allObjects { edge.removeTarget(self, action: #selector(edgeSwiped(_:))) }
        watched.removeAllObjects()
    }

    // The recognisers do all the work. The touches themselves stop here, so they do not travel on
    // to the views behind the board.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

    // MARK: Which touch goes where

    /// The touches still down, without this one.
    private func others(than key: ObjectIdentifier?) -> [Seen] {
        seen = seen.filter { _, entry in
            guard let touch = entry.touch else { return false }
            return touch.phase != .ended && touch.phase != .cancelled
        }
        return seen.filter { $0.key != key }.map(\.value)
    }

    private func verdict(for touch: UITouch) -> Verdict {
        let key = ObjectIdentifier(touch)
        let down = others(than: key)
        // Every recogniser asks about the same touch: the answer is made once.
        if let known = seen[key], known.landed == touch.timestamp { return known.verdict }
        var verdict = Verdict()
        if touch.type == .pencil {
            // The Pencil comes first: what a finger had begun (a resting hand, more often than not) is given up.
            giveUpFingers()
            route(touch, &verdict)
        } else if !down.contains(where: { $0.type == .pencil }) {
            if down.isEmpty {
                route(touch, &verdict)
            } else {
                // A second finger: from here on the fingers only slide and zoom the board.
                giveUpFingers()
            }
            verdict.two = touch.type == .direct
        }
        // (A finger that lands while the Pencil is down is a resting hand: nobody takes it.)
        seen[key] = Seen(touch: touch, landed: touch.timestamp, type: touch.type, verdict: verdict)
        return verdict
    }

    /// One finger, the Pencil or the pointer: a stroke for the drawing code when it asks for it, a press otherwise.
    private func route(_ touch: UITouch, _ verdict: inout Verdict) {
        if let ink, ink.claims(InkSample(touch, in: self)) {
            verdict.ink = true
        } else {
            verdict.press = true
            (touch.type == .pencil ? pencilTrack : fingerTrack).kind = Press.Kind(touch.type)
        }
    }

    /// What one finger (or the pointer) had begun is over: the board is told once, with the word to
    /// take a small shove back, and hears no more of that press. A finger's stroke is not kept.
    private func giveUpFingers() {
        hold.cancel()
        if fingerTrack.live, !fingerTrack.ignored {
            fingerTrack.ignored = true
            send(.lost(takeBack: true), fingerPress, fingerTrack)
        }
        if inkStroke.kind != .pencil { inkStroke.giveUp() }
    }

    func gestureRecognizer(_ recogniser: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let verdict = verdict(for: touch)
        if recogniser === fingerPress || recogniser === pencilPress { return verdict.press }
        if recogniser === inkStroke { return verdict.ink }
        if recogniser === twoPan || recogniser === pinch { return verdict.two }
        return true
    }

    func gestureRecognizer(_ recogniser: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // The board's own recognisers work side by side: a press goes on while the two-finger ones
        // wait for the second finger, and sliding and zooming happen together.
        if other.view === self { return true }
        // The page's own swipe from the screen's edge (Back) may begin too; when it does, the press is given up.
        if other is UIScreenEdgePanGestureRecognizer {
            if !watched.contains(other) {
                watched.add(other)
                other.addTarget(self, action: #selector(edgeSwiped(_:)))
            }
            return true
        }
        // Anything else (a swipe-back from the middle of the page, for one) loses to a press on the board.
        return false
    }

    @objc private func edgeSwiped(_ edge: UIGestureRecognizer) {
        if edge.state == .began { giveUpFingers() }
    }

    // MARK: One finger, the Pencil, the pointer

    @objc private func pressed(_ recogniser: UILongPressGestureRecognizer) {
        let track = recogniser === pencilPress ? pencilTrack : fingerTrack
        switch recogniser.state {
        case .began:
            // Both fingers landed in the same moment: this was never a press.
            let fingers = others(than: nil).filter { $0.type != .pencil }.count
            track.ignored = recogniser === fingerPress && fingers >= 2
            track.live = true
            track.start = recogniser.location(in: self)
            track.last = track.start
            if !track.ignored {
                send(.began, recogniser, track)
                hold.began(at: track.start, kind: track.kind)
            }
        case .changed:
            guard track.live, !track.ignored else { return }
            // While the press-and-hold menu is open, a trembling finger does not move anything.
            guard hold.moved(to: recogniser.location(in: self)) else { return }
            track.last = recogniser.location(in: self)
            send(.moved, recogniser, track)
        case .ended:
            // A press that opened the menu is not a press on the thing as well.
            let held = hold.ended()
            if track.live, !track.ignored {
                if !held { track.last = recogniser.location(in: self) }
                send(held ? .lost(takeBack: false) : .ended, recogniser, track)
            }
            track.live = false
            track.ignored = false
        case .cancelled, .failed:
            hold.cancel()
            // The system took the press away (a call, the home swipe, leaving the app).
            if track.live, !track.ignored { send(.lost(takeBack: false), recogniser, track) }
            track.live = false
            track.ignored = false
        default:
            break
        }
    }

    private func send(_ phase: PressPhase, _ recogniser: UIGestureRecognizer, _ track: Track) {
        let here = track.last
        let press = Press(startLocation: track.start, location: here,
                          translation: CGSize(width: here.x - track.start.x, height: here.y - track.start.y),
                          time: Date(), kind: track.kind, shift: recogniser.modifierFlags.contains(.shift))
        onPress?(phase, press)
    }

    // MARK: Two fingers

    private func active(_ recogniser: UIGestureRecognizer) -> Bool {
        recogniser.state == .began || recogniser.state == .changed
    }

    @objc private func panned(_ recogniser: UIPanGestureRecognizer) { twoFingers(recogniser) }

    @objc private func pinched(_ recogniser: UIPinchGestureRecognizer) {
        if recogniser.state == .began { pinchByTrackpad = recogniser.numberOfTouches == 0 }
        guard pinchByTrackpad else { twoFingers(recogniser); return }
        // A pinch on a trackpad: zoom round the pointer.
        if active(recogniser), recogniser.scale.isFinite, recogniser.scale > 0, let session {
            session.zoom(to: session.scale * recogniser.scale, around: pointer(recogniser))
            recogniser.scale = 1
        }
    }

    /// Sliding and zooming are two recognisers (each begins when it is sure), but one step:
    /// the board point between the fingers stays between them.
    private func twoFingers(_ recogniser: UIGestureRecognizer) {
        switch recogniser.state {
        case .began:
            // Normally done already, when the second finger landed.
            giveUpFingers()
            // Count the spreading from here, not from where the fingers landed: no jump.
            if recogniser === pinch { pinch.scale = 1 }
            step()
        case .changed:
            step()
        default:
            if !active(twoPan), !active(pinch) { lastMid = nil }
        }
    }

    private func step() {
        // With one finger lifted the board rests until both are down again.
        let both: [UIGestureRecognizer] = [twoPan, pinch]
        guard let lead = both.first(where: { active($0) && $0.numberOfTouches >= 2 }) else {
            lastMid = nil
            return
        }
        let mid = lead.location(in: self)
        var factor: CGFloat = 1
        if active(pinch), pinch.numberOfTouches >= 2, pinch.scale.isFinite, pinch.scale > 0 {
            factor = pinch.scale
            pinch.scale = 1
        }
        // A finger changed places with another: start again from here instead of jumping.
        if let last = lastMid, hypot(mid.x - last.x, mid.y - last.y) < 150 {
            session?.pinch(from: last, to: mid, by: factor)
        }
        lastMid = mid
    }

    // MARK: Trackpad and mouse

    /// Where the pointer is: scrolling and a trackpad's pinch happen round it.
    private func pointer(_ recogniser: UIGestureRecognizer) -> CGPoint {
        if let pointerAt { return pointerAt }
        let here = recogniser.location(in: self)
        if here.x.isFinite, here.y.isFinite, bounds.contains(here) { return here }
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    @objc private func hovered(_ recogniser: UIHoverGestureRecognizer) {
        switch recogniser.state {
        case .began, .changed: pointerAt = recogniser.location(in: self)
        default: pointerAt = nil
        }
        // A paste lands under the pointer (ClipBoard.swift).
        BarDesk.shared.pointer = pointerAt
    }

    @objc private func secondaryClicked(_ recogniser: UITapGestureRecognizer) {
        guard recogniser.state == .ended, let session else { return }
        BoardMenu.open(session, at: recogniser.location(in: self), finger: false)
    }

    @objc private func scrolled(_ recogniser: UIPanGestureRecognizer) {
        guard active(recogniser) || recogniser.state == .ended, let session else { return }
        // Each time only the way since the last time.
        let way = recogniser.translation(in: self)
        recogniser.setTranslation(.zero, in: self)
        guard way != .zero, way.x.isFinite, way.y.isFinite else { return }
        if recogniser.modifierFlags.contains(.command) {
            // ⌘ and scrolling: zoom by 1 % per point, round the pointer (as on the Mac).
            session.zoom(to: session.scale * exp(min(max(way.y, -60), 60) * 0.01), around: pointer(recogniser))
        } else {
            session.pan(by: CGSize(width: way.x, height: way.y))
        }
    }
}

// MARK: A stroke for the drawing code

/// Follows one claimed touch and hands every sample to the hook — the Pencil's in-between samples
/// (several per screen frame) and the predicted ones too, which Apple's own recognisers do not give.
final class InkRecognizer: UIGestureRecognizer {
    var hook: InkHook?
    /// What is drawing right now; nil when nothing is.
    private(set) var kind: Press.Kind?
    private weak var touch: UITouch?
    /// The hook has been told the end of this stroke.
    private var told = true

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let first = touches.first, let hook, let view, touch == nil || told else {
            for extra in touches where extra !== touch { ignore(extra, for: event) }
            if touch == nil { state = .failed }
            return
        }
        // A stroke that was given up (a finger's, when the Pencil lands) makes way for the new one.
        if let old = touch { ignore(old, for: event) }
        for extra in touches where extra !== first { ignore(extra, for: event) }
        touch = first
        kind = Press.Kind(first.type)
        told = false
        hook.began(InkSample(first, in: view))
        state = state == .possible ? .began : .changed
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch), let view else { return }
        if !told {
            let real = (event.coalescedTouches(for: touch) ?? [touch]).map { InkSample($0, in: view) }
            let predicted = (event.predictedTouches(for: touch) ?? []).map { InkSample($0, in: view) }
            hook?.moved(real, predicted)
        }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        finish(cancelled: false)
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        finish(cancelled: true)
        state = .cancelled
    }

    override func reset() {
        super.reset()
        finish(cancelled: true)
        touch = nil
        kind = nil
    }

    /// A second finger landed: the stroke is not kept, and what follows of it is not passed on.
    func giveUp() { finish(cancelled: true) }

    private func finish(cancelled: Bool) {
        guard !told else { return }
        told = true
        hook?.ended(cancelled)
    }
}
#endif
