import SwiftUI
import Combine
import UniformTypeIdentifiers
import QuickLook
import SeedboardCore
#if os(macOS)
import AppKit
import PDFKit
#else
import UIKit
#endif

// 0.5, pick 29: the Mac's own habits. The Help menu opens the guide in a small window of its own; the Dock
// icon has a menu; a photo, a scan or a sketch comes straight from the iPhone (Continuity Camera); words marked
// in another app become a board (Services); and Space on ONE chosen picture shows it at full size (Quick Look).
// The board's name in the top bar (a click renames it, and it has a small menu) is in MacTitle.swift.
// The rules are in SeedboardCore (`MacHabits`, `MenuRules.spaceShowsPicture`).

#if os(macOS)

/// What the Mac's menus, the Dock and the windows tell each other.
@MainActor
final class MacDesk: ObservableObject {
    static let shared = MacDesk()
    static let guideID = "guide"

    enum Page: String { case how, news }

    /// The page the guide window shows.
    @Published var page = Page.how
    /// Quick Look: the picture that is shown (nil: closed), and all the board's pictures for the arrow keys.
    @Published var look: URL?
    @Published var lookAll: [URL] = []

    /// The window with the boards (one at a time).
    weak var mainWindow: NSWindow?
    /// Opens the boards window again after it was closed, and the guide window.
    var openMain: (() -> Void)?
    var openGuide: (() -> Void)?

    /// "Import from iPhone or iPad" in the menu of empty board: the spot that was pressed (board points).
    var cameraAsk: (spot: CGPoint, board: UUID, time: Date)?

    /// Brings the boards window to the front; opens it again when it was closed.
    func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow, window.isVisible || window.isMiniaturized {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openMain?()
        }
    }

    func showGuide(_ page: Page) {
        self.page = page
        openGuide?()
    }
}

// MARK: Help ▸ How Seedboard Works, What's New

/// The guide in a small window of its own, so it can stay open beside the board.
struct GuideScene: Scene {
    var body: some Scene {
        Window("How Seedboard Works", id: MacDesk.guideID) {
            GuideWindow()
        }
        .defaultSize(width: 460, height: 640)
        .defaultPosition(.topTrailing)
        .windowResizability(.contentMinSize)
        // Its line is in the Help menu (with ⌘?), not a second time in the Window menu.
        .commandsRemoved()
    }
}

struct GuideWindow: View {
    @ObservedObject private var desk = MacDesk.shared
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                tab("How it works", .how, "guide.tab.how")
                tab("What's new", .news, "guide.tab.news")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            if desk.page == .how { GuidePage() } else { WhatsNewPage() }
        }
        .frame(minWidth: 360, minHeight: 320)
        // Escape closes the window, as it closes every page of the app.
        .background {
            Button("Close") { dismissWindow(id: MacDesk.guideID) }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .tint(Theme.text(.boards))
        .preferredColorScheme(LaunchOptions.arguments.contains("-night") ? .dark : nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide.window")
    }

    /// The page that shows is full colour; the other is a soft plate in the same green.
    private func tab(_ words: String, _ page: MacDesk.Page, _ id: String) -> some View {
        let on = desk.page == page
        return Button { desk.page = page } label: {
            Text(words)
                .font(.body.weight(.semibold))
                .foregroundStyle(on ? Color.white : Part.boards.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(on ? Part.boards.fill : Part.boards.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The Mac-only menu lines: Help, and File ▸ Import from iPhone or iPad (the system's own line and submenu:
/// Take Photo, Scan Documents, Add Sketch — `MacDelegate` takes what comes back).
struct MacCommands: Commands {
    var body: some Commands {
        ImportFromDevicesCommands()
        CommandGroup(replacing: .help) {
            Button("How Seedboard Works") { MacDesk.shared.showGuide(.how) }
                .keyboardShortcut("?", modifiers: .command)
            Button("What's New") { MacDesk.shared.showGuide(.news) }
        }
    }
}

// MARK: The window

/// On the whole window (the Mac only; nothing on iPhone and iPad): knows the boards window, shows a picture
/// at full size, and answers the launch words `-guide`, `-whatsNew` and `-lookPicture`.
struct MacRoot: ViewModifier {
    @ObservedObject private var desk = MacDesk.shared
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .background(WindowCatcher())
            .quickLookPreview($desk.look, in: desk.lookAll)
            .onChange(of: desk.look) { _, new in if new == nil { MacLook.closed() } }
            .onAppear {
                desk.openMain = { openWindow(id: "main") }
                desk.openGuide = { openWindow(id: MacDesk.guideID) }
                MacLaunch.run()
            }
    }
}

/// Tells `MacDesk` which window holds the boards.
private struct WindowCatcher: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Catcher() }
    func updateNSView(_ view: NSView, context: Context) {}

    final class Catcher: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            MainActor.assumeIsolated { MacDesk.shared.mainWindow = window }
        }
    }
}

/// For pictures: `-guide` opens the guide window on "How it works", `-whatsNew` on "What's new";
/// `-lookPicture` shows the open board's first picture at full size.
@MainActor
enum MacLaunch {
    private static var done = false

    static func run() {
        guard !done else { return }
        done = true
        let words = LaunchOptions.arguments
        if words.contains("-guide") || words.contains("-whatsNew") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                MacDesk.shared.showGuide(words.contains("-whatsNew") ? .news : .how)
            }
        }
        #if DEBUG
        if words.contains("-macCheck") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { MacDesk.shared.showMain() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { MacCheck.run() }
        }
        #endif
        #if DEBUG
        if words.contains("-titleCheck") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { MacDesk.shared.showMain() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { MacCheck.title() }
        }
        #endif
        if words.contains("-lookPicture") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard let session = AppModel.shared.session,
                      let first = MacHabits.lookPictures(of: session.board).first, let item = session.board.item(first.id) else { return }
                session.select(item.id)
                MacLook.show(item, in: session)
            }
        }
    }
}

// MARK: Space on a chosen picture: Quick Look

@MainActor
enum MacLook {
    private static var folder: URL { FileManager.default.temporaryDirectory.appendingPathComponent("Look", isDirectory: true) }

    /// Shows the picture at full size, as it is stored (the whole picture, also when it is cropped on the board).
    /// The arrow keys step through the board's other pictures in reading order; Space or Escape closes it.
    static func show(_ item: Item, in session: BoardSession) {
        let all = MacHabits.lookPictures(of: session.board)
        guard all.contains(where: { $0.id == item.id }) else {
            AppModel.shared.say("This picture is not on this Mac yet.", tone: .problem)
            return
        }
        // Copies under plain names ("Picture 2", or the caption): the window that shows a picture is called by its file.
        let place = folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let old = folder
        Task {
            let made: [(id: UUID, file: URL)] = await Task.detached(priority: .userInitiated) {
                try? FileManager.default.removeItem(at: old)
                try? FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
                var out: [(id: UUID, file: URL)] = []
                for picture in all {
                    guard let bytes = PictureStore.shared.fileBytes(picture.stored) else { continue }
                    let kind = (picture.stored as NSString).pathExtension
                    let file = place.appendingPathComponent(picture.name).appendingPathExtension(kind.isEmpty ? "jpg" : kind)
                    if (try? bytes.write(to: file, options: .atomic)) != nil { out.append((picture.id, file)) }
                }
                return out
            }.value
            guard let mine = made.first(where: { $0.id == item.id }) else {
                AppModel.shared.say("This picture is not on this Mac yet.", tone: .problem)
                return
            }
            MacDesk.shared.lookAll = made.map(\.file)
            MacDesk.shared.look = mine.file
        }
    }

    /// The picture was closed: the copies go, and the board has the keys again.
    static func closed() {
        MacDesk.shared.lookAll = []
        try? FileManager.default.removeItem(at: folder)
        AppModel.shared.session?.takeKeys()
    }
}

// MARK: A photo, a scan or a sketch from the iPhone or iPad (Continuity Camera)

@MainActor
enum MacCamera {
    /// What the iPhone may send back: a picture, or the pages of a scan. Each kind is named by itself, because the
    /// system asks for one exact kind at a time.
    static let wanted: [UTType] = [.jpeg, .png, .tiff, .heic, .heif, .image, .pdf]

    /// Each page of a scan as a picture, its long side 2048 pixels (the size pictures are kept at).
    private static func pages(of scan: Data) -> [Data] {
        guard let pdf = PDFDocument(data: scan) else { return [] }
        var out: [Data] = []
        for n in 0..<min(pdf.pageCount, 12) {
            guard let page = pdf.page(at: n) else { continue }
            let box = page.bounds(for: .mediaBox)
            guard box.width > 0, box.height > 0 else { continue }
            let k = CGFloat(PictureStore.longestSide) / max(box.width, box.height)
            let w = Int((box.width * k).rounded()), h = Int((box.height * k).rounded())
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -box.minX, y: -box.minY)
            page.draw(with: .mediaBox, to: ctx)
            guard let image = ctx.makeImage(),
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { continue }
            out.append(data)
        }
        return out
    }

    /// What came back from the iPhone is laid on the board: at the spot of the right-click when it was asked for
    /// there, else at a free place near the middle of the view. False: there was no picture in it.
    static func take(_ providers: [NSItemProvider], into session: BoardSession) -> Bool {
        let image = UTType.image.identifier, scan = UTType.pdf.identifier
        let wanted = providers.filter { $0.hasItemConformingToTypeIdentifier(image) || $0.hasItemConformingToTypeIdentifier(scan) }
        guard !wanted.isEmpty, !session.readOnly, !session.board.placesItself else { return false }
        let desk = MacDesk.shared
        let ask = desk.cameraAsk
        desk.cameraAsk = nil
        let spot = MacHabits.cameraSpot(asked: ask?.spot, on: ask?.board, at: ask?.time ?? .distantPast, open: session.board.id)
        Task { @MainActor in
            var all: [Data] = []
            for provider in wanted {
                if provider.hasItemConformingToTypeIdentifier(image) {
                    if let data = await bytes(of: provider, as: image) { all.append(data) }
                } else if let data = await bytes(of: provider, as: scan) {
                    all += pages(of: data)
                }
            }
            guard !all.isEmpty else {
                AppModel.shared.say("That could not be read as a picture.", tone: .problem)
                return
            }
            session.lay(pictures: all, at: spot)
            desk.showMain()
            session.takeKeys()
        }
        return true
    }

    private static func bytes(of provider: NSItemProvider, as type: String) async -> Data? {
        await withCheckedContinuation { (done: CheckedContinuation<Data?, Never>) in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in done.resume(returning: data) }
        }
    }

    /// Shows the right-click menu. In the menu of empty board, "Import from iPhone or iPad" follows "Picture…"
    /// (the system's own line, with Take Photo, Scan Documents and Add Sketch).
    static func popUp(_ menu: NSMenu, at p: CGPoint, in view: NSView, session: BoardSession) {
        let desk = MacDesk.shared
        addLine(to: menu, at: p, session: session)
        menu.popUp(positioning: nil, at: p, in: view)
        // The two minutes for taking the photo begin when the menu closes.
        if let ask = desk.cameraAsk { desk.cameraAsk = (ask.spot, ask.board, Date()) }
    }

    /// The lines the system put under File ▸ Import from iPhone or iPad just now (each device with Take Photo,
    /// Scan Documents and Add Sketch), as copies.
    private static func systemLines() -> [NSMenuItem] {
        func find(_ menu: NSMenu?) -> (item: NSMenuItem, menu: NSMenu)? {
            for item in menu?.items ?? [] {
                if item.identifier == NSMenuItem.importFromDeviceIdentifier, let menu { return (item, menu) }
                if let found = find(item.submenu) { return found }
            }
            return nil
        }
        guard let found = find(NSApp.mainMenu) else { return [] }
        found.menu.update()
        found.item.submenu?.update()
        var lines = (found.item.submenu?.items ?? []).compactMap { $0.copy() as? NSMenuItem }
        while lines.last?.isSeparatorItem == true { lines.removeLast() }
        return lines
    }

    static func addLine(to menu: NSMenu, at p: CGPoint, session: BoardSession) {
        let desk = MacDesk.shared
        desk.cameraAsk = nil
        if let at = menu.items.firstIndex(where: { $0.identifier?.rawValue == "menu.picture" }), !session.readOnly, !session.board.placesItself {
            // The system fills this line's submenu only in the menu bar (File ▸ Import from iPhone or iPad):
            // the same lines, with the system's own steps behind them, are shown here.
            let line = NSMenuItem(title: MacDelegate.cameraLine, action: nil, keyEquivalent: "")
            line.setAccessibilityIdentifier("menu.camera")
            let inner = NSMenu(title: line.title)
            for item in systemLines() { inner.addItem(item) }
            line.submenu = inner
            // No iPhone or iPad near: the line is there, but pale.
            line.isEnabled = !inner.items.isEmpty
            menu.insertItem(line, at: at + 1)
            desk.cameraAsk = (session.toBoard(p), session.board.id, Date())
        }
    }
}

/// On the drawing surface (`BoardKeys`): this board takes what "Import from iPhone or iPad" brings — the line in
/// the File menu and the one in the menu of empty board. Off on a board that cannot be changed and on a timeline
/// or a "Who does what" board (they hold no pictures).
struct MacTaker: ViewModifier {
    @ObservedObject var session: BoardSession

    func body(content: Content) -> some View {
        content.importsItemProviders(session.readOnly || session.board.placesItself ? [] : MacCamera.wanted) { providers in
            MacCamera.take(providers, into: session)
        }
    }
}

// MARK: The Dock menu and Services

/// The app's delegate on the Mac: the Dock icon's menu, and the Service.
@MainActor
final class MacDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Services ▸ New Seedboard Board from Selection (the line itself is in the Info.plist: NSServices).
        NSApp.servicesProvider = self
        // The system names File ▸ Import from iPhone or iPad "<<Import From Device - unlocalized>>" in this app:
        // the line gets its plain name whenever the menu bar is opened (and once now, for the Help menu's search).
        NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MacDelegate.nameCameraLine() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { MacDelegate.nameCameraLine() }
    }

    /// The words of File ▸ Import from iPhone or iPad (also on the line in the menu of empty board).
    static let cameraLine = "Import from iPhone or iPad"

    static func nameCameraLine() {
        func walk(_ menu: NSMenu?) {
            for item in menu?.items ?? [] {
                if item.identifier == NSMenuItem.importFromDeviceIdentifier, item.title != cameraLine { item.title = cameraLine }
                if let inner = item.submenu, inner !== NSApp.servicesMenu { walk(inner) }
            }
        }
        walk(NSApp.mainMenu)
    }

    // The Dock icon's menu: New Board, the pinned boards, the five changed last.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(line("New Board", #selector(dockNew(_:)), "dock.new"))
        let model = AppModel.shared
        guard model.loaded else { return menu }
        let lists = MacHabits.dockBoards(model.boards)
        // 0.11: the last five boards opened, as in File ▸ Open Recent.
        let listed = Set((lists.pinned + lists.recent).map(\.id))
        let opened = RecentDesk.boards().filter { !listed.contains($0.id) }
        for (at, group) in [lists.pinned, lists.recent, opened].enumerated() where !group.isEmpty {
            menu.addItem(.separator())
            if at == 2 {
                let head = NSMenuItem(title: "Opened Recently", action: nil, keyEquivalent: "")
                head.isEnabled = false
                menu.addItem(head)
            }
            for board in group {
                let item = line(board.title, #selector(dockOpen(_:)), "dock.board.\(board.title)")
                item.representedObject = board.id.uuidString
                menu.addItem(item)
            }
        }
        return menu
    }

    private func line(_ title: String, _ action: Selector, _ id: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.identifier = NSUserInterfaceItemIdentifier(id)
        return item
    }

    /// Like File ▸ New Board: the starter choice.
    @objc func dockNew(_ sender: Any?) {
        let desk = MacDesk.shared
        let wasThere = desk.mainWindow?.isVisible == true
        desk.showMain()
        // A window that had to be opened first needs a moment before a page can come down from it.
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasThere ? 0 : 0.5)) {
            if AppModel.shared.loaded { MenuDesk.shared.choosingStarter = true }
        }
    }

    /// Like a link to the board: a board that was removed meanwhile is said so, with "Bring back".
    @objc func dockOpen(_ sender: NSMenuItem) {
        guard let word = sender.representedObject as? String, let url = URL(string: "seedboard://board/\(word)") else { return }
        MacDesk.shared.showMain()
        AppModel.shared.open(url: url)
    }

    /// Services ▸ New Seedboard Board from Selection: the words marked in another app become a board
    /// (a list a mind map, anything else one sticky note) and the board opens.
    @objc func newBoardFromSelection(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let board = MacHabits.serviceBoard(from: pboard.string(forType: .string)) else {
            error.pointee = "There were no words to make a board from."
            return
        }
        Task { @MainActor in
            let model = AppModel.shared
            await model.whenLoaded()
            MacDesk.shared.showMain()
            model.add(board)
        }
    }
}

#if DEBUG
/// For trying the Mac's habits without a press: `-macCheck` prints what the menus, the Dock menu, the Service and
/// the taker of a photo answer (with `-board <word>` and `-sampleData`).
@MainActor
enum MacCheck {
    /// Straight to the error stream, so the lines are there even when the app is stopped right after.
    private static func out(_ line: String) { FileHandle.standardError.write(Data((line + "\n").utf8)) }

    /// `-titleCheck`: a real click on the board's name (sent to this app only; the pointer does not move), then
    /// prints whether "Name of the board" came down; Escape closes it; then a right-click prints the name's menu.
    static func title() {
        guard let window = MacDesk.shared.mainWindow else { out("TITLECHECK no window"); return }
        guard let top = window.contentView?.superview, let name = TitleClicks.Finder.title(in: top) else { out("TITLECHECK the name was not found"); return }
        let box = name.convert(name.bounds, to: nil)
        out("TITLECHECK window \(window.windowNumber) · name at \(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height)) · catchers \(name.gestureRecognizers.count)")
        // A click as the window gets it from the hand (a click made by the system's event tap does not reach an
        // app without the Accessibility switch).
        func click(_ down: NSEvent.EventType, _ up: NSEvent.EventType) {
            for kind in [down, up] {
                if let event = NSEvent.mouseEvent(with: kind, location: CGPoint(x: box.midX, y: box.midY), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                  windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                    NSApp.postEvent(event, atStart: false)
                }
            }
        }
        NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil) { note in
            let titles = ((note.object as? NSMenu)?.items ?? []).map { $0.title + ($0.isEnabled ? "" : " (off)") }
            out("TITLECHECK a menu opened: \(titles)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { (note.object as? NSMenu)?.cancelTracking() }
        }
        _ = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown]) { event in
            out("TITLECHECK event \(event.type.rawValue) in window \(event.window?.windowNumber ?? -1) at \(event.locationInWindow) · hit \(String(describing: event.window?.contentView?.superview?.hitTest(event.locationInWindow).map { type(of: $0) }))")
            return event
        }
        click(.leftMouseDown, .leftMouseUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let sheet = window.attachedSheet
            let texts = sheet.map { all($0.contentView).compactMap { ($0 as? NSTextField)?.stringValue } } ?? []
            out("TITLECHECK after the click: a question came down \(sheet != nil) · \(texts)")
            sheet.map { window.endSheet($0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { click(.rightMouseDown, .rightMouseUp) }
        }
    }

    private static func all(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { all($0) }
    }

    static func run() {
        func titles(_ menu: NSMenu?) -> String { (menu?.items ?? []).map { $0.isSeparatorItem ? "—" : $0.title + ($0.isEnabled ? "" : " (off)") }.joined(separator: " | ") }
        let bar = NSApp.mainMenu
        for name in ["File", "Help", "Window"] {
            let menu = bar?.items.first { $0.title == name }?.submenu
            menu?.update()
            out("MACCHECK \(name): \(titles(menu))")
            if let camera = menu?.items.first(where: { $0.identifier == NSMenuItem.importFromDeviceIdentifier }) {
                camera.submenu?.update()
                out("MACCHECK \(name) camera: enabled \(camera.isEnabled) · \(titles(camera.submenu))")
                out("MACCHECK \(name) camera target \(String(describing: camera.target)) action \(String(describing: camera.action)) · submenu delegate \(String(describing: camera.submenu?.delegate))")
                for item in camera.submenu?.items.prefix(3) ?? [] {
                    out("MACCHECK   “\(item.title)” target \(String(describing: item.target)) action \(String(describing: item.action)) object \(String(describing: item.representedObject))")
                }
                var hop: NSResponder? = NSApp.keyWindow?.firstResponder
                var chain: [String] = []
                while let now = hop, chain.count < 30 { chain.append(String(describing: type(of: now))); hop = now.nextResponder }
                out("MACCHECK chain: \(chain.joined(separator: " → "))")
            }
        }
        out("MACCHECK key window is main: \(MacDesk.shared.mainWindow?.isKeyWindow == true) · first responder \(String(describing: NSApp.keyWindow?.firstResponder.map { type(of: $0) }))")
        let first = NSApp.keyWindow?.firstResponder
        out("MACCHECK first responder takes a picture: \(String(describing: first?.validRequestor(forSendType: nil, returnType: .tiff).map { type(of: $0) })) · png \(String(describing: first?.validRequestor(forSendType: nil, returnType: .png).map { type(of: $0) })) · window: \(String(describing: NSApp.keyWindow?.validRequestor(forSendType: nil, returnType: .tiff).map { type(of: $0) }))")
        for kind in ["public.jpeg", "public.png", "public.tiff", "public.heic", "com.adobe.pdf", "public.image", "public.file-url", "NSFilenamesPboardType", "public.utf8-plain-text"] {
            let back = NSPasteboard.PasteboardType(kind)
            out("MACCHECK   \(kind): first \(String(describing: first?.validRequestor(forSendType: nil, returnType: back))) · empty send \(String(describing: first?.validRequestor(forSendType: NSPasteboard.PasteboardType(""), returnType: back))) · app \(String(describing: NSApp.validRequestor(forSendType: nil, returnType: back)))")
        }
        out("MACCHECK delegate is a responder: \(NSApp.delegate is NSResponder) · its next \(String(describing: (NSApp.delegate as? NSResponder)?.nextResponder)) · app's next \(String(describing: NSApp.nextResponder))")
        let taker = first?.validRequestor(forSendType: nil, returnType: .tiff) ?? NSApp.validRequestor(forSendType: nil, returnType: .tiff)
        out("MACCHECK taker of a picture: \(String(describing: taker.map { type(of: $0) })) · of words: \(String(describing: NSApp.validRequestor(forSendType: nil, returnType: .string).map { type(of: $0) }))")
        out("MACCHECK dock: \(titles(NSApp.delegate?.applicationDockMenu?(NSApp)))")
        guard let session = AppModel.shared.session else { out("MACCHECK no board open"); return }
        // The real thing for half a second: the menu of empty board is shown and closed again.
        if let view = PointerCatcher.PointerView.current {
            let shown = MacMenu.make(BarActions(session: session, prefix: "menu.", dots: nil, night: false).emptyMenu(at: .zero))
            let look = Timer(timeInterval: 0.6, repeats: false) { _ in
                MainActor.assumeIsolated {
                    let line = shown.items.first { $0.accessibilityIdentifier() == "menu.camera" }
                    out("MACCHECK shown board menu: \(titles(shown)) · camera: enabled \(line?.isEnabled == true) · \(titles(line?.submenu))")
                    for item in line?.submenu?.items.prefix(2) ?? [] {
                        out("MACCHECK   “\(item.title)” action \(String(describing: item.action)) object \(String(describing: item.representedObject).prefix(40)) target is the system's: \(item.target != nil)")
                    }
                    shown.cancelTracking()
                }
            }
            RunLoop.main.add(look, forMode: .common)
            MacCamera.popUp(shown, at: CGPoint(x: 200, y: 200), in: view, session: session)
        }
        // A picture handed over the way the iPhone hands it over.
        let before = session.board.items.filter { $0.kind == .picture }.count
        let board = NSPasteboard.withUniqueName()
        let image = NSImage(size: NSSize(width: 300, height: 200), flipped: false) { rect in
            NSColor.systemTeal.setFill()
            rect.fill()
            return true
        }
        board.clearContents()
        board.setData(image.tiffRepresentation, forType: .tiff)
        let read = #selector(NSServicesMenuRequestor.readSelection(from:))
        let took = (taker as? NSObject)?.responds(to: read) == true && (taker as? NSObject)?.perform(read, with: board) != nil
        // Words handed over the way Services hands them over.
        let words = NSPasteboard.withUniqueName()
        words.clearContents()
        words.setString("Winter cabin\n  Roof\n  Paint\n  Jetty", forType: .string)
        var problem: NSString = ""
        let boards = AppModel.shared.boards.count
        withUnsafeMutablePointer(to: &problem) { (NSApp.servicesProvider as? MacDelegate)?.newBoardFromSelection(words, userData: "", error: AutoreleasingUnsafeMutablePointer($0)) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            out("MACCHECK photo taken: \(took) · pictures \(before) → \(session.board.items.filter { $0.kind == .picture }.count) · spot kept \(MacDesk.shared.cameraAsk == nil ? "used" : "still waiting")")
            out("MACCHECK service: boards \(boards) → \(AppModel.shared.boards.count) · open now “\(AppModel.shared.session?.board.title ?? "")” · problem “\(problem)”")
        }
    }
}
#endif

#else

/// iPhone and iPad: nothing (the Mac's own habits are for the Mac).
struct MacRoot: ViewModifier {
    func body(content: Content) -> some View { content }
}

#endif
