import SwiftUI
import SeedboardCore
import AMSIcons

// 0.9 views: Focus on a frame (everything else dims), Show frames one by one, Tidy into a grid, and the small
// map in the corner of a big board. The rules are in the Core (Views09.swift); this file is the screen side.

/// What the views lane keeps for the open board. Plain values; every change tells the session to redraw.
@MainActor
final class ViewsDesk {
    private let changed: () -> Void
    init(changed: @escaping () -> Void) { self.changed = changed }

    /// Focus: the frame everything else is dimmed round.
    var focus: UUID? { didSet { changed() } }
    /// Show: the frames in their order, and the one shown now. Empty when no show is running.
    var order: [UUID] = [] { didSet { changed() } }
    var step = 0 { didSet { changed() } }
    /// The view as it was before Focus or Show began: Done and Escape bring it back.
    var before: Viewport?

    var showing: Bool { !order.isEmpty }

    /// The small map: on unless switched off (remembered on this device).
    static let mapKey = "seedboard.smallMap"
    static var mapOn: Bool {
        get { UserDefaults.standard.object(forKey: mapKey) as? Bool ?? true }
        set { if !LaunchOptions.sampleData { UserDefaults.standard.set(newValue, forKey: mapKey) } }
    }
}

extension BoardSession {
    /// A frame is chosen and Focus can start. (Not on a timeline or a "Who does what" board.)
    var canFocus: Bool { !board.placesItself && single?.kind == .frame && !views.showing }
    var focusRect: CGRect? { views.focus.flatMap { board.item($0) }?.frame }

    /// Moves the view to the box with a glide and marks it as moved by the owner.
    private func gotoBox(_ box: CGRect, top: Double, bottom: Double) {
        var next = place
        next.show(box, air: 36, top: top, bottom: bottom)
        glide(Glide.wholeBoard) { stand(at: next.offset, scale: next.scale); pan(by: .zero) }
    }

    private func comeBackToView() {
        guard let saved = views.before else { return }
        views.before = nil
        glide(Glide.wholeBoard) { stand(at: saved.offset, scale: saved.scale); pan(by: .zero) }
    }

    // MARK: Focus

    func startFocus() {
        guard canFocus, let frame = single else { return }
        commitEdit()
        if views.before == nil { views.before = place }
        let id = frame.id
        clearSelection()
        views.focus = id
        gotoBox(frame.frame, top: 50, bottom: 70)
        takeKeys()
    }

    func endFocus() {
        guard views.focus != nil else { return }
        views.focus = nil
        comeBackToView()
        takeKeys()
    }

    // MARK: Show

    var canShow: Bool { !board.placesItself && !board.showOrder().isEmpty }

    func startShow() {
        guard canShow, !views.showing else { return }
        commitEdit()
        let saved = views.before ?? place
        views.focus = nil
        clearSelection()
        linking = false
        linkFrom = nil
        ink.leave()
        views.before = saved
        views.step = 0
        views.order = board.showOrder()
        goToStep(0)
        takeKeys()
    }

    /// The frame of step `n` (frames that were removed meanwhile are skipped; the show ends when none is left).
    func goToStep(_ n: Int) {
        let live = views.order.filter { board.item($0) != nil }
        guard !live.isEmpty else { endShow(); return }
        if live != views.order { views.order = live }
        let at = min(max(n, 0), live.count - 1)
        views.step = at
        if let frame = board.item(live[at]) { gotoBox(frame.frame, top: 10, bottom: 60) }
    }

    func showNext(_ by: Int) { if views.showing { goToStep(views.step + by) } }

    func endShow() {
        guard views.showing else { return }
        views.order = []
        views.step = 0
        comeBackToView()
        takeKeys()
    }

    /// Keys while a show runs: ← and → and space go on, Escape ends. Everything else is left alone.
    func showKey(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        switch press.key {
        case .rightArrow, .space: showNext(1)
        case .leftArrow: showNext(-1)
        case .escape: endShow()
        default: break
        }
        return .handled
    }

    // MARK: Tidy into a grid

    /// How many things "Tidy into a grid" would line up now: the chosen ones (three or more), or with nothing
    /// chosen every loose sticky note.
    var gridTidyCount: Int {
        guard !readOnly, !board.placesItself else { return 0 }
        return board.gridMembers(selection).count
    }

    func tidyIntoGrid() {
        guard editing == nil else { return }
        let ids = selection
        let before = board.gridMembers(ids).count
        guard before >= 2 else { return }
        if change({ $0.tidyIntoGrid(ids) }) { tell(ids.isEmpty ? "Loose notes lined up in a grid." : "Lined up in a grid.") }
    }
}

// MARK: The screens

/// The small pill at the top while Focus runs: "Focus · name   Done".
struct FocusPill: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        if let id = session.views.focus {
            let name = session.board.item(id).map { $0.text.isEmpty ? "Frame" : $0.text } ?? "Frame"
            HStack(spacing: 8) {
                Text("Focus · \(name)")
                    .font(Txt.label)
                    .lineLimit(1)
                Button("Done") { session.endFocus() }
                    .buttonStyle(FilledButton(.frames))
                    .accessibilityIdentifier("focus.done")
            }
            .padding(.leading, 12)
            .padding(.trailing, 5)
            .padding(.vertical, 4)
            .background(Theme.plate, in: Capsule())
            .overlay(Capsule().stroke(Part.frames.text.opacity(0.4)))
            .plateShadow()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("focus.pill")
            .transition(.message)
        }
    }
}

/// The small bar at the bottom while frames are shown: "‹  2 of 5  ›  Done".
struct ShowBar: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        let total = session.views.order.count
        HStack(spacing: 6) {
            GlyphView(glyph: .new(.showFrames), size: 18, colour: Part.frames.text)
                .padding(.leading, 6)
                .accessibilityHidden(true)
            step("show.back", "Back", .control(.chevron), flip: true, on: session.views.step > 0) { session.showNext(-1) }
            Text("\(session.views.step + 1) of \(total)")
                .font(Txt.label)
                .monospacedDigit()
                .frame(minWidth: 56)
                .accessibilityIdentifier("show.count")
            step("show.next", "Next", .control(.chevron), flip: false, on: session.views.step < total - 1) { session.showNext(1) }
            Button("Done") { session.endShow() }
                .buttonStyle(FilledButton(.frames))
                .accessibilityIdentifier("show.done")
        }
        .padding(5)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Part.frames.text.opacity(0.4)))
        .plateShadow()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("show.bar")
    }

    private func step(_ id: String, _ help: String, _ glyph: Glyph, flip: Bool, on: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            GlyphView(glyph: glyph, size: 18, colour: Part.frames.text)
                .rotationEffect(.degrees(flip ? 180 : 0))
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(!on)
        .opacity(on ? 1 : 0.35)
        .accessibilityLabel(help)
        .accessibilityIdentifier(id)
    }
}

/// Lies over the board: while frames are shown a clear layer takes a swipe left or right for the next and
/// the one before (the board itself is not touched then); and the small map in the corner of a big board.
struct ViewsOverlay: View {
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme

    /// For pictures: `-views focus | show | map` (with `-board "Trip to Spain"`) starts Focus on the first frame,
    /// the frame show, or zooms in on a board so the small map shows — once, a moment after the board is shown.
    private static var launchUsed = false

    private func launch() {
        guard !Self.launchUsed, let word = LaunchOptions.value(for: "-views") else { return }
        Self.launchUsed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            switch word {
            case "focus":
                if let id = session.board.showOrder().first { session.select(id, adding: false); session.startFocus() }
            case "show": session.startShow()
            case "map":
                if let first = session.board.items.first(where: { $0.kind != .frame }) {
                    session.zoom(to: 1.5, around: session.toScreen(first.centre))
                }
            default: break
            }
        }
    }

    var body: some View {
        ZStack { content }.onAppear { launch() }
    }

    @ViewBuilder
    private var content: some View {
        if session.views.showing {
            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 28).onEnded { value in
                    let across = value.translation.width, down = value.translation.height
                    guard abs(across) > abs(down) * 1.5 else { return }
                    session.showNext(across < 0 ? 1 : -1)
                })
                .accessibilityHidden(true)
        } else if SmallMap.shows(session) {
            SmallMap(session: session, paint: Paint(scheme))
        }
    }
}

/// The small map: every thing as a tiny rectangle in its colour, the visible part as an outline; a press or a drag
/// on it moves the view there.
struct SmallMap: View {
    @ObservedObject var session: BoardSession
    let paint: Paint

    static func size() -> CGSize { Finger.phone ? CGSize(width: 90, height: 60) : CGSize(width: 120, height: 80) }

    static func shows(_ session: BoardSession) -> Bool {
        guard ViewsDesk.mapOn, !session.board.placesItself, !session.ink.on, !session.views.showing,
              session.viewSize.width > 10, let content = session.board.bounds else { return false }
        return BoardMap.isNeeded(content: content, visible: session.visibleBoardRect)
    }

    var body: some View {
        let size = Self.size()
        if let content = session.board.bounds {
            let visible = session.visibleBoardRect
            let map = BoardMap(content: content, visible: visible, size: size)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for item in session.board.items where !session.board.isHidden(item.id) {
                        let r = map.toMap(item.frame)
                        let box = CGRect(x: r.minX, y: r.minY, width: max(r.width, 2), height: max(r.height, 2))
                        let name = session.facts.colour[item.id] ?? (item.colour.isEmpty ? "grey" : item.colour)
                        if item.kind == .frame {
                            ctx.stroke(Path(box), with: .color(paint.line(name).opacity(0.7)), lineWidth: 1)
                        } else if item.kind == .note {
                            ctx.fill(Path(box), with: .color(paint.note(Palette.notes.contains(name) ? name : "yellow")))
                        } else {
                            ctx.fill(Path(box), with: .color(paint.line(name).opacity(0.85)))
                        }
                    }
                    let seen = map.toMap(visible)
                    ctx.stroke(Path(roundedRect: seen, cornerRadius: 2), with: .color(paint.chosen), lineWidth: 1.5)
                }
            }
            .frame(width: size.width, height: size.height)
            .background(Theme.plate.opacity(0.92), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.primary.opacity(0.14)))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .plateShadow()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                // The map as it was when the press began stays the one that is read, so the drag does not chase itself.
                session.centreView(on: map.toBoard(value.location))
            })
            .padding(.trailing, 10)
            .padding(.bottom, Finger.phone ? 124 : 66)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Small map")
            .accessibilityIdentifier("board.smallMap")
        }
    }
}

extension BoardSession {
    /// The part of the board on screen.
    var visibleBoardRect: CGRect { place.visibleBoard }

    /// Puts this board point in the middle of the view (the small map was pressed).
    func centreView(on p: CGPoint) {
        stopGlide()
        offset = CGSize(width: viewSize.width / 2 - p.x * scale, height: viewSize.height / 2 - p.y * scale)
        pan(by: .zero)
    }
}

/// The lines of the board's More menu: Show frames, Small map.
struct ViewsMoreLines: View {
    @ObservedObject var session: BoardSession
    @State private var mapOn = ViewsDesk.mapOn

    var body: some View {
        if !session.board.placesItself && !session.starterDraft {
            Button { session.startShow() } label: { MarkLabel("Show frames", .showFrames) }
                .disabled(!session.canShow)
                .accessibilityIdentifier("show.start")
            Button("Tidy into a grid") { session.tidyIntoGrid(); session.takeKeys() }
                .disabled(session.gridTidyCount < 2)
                .accessibilityIdentifier("more.tidyGrid")
            Toggle(isOn: Binding(get: { mapOn }, set: { mapOn = $0; ViewsDesk.mapOn = $0; session.objectWillChange.send() })) { MarkLabel("Small map", .smallMap) }
                .accessibilityIdentifier("more.smallMap")
        }
    }
}

/// The Mac menu lines: Focus (⌥⌘F), Show Frames (⌥⌘P), Tidy into a Grid (⌥⌘G).
struct ViewsCommands: Commands {
    @FocusedObject private var session: BoardSession?

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Focus on the Frame") { session?.startFocus() }
                .keyboardShortcut("f", modifiers: [.option, .command])
                .disabled(!(session?.canFocus ?? false) || session?.editing != nil)
            Button("Show Frames") { session?.startShow() }
                .keyboardShortcut("p", modifiers: [.option, .command])
                .disabled(!(session?.canShow ?? false) || session?.views.showing == true)
            Button("Tidy into a Grid") { session?.tidyIntoGrid() }
                .keyboardShortcut("g", modifiers: [.option, .command])
                .disabled((session?.gridTidyCount ?? 0) < 2 || session?.editing != nil)
        }
    }
}

extension BarActions {
    /// "Focus" for a chosen frame: bar, right-click menu.
    func focusAction(show: BarAction.Show = .wideWord, drop: Int = 3) -> BarAction {
        let session = session
        return BarAction(id: prefix + "focus", word: "Focus", glyph: .new(.focus),
                         kind: .press { session.startFocus() }, show: show, enabled: session.canFocus, drop: drop)
    }
}
