import SwiftUI
import SeedboardCore

/// Small pictures of boards, for the home page, the starter cards and the iPhone's list.
/// A picture is drawn once per version of a board (its identity + the time it was changed),
/// once for day and once for night, and then kept in memory — never drawn again on a redraw.
@MainActor
enum Thumbs {
    /// The size a small picture is drawn at, in points (twice as many pixels). Shown smaller, never bigger.
    static let size = CGSize(width: 240, height: 150)
    /// Width to height of every small picture.
    static let shape: CGFloat = 1.6

    private final class Entry {
        let stamp: Date
        let image: CGImage
        init(stamp: Date, image: CGImage) { self.stamp = stamp; self.image = image }
    }

    /// Memory only. The system empties it by itself when memory runs short; a picture is then drawn again.
    private static let kept: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 160
        cache.totalCostLimit = 48 * 1024 * 1024   // about 80 pictures
        return cache
    }()

    /// How often a picture was really drawn (for checking that redraws cost nothing).
    private(set) static var drawn = 0

    private static func key(_ name: String, night: Bool) -> NSString { "\(name)|\(night ? "night" : "day")" as NSString }

    /// The kept picture of this version, if there is one.
    static func kept(_ name: String, stamp: Date, night: Bool) -> CGImage? {
        guard let entry = kept.object(forKey: key(name, night: night)), entry.stamp == stamp else { return nil }
        return entry.image
    }

    /// The picture of this version: the kept one, or drawn now and kept. An older version's picture is replaced.
    static func picture(of board: Board, name: String, night: Bool) -> CGImage? {
        if let image = kept(name, stamp: board.changed, night: night) { return image }
        guard let image = draw(board, night: night) else { return nil }
        kept.setObject(Entry(stamp: board.changed, image: image), forKey: key(name, night: night), cost: image.bytesPerRow * image.height)
        return image
    }

    /// Draws the whole board, made small, in the middle of the picture, with the board's own painter.
    private static func draw(_ board: Board, night: Bool) -> CGImage? {
        var fitted = board
        Lettering.fit(&fitted, facts: MapFacts(board))
        let facts = MapFacts(fitted)
        let paint = Paint(night: night)
        let size = Thumbs.size
        let box = fitted.bounds
        let view = Canvas { ctx, _ in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paint.canvas))
            guard let box, box.width > 0, box.height > 0 else { return }
            // A little room round the drawing; a board with one small thing on it is not blown up.
            let k = min((size.width - 24) / box.width, (size.height - 20) / box.height, 0.6)
            var sheet = ctx
            sheet.translateBy(x: size.width / 2, y: size.height / 2)
            sheet.scaleBy(x: k, y: k)
            sheet.translateBy(x: -box.midX, y: -box.midY)
            var painter = BoardPainter(board: fitted, facts: facts, paint: paint)
            painter.handles = false
            painter.todoStates = TodoMark.marks(for: fitted)
            painter.ground = paint.canvas
            painter.draw(&sheet)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, night ? .dark : .light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        drawn += 1
        return renderer.cgImage
    }

    // MARK: Starters

    private static var starterBoards: [Starter: Board] = [:]

    /// The starter's own board, made once: what a new board of this kind looks like.
    static func board(of starter: Starter) -> Board {
        if let board = starterBoards[starter] { return board }
        let fixed = Date(timeIntervalSinceReferenceDate: 0)
        // A timeline is drawn round today: its starter is made for today, or its bars (and today, 25 years
        // later) would be too far apart to see. Its picture is still drawn only once.
        var board = starter.board(now: starter == .timeline ? Date() : fixed)
        board.changed = fixed
        starterBoards[starter] = board
        return board
    }
}

/// The small picture of a board, in the board's own colours by day and by night.
@MainActor
struct BoardThumb: View {
    let board: Board
    /// The name the picture is kept under: the board's identity, or the starter's name.
    let name: String

    @Environment(\.colorScheme) private var scheme
    /// The picture shown last, so an older one stays up while the new one is drawn.
    @State private var shown: CGImage?

    init(board: Board) {
        self.board = board
        self.name = board.id.uuidString
    }

    init(starter: Starter) {
        self.board = Thumbs.board(of: starter)
        self.name = "starter." + starter.rawValue
    }

    /// A starter of the shelf: an untouched built-in is drawn once, an own or changed one from its stored board.
    init(starter: ShelfStarter) {
        if let stored = starter.board {
            // 0.11: an own timeline starter is drawn with its days moved to "from today", as a new board from it gets.
            self.board = StarterShelf.shownBoard(stored)
            self.name = "shelf." + starter.id
        } else if let built = starter.builtin {
            self.board = Thumbs.board(of: built)
            self.name = "starter." + built.rawValue
        } else {
            self.board = Board(title: "")
            self.name = "shelf." + starter.id
        }
    }

    private struct Version: Equatable {
        let name: String
        let stamp: Date
        let night: Bool
    }

    var body: some View {
        let night = scheme == .dark
        let image = Thumbs.kept(name, stamp: board.changed, night: night) ?? shown
        ZStack {
            Paint(night: night).canvas
            if let image {
                Image(decorative: image, scale: 2)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .aspectRatio(Thumbs.shape, contentMode: .fit)
        // Drawn after the page is up, one picture at a time, and only when this version has none yet.
        .task(id: Version(name: name, stamp: board.changed, night: night)) {
            if Thumbs.kept(name, stamp: board.changed, night: night) == nil { await Task.yield() }
            shown = Thumbs.picture(of: board, name: name, night: night)
        }
        .accessibilityHidden(true)
    }
}
