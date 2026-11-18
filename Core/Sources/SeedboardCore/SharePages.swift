import Foundation
import CoreGraphics

// Share… (0.5, pick 22): what of a board is shared and in which form, the pages a PDF gets, how a page
// is fitted to the paper, and the words the Share plate says. Nothing here is stored in a board.

/// What of the board is shared.
public enum ShareWhat: String, CaseIterable, Sendable {
    /// The whole board.
    case whole
    /// Only what is chosen (offered when something is).
    case chosen
    /// Each named frame as a page of its own (offered when the board has named frames).
    case frames

    /// The word on its tile.
    public var word: String {
        switch self {
        case .whole: return "Whole board"
        case .chosen: return "What is chosen"
        case .frames: return "Each frame a page"
        }
    }
}

/// The form it is shared in.
public enum ShareForm: String, CaseIterable, Sendable {
    case picture, pdf, words

    /// The word on its tile.
    public var word: String {
        switch self {
        case .picture: return "Picture"
        case .pdf: return "PDF"
        case .words: return "Words"
        }
    }

    /// The ending of the file that is shared.
    public var ending: String {
        switch self {
        case .picture: return "png"
        case .pdf: return "pdf"
        case .words: return "txt"
        }
    }
}

/// One page of what is shared: a small board of its own, and the heading over it (a frame's name; empty
/// for the whole board and for what is chosen).
public struct SharePage: Equatable, Sendable {
    public var heading: String
    public var board: Board

    public init(heading: String = "", board: Board) {
        self.heading = heading
        self.board = board
    }
}

/// How one page lies on the paper.
public struct PageFit: Equatable, Sendable {
    /// The paper lies on its side.
    public var landscape: Bool
    /// The paper as it lies (points).
    public var paper: CGSize
    /// How much smaller than life size the board is drawn (1 = life size; never larger).
    public var scale: Double
    /// Where the board's top left corner goes, from the paper's top left corner.
    public var origin: CGPoint
}

public enum SharePlan {
    /// The white edge round a page.
    public static let edge = 28.0
    /// The room of the small line at the top (the board's name and the date).
    public static let head = 20.0
    /// The room of a frame's name as the page's heading, under that line.
    public static let heading = 24.0
    /// The air round the board on its page (board points).
    public static let air = 12.0

    /// The paper of the region, upright, in points: Letter in the United States, Canada and Mexico, A4 everywhere else.
    public static func paper(region: String?) -> CGSize {
        ["US", "CA", "MX"].contains((region ?? "").uppercased()) ? CGSize(width: 612, height: 792) : CGSize(width: 595, height: 842)
    }

    /// One page fitted: the paper lies on its side when the board is wider than tall (a timeline always);
    /// the board is made smaller until it fits and never larger than life size; it sits at the top, in the middle.
    public static func fit(content: CGSize, paper: CGSize, alwaysLandscape: Bool = false, hasHeading: Bool = false) -> PageFit {
        let landscape = alwaysLandscape || content.width > content.height
        let long = Double(max(paper.width, paper.height)), short = Double(min(paper.width, paper.height))
        let page = landscape ? CGSize(width: long, height: short) : CGSize(width: short, height: long)
        let top = edge + head + (hasHeading ? heading : 0)
        let roomW = Double(page.width) - 2 * edge, roomH = Double(page.height) - top - edge
        let w = Double(content.width), h = Double(content.height)
        guard w > 0, h > 0, roomW > 0, roomH > 0 else {
            return PageFit(landscape: landscape, paper: page, scale: 1, origin: CGPoint(x: edge, y: top))
        }
        let scale = min(1, roomW / w, roomH / h)
        return PageFit(landscape: landscape, paper: page, scale: scale, origin: CGPoint(x: edge + (roomW - w * scale) / 2, y: top))
    }

    /// The small line at the top right of a page: "18 Nov 2026", and "18 Nov 2026 · 2 of 4" when there are several pages.
    public static func dateLine(_ now: Date, page: Int = 1, of count: Int = 1, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = timeZone
        f.dateFormat = "d MMM yyyy"
        let day = f.string(from: now)
        return count > 1 ? "\(day) · \(page) of \(count)" : day
    }

    /// The board's name at the top left of a page: one line, at most 70 letters.
    public static func nameLine(_ title: String) -> String {
        let one = ParagonExport.oneLine(title)
        let name = one.isEmpty ? "Board" : one
        return name.count > 70 ? String(name.prefix(69)) + "…" : name
    }

    /// A name a file can carry on every device: "/", ":" and "\" become "-", at most 80 letters, never empty.
    /// `part`: a frame's name, or "part" for what is chosen — it follows the board's name after a dash.
    public static func fileName(_ title: String, part: String = "", form: ShareForm) -> String {
        func clean(_ words: String) -> String {
            let one = ParagonExport.oneLine(words).components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
            return String(one.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).prefix(80))
        }
        let board = clean(title), piece = clean(part)
        let name = (board.isEmpty ? "Board" : board) + (piece.isEmpty ? "" : " - " + piece)
        return name + "." + form.ending
    }

    /// What the Share plate says under its tiles: what he gets. `pages`: how many frames become pages;
    /// `chosen`: how many things are chosen.
    public static func line(_ what: ShareWhat, _ form: ShareForm, pages: Int = 1, chosen: Int = 1) -> String {
        let things = chosen == 1 ? "the chosen thing" : "the \(chosen) chosen things"
        let first = chosen == 1 ? "The chosen thing" : "The \(chosen) chosen things"
        switch (what, form) {
        case (.whole, .picture): return "One picture of the whole board."
        case (.whole, .pdf): return "The whole board on one page, sharp at any size."
        case (.whole, .words): return "The board's words as a small text file."
        case (.chosen, .picture): return "One picture of \(things)."
        case (.chosen, .pdf): return "\(first) on one page, sharp at any size."
        case (.chosen, .words): return "The words of \(things) as a small text file."
        case (.frames, .picture): return pages == 1 ? "One picture of the named frame." : "\(pages) pictures, one of each named frame."
        case (.frames, .pdf): return pages == 1 ? "One page with the named frame, its name on top." : "\(pages) pages, one for each named frame, its name on top."
        case (.frames, .words): return "The words frame by frame, each under its frame's name, as a small text file."
        }
    }

    /// What stays out when each frame is a page; nil when nothing does.
    public static func leftOutLine(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "1 thing lies outside the named frames and stays out." : "\(count) things lie outside the named frames and stay out."
    }
}

public extension Board {
    /// The frames that have a name, in reading order: row by row from the top, each row from the left.
    /// (Two frames are in one row when the second starts above the middle of the first.)
    /// A timeline and a "Who does what" board have no frames.
    var shareFrames: [Item] {
        guard !placesItself else { return [] }
        var rest = items
            .filter { $0.kind == .frame && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        var out: [Item] = []
        while let first = rest.first {
            let line = first.y + first.h / 2
            let row = rest.filter { $0.y < line }.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
            out += row
            let taken = Set(row.map(\.id))
            rest.removeAll { taken.contains($0.id) }
        }
        return out
    }

    /// The chosen things with what belongs to them: an idea brings everything under it, a frame brings
    /// what lies in it (and the frames wholly inside it).
    private func shareIDs(_ ids: Set<UUID>) -> Set<UUID> {
        var all = ids
        for id in ids {
            guard let frame = item(id), frame.kind == .frame else { continue }
            all.formUnion(things(in: id).map(\.id))
            all.formUnion(items.filter { Board.frame(frame, holds: $0) && $0.kind == .frame }.map(\.id))
        }
        return all
    }

    /// What can be shared of this board now. "What is chosen" only when something that can be shared is
    /// chosen, "Each frame a page" only when the board has named frames; never on a board that places itself.
    func shareChoices(chosen: Set<UUID>) -> [ShareWhat] {
        var all: [ShareWhat] = [.whole]
        guard !placesItself else { return all }
        if !clip(of: shareIDs(chosen)).isEmpty { all.append(.chosen) }
        if !shareFrames.isEmpty { all.append(.frames) }
        return all
    }

    /// The chosen things as a small board of its own (with the arrows between them), under this board's name.
    func sharePart(of ids: Set<UUID>) -> Board {
        var part = clip(of: shareIDs(ids)).asBoard()
        part.title = title
        part.colour = colour
        return part
    }

    /// The pages that are shared. The whole board and what is chosen are one page; each named frame is a
    /// page with the frame's name as its heading, in reading order. Empty pages are left out.
    func sharePages(_ what: ShareWhat, chosen: Set<UUID> = []) -> [SharePage] {
        switch what {
        case .whole:
            return isEmpty ? [] : [SharePage(board: self)]
        case .chosen:
            let part = sharePart(of: chosen)
            return part.isEmpty ? [] : [SharePage(board: part)]
        case .frames:
            return shareFrames.compactMap { frame in
                let part = sharePart(of: [frame.id])
                return part.isEmpty ? nil : SharePage(heading: ParagonExport.oneLine(frame.text), board: part)
            }
        }
    }

    /// How many things lie outside every named frame (a mind map counts once): they are not on any page
    /// when each frame is a page.
    var shareLeftOut: Int {
        let frames = shareFrames
        guard !frames.isEmpty else { return 0 }
        return items.filter { thing in
            thing.kind != .frame && !(thing.kind == .idea && thing.parent != nil) && !isHidden(thing.id)
                && !frames.contains { Board.frame($0, holds: thing) }
        }.count
    }

    /// The words that are shared: the list "Copy the board as text" makes — of the whole board, of what is
    /// chosen (one thing gives just its words), or frame by frame, each under its frame's name.
    func shareWords(_ what: ShareWhat, chosen: Set<UUID> = []) -> String {
        switch what {
        case .whole:
            return outlineText
        case .chosen:
            return clip(of: shareIDs(chosen)).text
        case .frames:
            return sharePages(.frames).map { page in
                let rule = String(repeating: "-", count: min(max(page.heading.count, 3), 40))
                // The page's own frame is its heading already: it is not said a second time inside (since 0.5 a
                // named frame is a heading in "Copy the board as text").
                var inner = page.board
                inner.items.removeAll { $0.kind == .frame && $0.lanes == nil && ParagonExport.oneLine($0.text) == page.heading }
                let words = inner.outlineText
                return page.heading + "\n" + rule + (words.isEmpty ? "" : "\n" + words)
            }.joined(separator: "\n\n\n")
        }
    }
}
