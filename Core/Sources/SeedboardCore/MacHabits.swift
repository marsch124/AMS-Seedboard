import Foundation
import CoreGraphics

// 0.5, pick 29: the Mac's own habits — the Dock menu, Space on a picture
// (Quick Look), a photo from the iPhone, and the Service "New Seedboard Board from Selection".
// Only the rules are here; the screens are in the app's MacHabits files.

public extension MenuRules {
    /// Space was let go on the Mac with exactly ONE picture chosen: a short press without a drag shows the
    /// picture at full size (Quick Look). Held with a drag it slid the board, as always; with anything else
    /// chosen the short press starts typing (`spaceStartsTyping`). A picture has no words to type, so the
    /// key was free there.
    static func spaceShowsPicture(slid: Bool, held: TimeInterval, chosen: Int, pictureChosen: Bool, typing: Bool) -> Bool {
        !slid && held < shortPress && chosen == 1 && pictureChosen && !typing
    }
}

public enum MacHabits {
    // MARK: The Dock menu

    /// The most pinned boards the Dock menu lists (it is a short menu, not the whole list).
    public static let dockPinned = 10
    /// The boards last worked on that follow the pinned ones.
    public static let dockRecent = 5

    /// The boards in the Dock icon's menu: the pinned ones (at most ten), then the five that were changed
    /// last and are not pinned — sent to PARAGON or not. Each group newest change first.
    public static func dockBoards(_ boards: [Board]) -> (pinned: [Board], recent: [Board]) {
        let newest = boards.sorted { $0.changed > $1.changed }
        return (Array(newest.filter(\.pinned).prefix(dockPinned)), Array(newest.filter { !$0.pinned }.prefix(dockRecent)))
    }

    // MARK: Space on a picture

    /// One picture of a board, for looking at it at full size.
    public struct LookPicture: Equatable, Sendable {
        /// The picture thing on the board.
        public let id: UUID
        /// The stored picture.
        public let stored: String
        /// What the window that shows it is called: its caption, else "Picture 2".
        public let name: String
    }

    /// The board's pictures in reading order (row by row from the top, each row from the left): the order the
    /// arrow keys step through. A picture thing without a stored picture is left out. Two pictures are in one
    /// row when the second begins above the middle of the row's first.
    public static func lookPictures(of board: Board) -> [LookPicture] {
        let all = board.items.filter { $0.kind == .picture && !($0.picture ?? "").isEmpty }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
        var rows: [[Item]] = []
        for item in all {
            if let first = rows.last?.first, item.frame.minY < first.frame.midY {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }
        let ordered = rows.flatMap { $0.sorted { $0.frame.minX < $1.frame.minX } }
        var used: Set<String> = []
        var out: [LookPicture] = []
        for (at, item) in ordered.enumerated() {
            let base = lookName(caption: item.text, number: at + 1)
            // Two pictures never share a name: "Cabin", "Cabin 2".
            var name = base
            var n = 2
            while used.contains(name.lowercased()) {
                name = "\(base) \(n)"
                n += 1
            }
            used.insert(name.lowercased())
            out.append(LookPicture(id: item.id, stored: item.picture ?? "", name: name))
        }
        return out
    }

    /// A picture's name: the first line of its caption (at most 60 letters, nothing a file's name may not
    /// hold), else "Picture" with its place in the reading order.
    static func lookName(caption: String, number: Int) -> String {
        let line = caption.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let safe = line.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
        var name = String(ParagonExport.oneLine(safe).prefix(60)).trimmingCharacters(in: .whitespaces)
        while name.hasPrefix(".") { name.removeFirst() }
        return name.isEmpty ? "Picture \(number)" : name
    }

    // MARK: A photo from the iPhone

    /// How long the spot of a right-click stays the place for the photo (taking it takes a while).
    public static let cameraWait: TimeInterval = 120

    /// Where a photo from the iPhone lands. Asked for in the menu of empty board: at that spot, when it
    /// arrives within two minutes and the same board is still open. Otherwise nil: a free place near the
    /// middle of the view, as with the Picture tool.
    public static func cameraSpot(asked: CGPoint?, on board: UUID?, at time: Date, open: UUID, now: Date = Date()) -> CGPoint? {
        guard let asked, board == open else { return nil }
        let waited = now.timeIntervalSince(time)
        return waited >= 0 && waited <= cameraWait ? asked : nil
    }

    // MARK: Services ▸ New Seedboard Board from Selection

    /// The board made from the words marked in another app: the same rule as the Shortcuts action
    /// (`Outside.board`) — a list becomes a mind map, anything else one sticky note, the name is the first
    /// line. nil when there are no words at all: no empty board is made.
    public static func serviceBoard(from words: String?, now: Date = Date()) -> Board? {
        guard let words, !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return Outside.board(title: nil, text: words, now: now)
    }
}
