import SwiftUI
import Combine
import CoreSpotlight
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Pick 25: a fuller menu bar on the Mac. The same commands serve an iPad with a keyboard, where
// they show when ⌘ is held. The Board menu itself (and Undo, Redo) is `BoardCommands` in BoardView.swift.

/// What the menus and the screens tell each other: a menu line asks for a page, the board says
/// whether its drawing surface has the keys.
@MainActor
final class MenuDesk: ObservableObject {
    static let shared = MenuDesk()

    /// File ▸ New Board: the starter choice is asked for.
    @Published var choosingStarter = false
    /// The board whose drawing surface has the keys (nil: a text field, a page or a button has them).
    @Published private(set) var keysBoard: UUID?
    /// The Mac: the board's window is the one being typed in (not a page over it, not Settings).
    @Published var windowHasKeys = true
    /// File ▸ Rename… and File ▸ Remove Board…: the open board shows its own question.
    let rename = PassthroughSubject<Void, Never>()
    let remove = PassthroughSubject<Void, Never>()

    func keys(_ has: Bool, board: UUID) {
        if has {
            if keysBoard != board { keysBoard = board }
        } else if keysBoard == board {
            keysBoard = nil
        }
    }

    /// True when a letter key pressed now would reach this board's drawing surface.
    func surfaceHasKeys(_ session: BoardSession) -> Bool {
        keysBoard == session.board.id && windowHasKeys && session.editing == nil
    }
}

/// File, Edit, View and Insert.
struct SeedMenus: Commands {
    let model: AppModel
    @FocusedObject private var session: BoardSession?
    @ObservedObject private var desk = MenuDesk.shared

    /// A board is open and may be changed.
    private var canChange: Bool { session.map { !$0.readOnly } ?? false }
    private var typing: Bool { session?.editing != nil }

    /// The letter keys are tools only while the drawing surface has the keys and nothing is chosen
    /// (with one thing chosen a letter starts typing in it; in a text field it is a letter). Only then
    /// do the Insert lines carry their letter, so a menu key can never take a letter away from words.
    private var lettersAreTools: Bool {
        guard let session else { return false }
        return MenuRules.lettersAreTools(surfaceHasKeys: desk.surfaceHasKeys(session), typing: session.editing != nil,
                                         chosen: session.selection.count, arrowChosen: session.selectedLink != nil,
                                         readOnly: session.readOnly)
    }

    var body: some Commands {
        // File. (One window on the Mac: no "New Window".)
        CommandGroup(replacing: .newItem) {
            Button("New Board") { if model.loaded { desk.choosingStarter = true } }
                .keyboardShortcut("n", modifiers: .command)
            Button("New Blank Board") { if model.loaded { model.newBoard(.blank) } }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Rename…") { desk.rename.send() }
                .disabled(!canChange)
            Button("Send to PARAGON…") {
                session?.commitEdit()
                model.showSend = true
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(session == nil || session?.starterDraft == true)
            Button("Share a Picture…") {
                if let session {
                    session.commitEdit()
                    if !SharePicture.show(session.board) { model.say("The picture could not be made.") }
                }
            }
            .disabled(session?.board.isEmpty ?? true)
            Divider()
            Button("Save as a Starter…") {
                if let session { session.commitEdit(); model.ask(.save(session.board)) }
            }
            .disabled(!canChange || session?.starterDraft == true)
            Button("Starters…") { model.ask(.page) }
            Divider()
            Button("Remove Board…") { desk.remove.send() }
                .disabled(session == nil || session?.starterDraft == true)
        }

        // Edit. On the Mac, Delete and Select All are the system's own lines: the board answers them
        // while it has the keys (`BoardKeys`), a text field answers them while words are typed.
        CommandGroup(after: .pasteboard) {
            #if !os(macOS)
            Button("Select All") {
                if let session, desk.surfaceHasKeys(session) { session.selectAll() } else { TextKeys.selectAll() }
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(session == nil)
            #endif
            Button("Duplicate") { session?.duplicateSelection() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!canChange || typing || (session?.selection.isEmpty ?? true))
        }

        // View.
        CommandGroup(before: .toolbar) {
            Button("Zoom In") { if let session { session.zoom(to: session.scale * 1.25) } }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(session == nil)
            Button("Zoom Out") { if let session { session.zoom(to: session.scale / 1.25) } }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(session == nil)
            Button("Actual Size") { session?.zoom(to: 1) }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(session == nil)
            Button("Show the Whole Board") { session?.fit() }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(session == nil)
            Divider()
        }

        // Insert: every tool with its letter (the letters `CanvasView.handleKey` answers).
        CommandMenu("Insert") {
            ForEach(MenuRules.tools, id: \.letter) { tool($0) }
            Divider()
            // Two shapes that have a letter but no button of their own.
            ForEach(MenuRules.moreShapes, id: \.letter) { tool($0) }
        }
    }

    @ViewBuilder
    private func tool(_ line: MenuRules.ToolLine) -> some View {
        let button = Button(line.name) {
            guard let session else { return }
            if let kind = line.kind {
                session.add(kind)
            } else {
                // The arrow tool, as its button: with one shape chosen, the arrow starts there.
                session.commitEdit()
                session.linking.toggle()
                session.linkFrom = session.linking ? session.single.flatMap { $0.kind == .frame ? nil : $0.id } : nil
            }
            session.takeKeys()
        }
        // (A timeline and a "Who does what" board have their own tools.)
        .disabled(!canChange || session?.board.placesItself == true)
        if lettersAreTools {
            button.keyboardShortcut(KeyEquivalent(line.letter), modifiers: [])
        } else {
            button
        }
    }
}

// MARK: The board's side

/// On the drawing surface (`CanvasView`): tells the menus whether it has the keys; on the Mac it also
/// answers the Edit menu's own Delete and Select All, and lets Space with a drag slide the board.
struct BoardKeys: ViewModifier {
    @ObservedObject var session: BoardSession
    let has: Bool

    private var canDelete: Bool {
        !session.readOnly && session.editing == nil && (!session.selection.isEmpty || session.selectedLink != nil)
    }

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            // `delete:` is the menu line only; the Delete key itself stays with the board's own key handling.
            .onCommand(#selector(NSText.delete(_:)), perform: canDelete ? { session.deleteSelection() } : nil)
            .onCommand(#selector(NSResponder.selectAll(_:)),
                       perform: session.editing == nil && !session.board.isEmpty ? { session.selectAll() } : nil)
            .background(SpaceHand(session: session))
            #endif
            .onChange(of: has, initial: true) { _, new in MenuDesk.shared.keys(new, board: session.board.id) }
            .onDisappear { MenuDesk.shared.keys(false, board: session.board.id) }
    }
}

/// On the open board (`BoardView`): File ▸ Rename… and Remove Board… open the board's own two questions.
struct MenuAsks: ViewModifier {
    let rename: () -> Void
    let remove: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(MenuDesk.shared.rename) { rename() }
            .onReceive(MenuDesk.shared.remove) { remove() }
    }
}

/// On the whole window: the starter choice for File ▸ New Board, a board found by the device's search,
/// and the two watchers that remember where the owner left and keep the search up to date.
struct OutsideDoors: ViewModifier {
    let model: AppModel
    @ObservedObject private var desk = MenuDesk.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $desk.choosingStarter, onDismiss: { model.session?.takeKeys() }) {
                StarterSheet { starter in
                    desk.choosingStarter = false
                    if let starter { model.newBoard(from: starter) }
                }
                .environmentObject(model)
            }
            // A board picked in the device's search (Spotlight) opens like a link to it.
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let word = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                      let id = UUID(uuidString: word), let url = URL(string: "seedboard://board/\(id.uuidString)") else { return }
                model.open(url: url)
            }
            .onAppear {
                Remember.shared.watch(model)
                SpotlightIndex.shared.watch(model)
                // For pictures: `-starters` shows the starter choice.
                if LaunchOptions.arguments.contains("-starters") { desk.choosingStarter = true }
            }
    }
}

/// The starter choice as a page of its own, with Cancel (Escape on the Mac).
private struct StarterSheet: View {
    let done: (ShelfStarter?) -> Void
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            StarterPicker(pick: { done($0) }, close: { done(nil) })
            #else
            StarterPicker(wide: true, pick: { done($0) }, close: { done(nil) })
            #endif
            HStack {
                Spacer()
                Button("Cancel") { done(nil) }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("starters.cancel")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        #if !os(macOS)
        .presentationDetents([.height(CGFloat(model.shelf.shown.count) * 46 + 104)])
        #endif
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("starters.sheet")
    }
}

// MARK: Share a picture from the menu

@MainActor
enum SharePicture {
    /// Makes the board's picture and opens the system's share choice. False when no picture could be made.
    static func show(_ board: Board) -> Bool {
        guard let png = BoardPicture.png(of: board) else { return false }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Share", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = board.title.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
        let file = folder.appendingPathComponent((name.isEmpty ? "Board" : name) + ".png")
        guard (try? png.write(to: file, options: .atomic)) != nil else { return false }
        #if os(macOS)
        guard let view = (NSApp.keyWindow ?? NSApp.mainWindow)?.contentView else { return false }
        // Under the window's top bar, in the middle.
        let top = view.isFlipped ? view.bounds.minY + 56 : view.bounds.maxY - 56
        NSSharingServicePicker(items: [file]).show(relativeTo: CGRect(x: view.bounds.midX - 1, y: top, width: 2, height: 2), of: view, preferredEdge: .minY)
        return true
        #else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return false }
        while let over = top.presentedViewController { top = over }
        let page = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        page.popoverPresentationController?.sourceView = top.view
        page.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: 56, width: 1, height: 1)
        top.present(page, animated: true)
        return true
        #endif
    }
}

#if !os(macOS)
/// ⌘A while words are typed (on the board, in a name field, on the Send page) belongs to the words.
enum TextKeys {
    static func selectAll() {
        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: Space and a drag slide the board (Mac)

#if os(macOS)
/// While Space is held on the board the pointer is an open hand, and a drag slides the board, wherever
/// it starts. A short press of Space still starts typing in the one chosen thing (now when the key is
/// let go). While words are typed, or a text field or a button has the keys, Space is left alone.
struct SpaceHand: NSViewRepresentable {
    let session: BoardSession

    func makeNSView(context: Context) -> HandView {
        let view = HandView()
        view.session = session
        return view
    }

    func updateNSView(_ view: HandView, context: Context) { view.session = session }

    final class HandView: NSView {
        weak var session: BoardSession?
        private var monitor: Any?
        private var watchers: [NSObjectProtocol] = []
        private var spaceDown = false
        private var spaceBegan = Date.distantPast
        private var sliding = false
        /// The board was slid during this press of Space: letting go does not start typing.
        private var slid = false
        private var last = CGPoint.zero

        private static let space: UInt16 = 49

        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopWatching()
            guard let window else { return }
            MenuDesk.shared.windowHasKeys = window.isKeyWindow || window.attachedSheet == nil
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
                guard let self else { return event }
                var answer: NSEvent? = event
                MainActor.assumeIsolated { answer = self.take(event) }
                return answer
            }
            let centre = NotificationCenter.default
            watchers = [
                centre.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { _ in
                    MainActor.assumeIsolated { MenuDesk.shared.windowHasKeys = true }
                },
                centre.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        MenuDesk.shared.windowHasKeys = false
                        self?.letGo()
                    }
                },
                centre.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.letGo() }
                },
            ]
        }

        private func stopWatching() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            watchers.forEach(NotificationCenter.default.removeObserver)
            watchers = []
            letGo()
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
            watchers.forEach(NotificationCenter.default.removeObserver)
        }

        /// The key never came up (the window or the app was left): everything is as before.
        private func letGo() {
            guard spaceDown || sliding else { return }
            spaceDown = false
            sliding = false
            NSCursor.arrow.set()
        }

        /// Space belongs to the board only while its drawing surface has the keys and no words are typed.
        private func spaceIsMine(_ event: NSEvent, _ session: BoardSession) -> Bool {
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
            guard MenuDesk.shared.surfaceHasKeys(session) else { return false }
            return !(window?.firstResponder is NSText)
        }

        private func take(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window, let session else { return event }
            switch event.type {
            case .keyDown:
                guard event.keyCode == Self.space, spaceDown || spaceIsMine(event, session) else { return event }
                if !spaceDown {
                    spaceDown = true
                    slid = false
                    spaceBegan = Date()
                }
                // The key repeats while it is held: the hand is shown again each time, whatever reset it.
                (sliding ? NSCursor.closedHand : NSCursor.openHand).set()
                return nil
            case .keyUp:
                guard event.keyCode == Self.space, spaceDown else { return event }
                spaceDown = false
                if !sliding { NSCursor.arrow.set() }
                // A short press without a drag: typing starts in the one chosen thing, as before.
                if MenuRules.spaceStartsTyping(slid: slid, held: Date().timeIntervalSince(spaceBegan), chosen: session.selection.count,
                                               typing: session.editing != nil), let item = session.single {
                    session.beginEdit(item.id)
                }
                return nil
            case .leftMouseDown:
                let here = convert(event.locationInWindow, from: nil)
                guard spaceDown, bounds.contains(here) else { return event }
                sliding = true
                slid = true
                last = here
                NSCursor.closedHand.set()
                return nil
            case .leftMouseDragged:
                guard sliding else { return event }
                let here = convert(event.locationInWindow, from: nil)
                session.pan(by: CGSize(width: here.x - last.x, height: here.y - last.y))
                last = here
                NSCursor.closedHand.set()
                return nil
            case .leftMouseUp:
                guard sliding else { return event }
                sliding = false
                (spaceDown ? NSCursor.openHand : NSCursor.arrow).set()
                return nil
            default:
                return event
            }
        }
    }
}
#endif
