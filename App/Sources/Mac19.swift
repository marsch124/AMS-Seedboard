import SwiftUI
import Combine
import SeedboardCore
import AMSIcons
#if os(macOS)
import AppKit
#endif

// 0.19 (his picks 16, 48, 49, 50): the "+" with its hold menu, the Mac's hideable board list (⌃⌘S),
// the iPad's tool bar that can be dragged to an edge, and the Mac's Quick look on a board row.

/// Every SF Symbol name this file uses, in one place (the lead can swap a name after Martin has looked).
enum Marks19Mac {
    static let addNote = "note.text"
    static let addIdea = "lightbulb"
    static let addShape = "square.on.circle"
    static let addText = "textformat"
    static let quickLook = "eye"
}

/// The one place for the shortcut of View ▸ Hide Sidebar / Show Sidebar.
enum Shortcut19 {
    static let sidebarKey = KeyEquivalent("s")
    static let sidebarModifiers: EventModifiers = [.control, .command]
}

// MARK: 16 — the "+" with its hold menu

/// A "+" tile at the start of the tool bar. A plain press adds a sticky note; holding it (the Mac: a right-click
/// or click-and-hold) lists Note, Idea, Shape and Text.
struct AddTool: View {
    @ObservedObject var session: BoardSession
    @Environment(\.toolSide) private var side

    private func add(_ kind: ItemKind) {
        session.add(kind)
        session.takeKeys()
    }

    private var choices: some View {
        Group {
            Button { add(.note) } label: { Label("Note", systemImage: Marks19Mac.addNote) }
                .accessibilityIdentifier("tool.add.note")
            Button { add(.idea) } label: { Label("Idea", systemImage: Marks19Mac.addIdea) }
                .accessibilityIdentifier("tool.add.idea")
            Button { add(ShapeChoice.shared.last) } label: { Label("Shape", systemImage: Marks19Mac.addShape) }
                .accessibilityIdentifier("tool.add.shape")
            Button { add(.text) } label: { Label("Text", systemImage: Marks19Mac.addText) }
                .accessibilityIdentifier("tool.add.text")
        }
    }

    var body: some View {
        let tile = ControlMarkView(.add, size: ToolSize.mark(side), colour: Part.boards.text)
            .frame(width: side, height: side)
            .background(Part.boards.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .pressRoom(3, 3)
        Menu {
            choices
        } label: {
            tile
        } primaryAction: {
            add(.note)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(PressStyle(tint: Part.boards.text))
        #if os(macOS)
        .contextMenu { choices }
        #endif
        .help("Add a sticky note — hold for Note, Idea, Shape, Text")
        .accessibilityLabel("Add")
        .accessibilityHint("Adds a sticky note. Hold for Note, Idea, Shape or Text.")
        .accessibilityIdentifier("tool.add")
    }
}

// MARK: 48 — the board list can be hidden (Mac)

/// Whether the Mac's board list is hidden, kept per Mac.
@MainActor
final class SidebarHabit: ObservableObject {
    static let shared = SidebarHabit()
    private static let key = "mac.sidebarHidden"

    @Published var hidden: Bool {
        didSet { if !LaunchOptions.sampleData { UserDefaults.standard.set(hidden, forKey: SidebarHabit.key) } }
    }

    private init() {
        hidden = LaunchOptions.sampleData ? false : UserDefaults.standard.bool(forKey: SidebarHabit.key)
    }

    func toggle() { hidden.toggle() }
}

/// View ▸ Hide Sidebar / Show Sidebar.
struct SidebarCommand19: View {
    @ObservedObject private var habit = SidebarHabit.shared

    var body: some View {
        Button(habit.hidden ? "Show Sidebar" : "Hide Sidebar") { habit.toggle() }
            .keyboardShortcut(Shortcut19.sidebarKey, modifiers: Shortcut19.sidebarModifiers)
    }
}

// MARK: 49 — the iPad's tool bar at any edge

/// Where the tool bar sits on this iPad. The iPhone and the Mac always have it at the bottom.
@MainActor
final class DockDesk: ObservableObject {
    static let shared = DockDesk()
    private static let key = "tool.dock"

    static var onThisDevice: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    @Published private(set) var side: ToolDock

    private init() {
        side = DockDesk.onThisDevice && !LaunchOptions.sampleData ? ToolDock.stored(UserDefaults.standard.string(forKey: DockDesk.key)) : .bottom
    }

    func move(to new: ToolDock) {
        guard DockDesk.onThisDevice else { return }
        side = new
        UserDefaults.standard.set(new.rawValue, forKey: DockDesk.key)
    }
}

private struct BoardAreaKey: EnvironmentKey { static let defaultValue = CGSize.zero }
private struct ToolVerticalKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var boardArea: CGSize {
        get { self[BoardAreaKey.self] }
        set { self[BoardAreaKey.self] = newValue }
    }
    var toolVertical: Bool {
        get { self[ToolVerticalKey.self] }
        set { self[ToolVerticalKey.self] = newValue }
    }
}

/// On the board: measures it, names its coordinate space, and shows the tool bar when it is docked left or right.
struct DockArea: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var dock = DockDesk.shared
    @State private var area = CGSize.zero

    static let space = "seedboard.board"

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: DockArea.space)
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { area = geo.size }
                    .onChange(of: geo.size) { _, new in area = new }
            })
            .environment(\.boardArea, area)
            .overlay(alignment: dock.side == .right ? .trailing : .leading) {
                if DockDesk.docked(session) && dock.side.vertical {
                    ViewThatFits(in: .vertical) {
                        ToolPill(session: session)
                        ToolPill(session: session).environment(\.toolSide, 36)
                        ToolPill(session: session).environment(\.toolSide, 32)
                        ScrollView(.vertical, showsIndicators: false) { ToolPill(session: session).environment(\.toolSide, 32) }
                    }
                    .environment(\.toolVertical, true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 60)
                }
            }
    }
}

extension DockDesk {
    /// The bar is off the bottom row: only on an iPad, only for an ordinary board that can be changed.
    static func docked(_ session: BoardSession) -> Bool {
        DockDesk.onThisDevice && DockDesk.shared.side != .bottom && !session.readOnly
            && !session.board.isSequence && !session.board.isTimeline
    }
}

/// The small rounded capsule on the tool bar (Apple's sheet-grabber look). Drag it to another edge.
struct ToolGrabber: View {
    @ObservedObject private var dock = DockDesk.shared
    @Environment(\.boardArea) private var area
    @Environment(\.toolVertical) private var vertical
    @Binding var drag: CGSize

    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.55))
            .frame(width: vertical ? 5 : 36, height: vertical ? 36 : 5)
            .padding(vertical ? .horizontal : .vertical, 5)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(DockArea.space))
                    .onChanged { drag = $0.translation }
                    .onEnded { value in
                        let target = ToolDock.nearest(x: value.location.x, y: value.location.y,
                                                      width: area.width, height: area.height)
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            drag = .zero
                            dock.move(to: target)
                        }
                    }
            )
            .help("Drag to move the tool bar to another edge")
            .accessibilityLabel("Move the tool bar")
            .accessibilityHint("Drag to the bottom, left or right edge.")
            .accessibilityAction(named: "Move to the left") { dock.move(to: .left) }
            .accessibilityAction(named: "Move to the right") { dock.move(to: .right) }
            .accessibilityAction(named: "Move to the bottom") { dock.move(to: .bottom) }
            .accessibilityIdentifier("board.tools.grabber")
    }
}

// MARK: 50 — Quick look on a board row (Mac)

/// Hover a board row for about 0.6 s: a small popover with its name and first lines. Never on touch devices.
struct BoardQuickLook: ViewModifier {
    let board: Board
    #if os(macOS)
    @State private var shown = false
    @State private var wait: Task<Void, Never>?

    static let delay: Duration = .milliseconds(600)

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                wait?.cancel()
                if inside {
                    wait = Task { @MainActor in
                        try? await Task.sleep(for: BoardQuickLook.delay)
                        if !Task.isCancelled { shown = true }
                    }
                } else {
                    shown = false
                }
            }
            .popover(isPresented: $shown, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(board.title).font(.headline).lineLimit(1)
                    let lines = board.quickLookLines()
                    if lines.isEmpty {
                        Text("Nothing on it yet").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.callout).lineLimit(1).truncationMode(.tail)
                        }
                    }
                }
                .padding(10)
                .frame(width: 240, alignment: .leading)
                .accessibilityIdentifier("boards.quicklook")
            }
    }
    #else
    func body(content: Content) -> some View { content }
    #endif
}
