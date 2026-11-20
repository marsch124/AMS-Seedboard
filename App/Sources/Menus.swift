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
    private let desk14 = Boards14Desk.shared

    /// A board is open and may be changed.
    private var canChange: Bool { session.map { !$0.readOnly } ?? false }
    private var typing: Bool { session?.editing != nil }
    /// 0.9: the marks (vote dots, pinning, tick lists) work on an ordinary board that may be changed.
    private var marksOn: Bool { session?.marksOn ?? false }

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
            // 0.11: the last five boards opened (Extras11.swift).
            #if os(macOS)
            OpenRecentMenu(model: model)
            #endif
            Divider()
            Button("Rename…") { desk.rename.send() }
                .disabled(!canChange)
            Button("Due Day…") { DueDesk.shared.show = true }
                .disabled(!canChange || session?.starterDraft == true)
            Button("Send to PARAGON…") {
                session?.commitEdit()
                model.showSend = true
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(session == nil || session?.starterDraft == true)
            // 0.9: the Send page for the chosen frame alone, and Today's three (ParagonNine.swift).
            Button("Send This Frame to PARAGON…") { if let session { ParagonDesk.shared.sendFrame(session) } }
                .disabled(session?.frameToSend == nil || session?.starterDraft == true)
            Button("Today's Three to PARAGON…") { if let session { ParagonDesk.shared.askToday(session) } }
                .disabled(session?.todayThreeOffered != true)
            Button("Share…") { if let session { ShareDesk.shared.ask(session) } }
                .disabled(session?.board.isEmpty ?? true)
            // 0.5: a new timeline board from this board's ideas and shapes (TimelineOfIt.swift).
            Button("Make a Timeline of It…") {
                if let session { model.makeTimeline(of: session) }
            }
            .disabled(session == nil || session?.board.isEmpty == true || session?.board.placesItself == true || session?.starterDraft == true)
            // 0.9: a timeline: phases fold away; milestones go into the calendar (CalendarAdd.swift).
            Button("Fold All Phases") { session?.foldAllTimelinePhases(true) }
                .disabled(session == nil || session?.readOnly == true || session?.board.canFoldAny != true)
            Button("Unfold All Phases") { session?.foldAllTimelinePhases(false) }
                .disabled(session == nil || session?.readOnly == true || session?.board.canUnfoldAny != true)
            // 0.14: Hide done bars; Set / Clear the plan (a timeline).
            Button(session?.board.hidesDone == true ? "Show Done Bars" : "Hide Done Bars") { session?.toggleHideDone() }
                .disabled(session == nil || session?.readOnly == true || session?.board.isTimeline != true)
            Button("Set the Plan") { if let w = session?.setTimelinePlan() { model.say(w) } }
                .disabled(session == nil || session?.readOnly == true || session?.board.isTimeline != true)
            Button("Clear the Plan") { session?.clearTimelinePlan() }
                .disabled(session == nil || session?.readOnly == true || session?.board.hasPlan != true)
            // 0.17: purple means PARAGON — old purple milestones and mind-map branches get another colour.
            Button("Make Milestones Orange") { _ = session?.change { $0.makeMilestonesOrange() } }
                .disabled(session == nil || session?.readOnly == true || (session?.board.purpleMilestones ?? 0) == 0)
            // 0.18: purple (PARAGON) and red (late) main branches.
            Button("Recolour Branches") { _ = session?.change { $0.recolourBranches() } }
                .disabled(session == nil || session?.readOnly == true || (session?.board.oddBranches() ?? 0) == 0)
            Button("Add to Calendar…") {
                session?.commitEdit()
                model.showCalendar = true
            }
            .disabled(session?.canAddToCalendar != true)
            Divider()
            Button("Save as a Starter…") {
                if let session { session.commitEdit(); model.ask(.save(session.board)) }
            }
            .disabled(!canChange || session?.starterDraft == true)
            Button("Starters…") { model.ask(.page) }
            // 0.14: a Markdown, text or OPML outline becomes a new mind map (Boards14.swift).
            Button("Open Outline…") { if model.loaded { desk14.openingOutline = true } }
            Divider()
            // 0.9: out of the list, never deleted; "Put away (n)" at the bottom of the list brings it back.
            Button("Put Board Away") {
                if let session { model.putAway(session.board.id) }
            }
            .disabled(!canChange || session?.starterDraft == true || session?.board.isPutAway == true)
            Button("Remove Board…") { desk.remove.send() }
                .disabled(session == nil || session?.starterDraft == true)
        }

        // File ▸ Print… ⌘P (BoardPaper.swift).
        CommandGroup(replacing: .printItem) { PrintLine(session: session) }

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
            // 0.14 (look): copy the look of one thing, paste it on the chosen ones; today's date at the cursor.
            Divider()
            Button("Copy Look") { session?.copyLook() }
                .keyboardShortcut("c", modifiers: [.option, .command])
                .disabled(!canChange || typing || !(session?.canCopyLook ?? false))
            // ⌥⌘V is taken by Vote Dot, so Paste Look has Control as well.
            Button("Paste Look") { session?.pasteLook() }
                .keyboardShortcut("v", modifiers: [.control, .option, .command])
                .disabled(!canChange || typing || !(session?.canPasteLook ?? false))
            Button("Insert Today's Date") { session?.insertToday() }
                .keyboardShortcut("d", modifiers: [.shift, .command])
                .disabled(!canChange || !typing)
            // 0.9 (Marks): a dot for each chosen thing, pin it, a tick list in a note.
            Divider()
            Button("Vote Dot") { session?.vote() }
                .keyboardShortcut("v", modifiers: [.option, .command])
                .disabled(!marksOn || typing || (session?.selection.isEmpty ?? true))
            Button("Pin in Place") { session?.togglePinned() }
                .disabled(!marksOn || typing || (session?.selection.isEmpty ?? true))
            Button("Tick List") { session?.tickList() }
                .disabled(!marksOn || typing || !(session?.selection.contains { session?.board.item($0)?.kind == .note } ?? false))
        }

        // View.
        CommandGroup(before: .toolbar) {
            Button("Zoom In") { session?.zoomStep(by: 1.25) }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(session == nil)
            Button("Zoom Out") { session?.zoomStep(by: 1 / 1.25) }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(session == nil)
            Button("Actual Size") { session?.actualSize() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(session == nil)
            Button("Show the Whole Board") { session?.fit() }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(session == nil)
            // 0.19 (17): freeze the board for reading.
            Button(session?.readMode == true ? "Leave Read Mode" : "Read Mode") { session?.setReadMode(session?.readMode != true) }
                .keyboardShortcut("r", modifiers: [.option, .command])
                .disabled(session == nil || session?.board.canBeChanged != true || session?.starterDraft == true)
            // 0.14 (look): the chosen things fill the screen.
            Button("Zoom to Chosen") { session?.zoomToChosen() }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(!(session?.canZoomToChosen ?? false) || typing)
            // 0.9: on a timeline: brings today into view (the key T does the same while the timeline has the keys).
            Button("Go to Today") { session?.timelineShowToday() }
                .disabled(session?.board.isTimeline != true)
            // 0.14 (22): the brainstorm timer (PiecesPage.swift).
            Button("Brainstorm Timer") {
                if let session { BrainstormDesk.shared.offer(on: session.board.id) }
            }
            .disabled(session == nil || session?.board.placesItself == true)
            Divider()
        }

        // Insert: every tool with its letter (the letters `CanvasView.handleKey` answers).
        CommandMenu("Insert") {
            ForEach(MenuRules.tools, id: \.letter) { tool($0) }
            Divider()
            // Two shapes that have a letter but no button of their own.
            ForEach(MenuRules.moreShapes, id: \.letter) { tool($0) }
            Divider()
            // A picture (letter P), then the Draw tool (letter S, for Sketch): on boards that have them.
            PictureInsertLine(enabled: canChange && session?.board.placesItself != true, letter: lettersAreTools)
            // 0.14: a table of cells (3 × 3, empty).
            Button("Table") { session?.add(.table); session?.takeKeys() }
                .disabled(!canChange || session?.board.placesItself == true)
            drawLine
            // 0.9: the chosen picture takes drawing; the chosen sketch's handwriting becomes typed words.
            // 0.14 (27): a saved piece goes onto the board (PiecesPage.swift).
            Button("Piece…") { if let session { PieceDesk.shared.openPage(session) } }
                .disabled(session == nil || !(session.map { PieceDesk.shared.canAdd($0) } ?? false))
            Button("Draw on Picture") {
                guard let session, let id = session.single?.id else { return }
                session.drawOnPicture(id)
                session.takeKeys()
            }
            .disabled(!canChange || session?.board.placesItself == true || session?.single?.kind != .picture)
            Button("Make Sketch Typed") {
                guard let session, let id = session.single?.id else { return }
                session.makeTyped(id)
            }
            .disabled(!canChange || session?.board.placesItself == true || session?.single?.kind != .drawing)
        }
    }

    @ViewBuilder
    private var drawLine: some View {
        let button = Button("Draw") {
            guard let session else { return }
            session.toggleDraw()
            session.takeKeys()
        }
        .disabled(!canChange || session?.board.placesItself == true)
        if lettersAreTools {
            button.keyboardShortcut(KeyEquivalent("s"), modifiers: [])
        } else {
            button
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
            // 0.5: a photo, a scan or a sketch from the iPhone lands on this board (MacHabits.swift).
            .modifier(MacTaker(session: session))
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
            // 0.5: a board that is open on another device is taken up here (Handoff).
            .onContinueUserActivity(Handoff.activityType) { HandoffDesk.shared.took($0, model: model) }
            .onAppear {
                Remember.shared.watch(model)
                SpotlightIndex.shared.watch(model)
                OutsideWatch.shared.watch(model)
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
                // 0.5: a short press with ONE picture chosen shows it at full size (Quick Look, MacHabits.swift).
                if let item = session.single, MenuRules.spaceShowsPicture(slid: slid, held: Date().timeIntervalSince(spaceBegan), chosen: session.selection.count,
                                                                         pictureChosen: item.kind == .picture, typing: session.editing != nil) {
                    MacLook.show(item, in: session)
                    return nil
                }
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
