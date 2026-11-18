import SwiftUI
import Combine
import ImageIO
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 24: the app's half of Share › Seedboard.
//  - It tells the share page which boards there are (a small list, two seconds after the boards changed).
//  - It empties the waiting list: when the boards are read at the start, and every time Seedboard comes to the
//    front (iPhone, iPad and — where switching apps is not "leaving the scene" — the Mac). Words become a sticky
//    note (a list a mind map), a link a sticky note with title and address, a picture a picture thing; each lies
//    in a free column to the right of everything on its board.
//  - A line is taken off the list only after its board was saved on the device.
// With `-sampleData` nothing outside the app is touched. Debug builds: `-arrivalsFolder <folder>` uses that
// folder as the waiting place (also with `-sampleData`), `-arrivalsShow` brings what came into sight at once,
// `-sharePage` / `-sharePageNoPictures` show the share page itself with made-up content.

@MainActor
final class ArrivalDesk {
    static let shared = ArrivalDesk()

    private weak var model: AppModel?
    private var boxes: [ArrivalBox] = []
    private var watch: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var busy = false
    private var again = false
    private var retry: DispatchWorkItem?

    /// Called once, when the boards have been read.
    func start(_ model: AppModel) {
        guard self.model == nil else { return }
        self.model = model
        #if DEBUG
        ShareInTrial.showIfAsked(model)
        #endif
        Task {
            let boxes = await Task.detached(priority: .utility) { ArrivalDesk.find() }.value
            guard !boxes.isEmpty else { return }
            self.boxes = boxes
            listen(model)
            take()
        }
    }

    /// The waiting places this app can reach. None with made-up boards.
    nonisolated private static func find() -> [ArrivalBox] {
        #if DEBUG
        if let path = LaunchOptions.value(for: "-arrivalsFolder") {
            let folder = URL(fileURLWithPath: path, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return [ArrivalBox(folder: folder)]
        }
        #endif
        if LaunchOptions.sampleData { return [] }
        return ArrivalBox.homes()
    }

    private func listen(_ model: AppModel) {
        // The share page's list of boards follows the boards, once they rest.
        watch = model.$boards
            .combineLatest(model.$loaded)
            .filter { $0.1 }
            .map { ShareBoards.list(of: $0.0) }
            .removeDuplicates()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] list in
                guard let boxes = self?.boxes else { return }
                Task.detached(priority: .utility) { for box in boxes { box.keep(boards: list) } }
            }
        // Seedboard comes to the front. On the Mac the scene does not notice a switch between apps; this does.
        #if os(macOS)
        let front = NSApplication.didBecomeActiveNotification
        #else
        let front = UIApplication.didBecomeActiveNotification
        #endif
        observers.append(NotificationCenter.default.addObserver(forName: front, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.take() }
        })
    }

    // MARK: Emptying the list

    /// Lays what waits on its boards. One round at a time; a call during a round starts another after it.
    func take() {
        guard let model, model.loaded, !boxes.isEmpty else { return }
        guard !busy else {
            again = true
            return
        }
        busy = true
        retry?.cancel()
        Task {
            let held = await round(model)
            busy = false
            if again {
                again = false
                take()
            } else if held {
                // Something waits for the board he is typing in: looked at again in a moment.
                let work = DispatchWorkItem { ArrivalDesk.shared.take() }
                retry = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
            }
        }
    }

    private struct Found: Sendable {
        var arrivals: [Arrival] = []
        /// Every picture that was kept for the boards, with its size in pixels.
        var pixels: [UUID: CGSize] = [:]
        /// Pictures that could be read but not kept with the boards (e.g. the device is full): they wait, never lost.
        var notTaken: Set<UUID> = []
    }

    /// Reads every list, and keeps the waiting pictures where the boards' pictures live. Off the main thread.
    nonisolated private static func read(_ boxes: [ArrivalBox]) -> Found {
        var found = Found()
        var seen: Set<UUID> = []
        for box in boxes {
            box.sweep()
            for arrival in box.waiting() where seen.insert(arrival.id).inserted {
                found.arrivals.append(arrival)
                guard arrival.kind == .picture, let name = arrival.picture, let bytes = box.pictureBytes(name),
                      let size = pixelSize(of: bytes) else { continue }
                guard PictureStore.shared.adopt(bytes, named: name) else { found.notTaken.insert(arrival.id); continue }
                found.pixels[arrival.id] = size
            }
        }
        return found
    }

    /// A picture's size in pixels, read without opening the picture.
    nonisolated private static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    /// One round. True when something was left waiting because the owner is typing in its board.
    private func round(_ model: AppModel) async -> Bool {
        let boxes = self.boxes
        let found = await Task.detached(priority: .userInitiated) { ArrivalDesk.read(boxes) }.value
        guard !found.arrivals.isEmpty else { return false }

        var held = false
        var things = 0
        var handled: [(board: UUID, arrivals: [Arrival])] = []
        var landed: [(board: UUID, first: UUID)] = []
        for group in Arrivals.groups(found.arrivals, boards: model.boards) {
            var laid: [UUID] = []
            if model.openID == group.board, let session = model.session {
                // The board that is open: one step that can be undone. In the middle of typing or dragging
                // nothing is laid under his hands; the lines wait.
                // A board that waits for its newest version (Handoff) cannot take anything yet: the lines wait too.
                if session.busy || session.readOnly {
                    held = true
                    continue
                }
                session.change { laid = $0.land(group.arrivals, pixels: found.pixels) }
                if !laid.isEmpty {
                    session.selectedLink = nil
                    session.selection = Set(laid)
                }
            } else {
                var board = model.boards.first { $0.id == group.board }
                    ?? fresh(Board(id: group.board, title: Arrivals.boardName(for: group.arrivals)), among: model.boards)
                laid = board.land(group.arrivals, pixels: found.pixels)
                if !laid.isEmpty {
                    board.touch()
                    model.write(board)
                }
            }
            things += laid.count
            // A picture that could be read but not kept waits for the next round (its line stays).
            let waiting = group.arrivals.filter { found.notTaken.contains($0.id) }
            if !waiting.isEmpty { held = true }
            handled.append((group.board, group.arrivals.filter { !found.notTaken.contains($0.id) }))
            if let first = laid.first { landed.append((group.board, first)) }
        }

        // The boards are written on the device BEFORE a line leaves the list. A board that could not be written
        // keeps its lines; read again, they lay nothing twice (each thing carries its line's identity).
        model.saveNow()
        model.store.flush()
        try? await Task.sleep(nanoseconds: 60_000_000)
        let gone = handled.filter { !model.store.notOnDevice($0.board) }.flatMap { group -> [Arrival] in
            let stored = model.openID == group.board ? model.session?.board : model.boards.first { $0.id == group.board }
            // Only what really is on the board leaves the list; an unreadable picture is said as lost and goes too.
            return group.arrivals.filter { stored?.item($0.id) != nil || ($0.kind == .picture && found.pixels[$0.id] == nil) }
        }
        if !gone.isEmpty {
            await Task.detached(priority: .utility) { for box in boxes { box.remove(gone) } }.value
        }

        let lost = handled.flatMap(\.arrivals).filter { $0.kind == .picture && found.pixels[$0.id] == nil }.count
        var line: [String] = []
        if things > 0 { line.append(Arrivals.cameLine(things)) }
        if lost > 0 { line.append(Arrivals.lostLine(lost)) }
        guard !line.isEmpty else { return held }
        // One pill when everything went to one board: "Show" brings it into sight on the open board, "Open" opens the other.
        var pill: FlashAction?
        if landed.count == 1, let place = landed.first {
            if model.openID == place.board {
                pill = FlashAction(label: "Show") { [weak model] in model?.session?.reveal(place.first) }
            } else {
                pill = FlashAction(label: "Open") { [weak model] in model?.open(place.board) }
            }
        }
        model.say(line.joined(separator: " "), tone: lost > 0 ? .problem : .good, seconds: pill == nil ? 4 : 6, action: pill)
        #if DEBUG
        // For pictures: `-arrivalsShow` presses the pill at once, so the things that came are in sight.
        if LaunchOptions.arguments.contains("-arrivalsShow") { pill?.run() }
        #endif
        return held
    }

    /// A board made for a share joins the list like any new board: the next colour, and a name no other board has.
    private func fresh(_ made: Board, among boards: [Board]) -> Board {
        var board = made
        board.colour = Palette.boards[boards.count % Palette.boards.count]
        let names = Set(boards.map { $0.title.lowercased() })
        let base = board.title
        var n = 2
        while names.contains(board.title.lowercased()) {
            board.title = "\(base) \(n)"
            n += 1
        }
        return board
    }
}

#if DEBUG
/// For pictures and the screen test: the share page itself, with made-up content, in a window of its own
/// (`-sharePage`; `-sharePageNoPictures` = the page when pictures cannot be taken). Nothing is written anywhere.
@MainActor
enum ShareInTrial {
    #if os(macOS)
    private static var window: NSWindow?
    #endif

    static func showIfAsked(_ app: AppModel) {
        let noPictures = LaunchOptions.arguments.contains("-sharePageNoPictures")
        guard noPictures || LaunchOptions.arguments.contains("-sharePage") else { return }
        let model = ShareInModel()
        model.loading = false
        model.title = "Timber prices this spring"
        model.address = "https://example.com/timber-prices"
        model.boards = ShareBoards.list(of: app.boards)
        if noPictures {
            model.picturesLeftOut = 2
        } else {
            model.pictures = [ShareInPicture(id: UUID(), thumb: swatch(0.62, 0.45, 0.28)), ShareInPicture(id: UUID(), thumb: swatch(0.36, 0.55, 0.42))]
        }
        #if os(macOS)
        let page = ShareInPage(model: model).frame(width: 420, height: 480)
        let made = NSWindow(contentViewController: NSHostingController(rootView: page))
        made.title = "Share"
        made.styleMask = [.titled, .closable]
        made.isReleasedWhenClosed = false
        made.appearance = LaunchOptions.arguments.contains("-night") ? NSAppearance(named: .darkAqua) : nil
        model.onCancel = { made.close() }
        model.onSend = { _ in made.close() }
        window = made
        made.center()
        made.makeKeyAndOrderFront(nil)
        #else
        let host = UIHostingController(rootView: ShareInPage(model: model))
        if LaunchOptions.arguments.contains("-night") { host.overrideUserInterfaceStyle = .dark }
        model.onCancel = { [weak host] in host?.dismiss(animated: false) }
        model.onSend = { [weak host] _ in host?.dismiss(animated: false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController?.present(host, animated: false)
        }
        #endif
    }

    /// A small flat picture standing in for a shared photo.
    private static func swatch(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: 88, height: 88, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 88, height: 88))
        return ctx.makeImage()
    }
}
#endif
