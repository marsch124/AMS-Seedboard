import SwiftUI
import SeedboardCore
#if os(iOS)
import UIKit
#endif

// Drawing by hand on the board (0.2): what the Pencil, a finger or the mouse does while a line is
// drawn. The rules (thinning, joining, the rubber, how a line is painted) are in SeedboardCore
// (Ink.swift); the painting is in InkDraw.swift; the Draw tool and its plate are in InkViews.swift.
//
//   the Pencil on empty board           →  draws at once, no tool chosen (a drawing's own lines count as empty)
//   the Pencil on a thing               →  chooses or moves it, as a finger does
//   a finger                            →  never draws (it slides the board) — unless the Draw tool is on
//   the Draw tool on                    →  finger, Pencil, mouse and trackpad draw, across things too
//   "Only Draw with Apple Pencil" (iPad Settings) on  →  a finger does not draw even with the tool on

/// One sample of a line being drawn, whoever draws it (the Mac has no `InkSample`).
struct InkDot {
    /// In the board view's own points.
    var location: CGPoint
    /// 0 … 1 from the Pencil; nil from a finger, the mouse or a trackpad.
    var force: Double?
    /// Seconds, on the clock of whoever sent it.
    var time: TimeInterval
    var kind: Press.Kind
}

/// The line that runs under the tip while it is down. Only the light layer over the board listens
/// to it (`InkLayer`), so a sample redraws that one line and nothing else.
@MainActor
final class WetLine: ObservableObject {
    /// Board points.
    private(set) var points: [CGPoint] = []
    private(set) var pressure: [Double] = []
    /// Where the tip is likely to go next: drawn, then thrown away with the next sample.
    private(set) var ahead: [CGPoint] = []
    private(set) var aheadPressure: [Double] = []
    private(set) var colour = ""
    private(set) var width = InkWidth.medium
    private(set) var live = false
    private(set) var pressed = false
    /// The rubber's place while it rubs (board points).
    private(set) var rubberAt: CGPoint?

    func begin(at point: CGPoint, force: Double?, colour: String, width: InkWidth) {
        points = [point]
        pressure = [force ?? 1]
        ahead = []
        aheadPressure = []
        pressed = force != nil
        self.colour = colour
        self.width = width
        live = true
        objectWillChange.send()
    }

    func add(_ real: [(CGPoint, Double?)], ahead predicted: [(CGPoint, Double?)]) {
        guard live else { return }
        for (point, force) in real where point.x.isFinite && point.y.isFinite {
            points.append(point)
            pressure.append(force ?? 1)
        }
        ahead = predicted.map(\.0).filter { $0.x.isFinite && $0.y.isFinite }
        aheadPressure = ahead.count == predicted.count ? predicted.map { $0.1 ?? 1 } : []
        objectWillChange.send()
    }

    func rub(at point: CGPoint?) {
        rubberAt = point
        objectWillChange.send()
    }

    func clear() {
        guard live || rubberAt != nil || !points.isEmpty else { return }
        points = []
        pressure = []
        ahead = []
        aheadPressure = []
        live = false
        rubberAt = nil
        objectWillChange.send()
    }
}

/// The drawing tools of one open board: is the Draw tool on, pen or rubber, how thick, which colour.
@MainActor
final class InkDesk: ObservableObject {
    /// The Draw tool is on: a finger and the mouse draw too.
    @Published var on = false
    /// The rubber instead of the pen.
    @Published var rubber = false
    /// Thickness and colour are remembered on this device (not in iCloud): the last used come back.
    @Published var width: InkWidth {
        didSet { if !LaunchOptions.sampleData { UserDefaults.standard.set(width.rawValue, forKey: InkDesk.widthKey) } }
    }
    /// A palette name; empty = plain ink.
    @Published var colour: String {
        didSet { if !LaunchOptions.sampleData { UserDefaults.standard.set(colour, forKey: InkDesk.colourKey) } }
    }
    let wet = WetLine()

    private static let widthKey = "ink.width"
    private static let colourKey = "ink.colour"

    init() {
        // Pictures and tests always start with plain ink, medium.
        let stored = LaunchOptions.sampleData ? nil : UserDefaults.standard
        width = stored?.string(forKey: InkDesk.widthKey).flatMap { InkWidth(rawValue: $0) } ?? .medium
        let name = stored?.string(forKey: InkDesk.colourKey) ?? ""
        colour = Palette.names.contains(name) ? name : ""
    }

    /// Leaves the Draw tool; the next line is a pen's again.
    func leave() {
        if on { on = false }
        if rubber { rubber = false }
    }

    func pick(width new: InkWidth) {
        width = new
        rubber = false
    }

    func pick(colour new: String) {
        colour = new
        rubber = false
    }

    /// iPad Settings › Apple Pencil › "Only Draw with Apple Pencil": a finger then never draws.
    static var pencilOnly: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad && UIPencilInteraction.prefersPencilOnlyDrawing
        #else
        return false
        #endif
    }

    // MARK: The Pencil's double-tap and squeeze

    /// What the owner chose in Settings for the Pencil's double-tap or squeeze, in this app's words.
    enum PencilWish { case nothing, swap, plate }

    /// Double-tap or squeeze: pen and rubber change places, or the Draw tool's plate opens or
    /// closes — whichever the owner chose in Settings.
    func pencil(_ wish: PencilWish) {
        switch wish {
        case .nothing: break
        case .swap: rubber.toggle()
        case .plate: if on { leave() } else { on = true }
        }
    }

    // MARK: The stroke that is going on

    fileprivate struct Rub {
        /// The board as it was when the rubber came down.
        var base: Board
        var gone: Set<InkMark> = []
        var last: CGPoint
    }

    fileprivate var kind: Press.Kind?
    fileprivate var rub: Rub?
    fileprivate var landed = CGPoint.zero
    fileprivate var landedAt: TimeInterval = 0
    fileprivate var lastAt: TimeInterval = 0
    /// The farthest the tip went from where it landed, in screen points.
    fileprivate var strayed: CGFloat = 0
    fileprivate var beganAt = Date()
    /// The drawing the last stroke went into, and when that stroke ended.
    fileprivate var lastDrawing: (id: UUID, at: Date)?
    /// The Mac's click and drag that is going on (told from the next one by where it began), and whether it draws.
    fileprivate var mouse: (start: CGPoint, ink: Bool)?
}

extension BoardSession {
    // MARK: Who draws

    /// Does this touch draw? Asked once, when it lands (TouchLayer's `InkHook.claims`).
    func inkClaims(_ dot: InkDot) -> Bool {
        guard !readOnly, !board.isTimeline else { return false }
        switch dot.kind {
        case .pencil:
            if ink.on { return true }
            return !linking && inkBare(toBoard(dot.location))
        case .finger:
            return ink.on && !InkDesk.pencilOnly
        case .pointer:
            return ink.on
        }
    }

    /// Nothing the Pencil could choose or move lies here. A drawing that is not chosen counts as
    /// empty board — the Pencil draws on, over and across its own lines; a chosen one is moved.
    private func inkBare(_ p: CGPoint) -> Bool {
        if linkEnd(at: p) != nil { return false }
        var plain = board
        plain.items.removeAll { $0.kind == .drawing && !selection.contains($0.id) }
        // The small controls round the one chosen thing (ChosenFrame.swift).
        if control(at: toScreen(p), finger: false, onThing: plain.hit(p) != nil) != nil { return false }
        if plain.hit(p, scale: Double(scale), least: 0) != nil { return false }
        return plain.hitLink(p, within: Double(9 / scale)) == nil
    }

    // MARK: One stroke

    func inkBegan(_ dot: InkDot) {
        guard !readOnly else { return }
        // Drawing somewhere ends the typing and lets go of what was chosen, as a press on empty board does.
        if editing != nil { commitEdit() }
        clearSelection()
        takeKeys()
        let desk = ink
        desk.kind = dot.kind
        desk.landed = dot.location
        desk.landedAt = dot.time
        desk.lastAt = dot.time
        desk.strayed = 0
        desk.beganAt = Date()
        let p = toBoard(dot.location)
        if desk.rubber {
            liveStart()
            desk.rub = InkDesk.Rub(base: board, last: p)
            desk.wet.rub(at: p)
            rubStep(to: p, first: true)
        } else {
            desk.wet.begin(at: p, force: dot.force, colour: desk.colour, width: desk.width)
        }
    }

    func inkMoved(_ real: [InkDot], _ predicted: [InkDot] = []) {
        let desk = ink
        guard desk.kind != nil, let latest = real.last else { return }
        desk.lastAt = latest.time
        for dot in real {
            desk.strayed = max(desk.strayed, hypot(dot.location.x - desk.landed.x, dot.location.y - desk.landed.y))
        }
        if desk.rub != nil {
            for dot in real { rubStep(to: toBoard(dot.location), first: false) }
            desk.wet.rub(at: toBoard(latest.location))
        } else {
            desk.wet.add(real.map { (toBoard($0.location), $0.force) }, ahead: predicted.map { (toBoard($0.location), $0.force) })
        }
    }

    /// The tip was lifted — or the stroke was taken away (`cancelled`: a second finger landed, a
    /// call came), and nothing of it is kept.
    func inkEnded(cancelled: Bool) {
        let desk = ink
        guard let kind = desk.kind else { return }
        desk.kind = nil
        if desk.rub != nil {
            // Everything the rubber took on this way is ONE step for Undo.
            desk.rub = nil
            desk.wet.clear()
            liveEnd(keep: !cancelled)
            return
        }
        let points = desk.wet.points
        let force = desk.wet.pressed ? desk.wet.pressure : nil
        desk.wet.clear()
        guard !cancelled, let first = points.first, !readOnly else { return }
        // A tap of the Pencil on a drawing's line (no tool chosen) chooses the drawing instead of leaving a dot on it.
        let tap = desk.strayed <= CGFloat(Ink.tapWay) && desk.lastAt - desk.landedAt <= Ink.tapSeconds
        if tap, kind == .pencil, !desk.on, let id = board.inkHit(first, reach: Ink.reach / Double(scale)) {
            select(id)
            return
        }
        let line = Ink.thin(points, pressure: force, tolerance: Ink.tolerance(scale: Double(scale)))
        guard let box = Ink.bounds(of: line.points) else { return }
        // Strokes close together in time and place are one drawing.
        let join = board.drawingToJoin(box, last: desk.lastDrawing?.id,
                                       after: desk.beganAt.timeIntervalSince(desk.lastDrawing?.at ?? .distantPast))
        var made: UUID?
        // One stroke, one step for Undo.
        change { made = $0.addStroke(line.points, pressure: line.pressure, colour: desk.colour, width: desk.width, to: join) }
        if let made { desk.lastDrawing = (made, Date()) }
    }

    /// The rubber went on to `p`: every stroke it touched on the way goes, whole.
    private func rubStep(to p: CGPoint, first: Bool) {
        guard var rub = ink.rub else { return }
        let found = rub.base.strokes(near: p, from: first ? nil : rub.last, reach: Ink.rubber / Double(scale)).subtracting(rub.gone)
        rub.last = p
        if !found.isEmpty {
            rub.gone.formUnion(found)
            let gone = rub.gone
            live { $0.removeStrokes(gone) }
        }
        ink.rub = rub
    }

    // MARK: The Draw tool

    /// The Draw tool was pressed: on, or off again.
    func toggleDraw() {
        guard !readOnly else { return }
        if editing != nil { commitEdit() }
        if ink.on {
            ink.leave()
        } else {
            linking = false
            linkFrom = nil
            clearSelection()
            ink.on = true
        }
    }

    #if os(iOS)
    // MARK: iPhone and iPad

    /// How drawing plugs into the touch layer (TouchLayer.swift).
    var inkHook: InkHook {
        func dot(_ sample: InkSample) -> InkDot {
            InkDot(location: sample.location, force: sample.kind == .pencil ? Double(sample.force) : nil,
                   time: sample.time, kind: sample.kind)
        }
        return InkHook(
            claims: { [weak self] sample in self?.inkClaims(dot(sample)) ?? false },
            began: { [weak self] sample in self?.inkBegan(dot(sample)) },
            moved: { [weak self] real, predicted in self?.inkMoved(real.map(dot), predicted.map(dot)) },
            ended: { [weak self] cancelled in self?.inkEnded(cancelled: cancelled) })
    }
    #endif

    // MARK: The Mac

    /// The Mac's click and drag while the Draw tool is on. True: the drag is a line (or the rubber)
    /// and must not reach the choose / move code. A drag that began as a line ends as one.
    func inkMouse(_ value: DragGesture.Value, ended: Bool) -> Bool {
        let desk = ink
        let dot = InkDot(location: value.location, force: nil, time: value.time.timeIntervalSinceReferenceDate, kind: .pointer)
        if desk.mouse?.start != value.startLocation {
            // A new drag (an older one that never ended is given up).
            if desk.mouse?.ink == true { inkEnded(cancelled: true) }
            let draws = desk.on && !readOnly && !board.isTimeline
            desk.mouse = (value.startLocation, draws)
            if draws {
                inkBegan(InkDot(location: value.startLocation, force: nil, time: dot.time, kind: .pointer))
                if value.location != value.startLocation { inkMoved([dot]) }
            }
        } else if desk.mouse?.ink == true, !ended {
            inkMoved([dot])
        }
        let draws = desk.mouse?.ink == true
        if ended {
            if draws {
                inkMoved([dot])
                inkEnded(cancelled: false)
            }
            desk.mouse = nil
        }
        return draws
    }
}
