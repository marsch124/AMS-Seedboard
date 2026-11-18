import Foundation

// 0.5, the iPhone: what a long press on the app's icon offers, the links those lines follow, and the ways a
// picture comes onto a board from the Picture tile. Plain rules only; the screens are in the app
// (QuickActions.swift, PictureWays.swift).

// MARK: - Links that make a new board

/// `seedboard://new/<starter id>`: a link that makes a new board and opens it.
/// The starter id is a built-in's stored name ("blank", "mindMap", "flow" …) or the id of one of the owner's
/// own starters. `seedboard://new/clipboard` makes a board from the words on the clipboard.
public enum NewLink {
    public enum Ask: Equatable, Sendable {
        /// A starter of the shelf, by its id.
        case starter(String)
        /// The words on the clipboard: a list becomes a mind map, anything else one sticky note.
        case clipboard
    }

    static let clipboardWord = "clipboard"

    /// What a link asks for; nil when it is not a `seedboard://new/…` link.
    /// `seedboard://new` and `seedboard://new/` mean a blank board.
    public static func ask(from url: URL) -> Ask? {
        guard url.scheme?.lowercased() == "seedboard", url.host?.lowercased() == "new" else { return nil }
        let word = url.pathComponents.first { $0 != "/" } ?? ""
        if word.isEmpty { return .starter(Starter.blank.id) }
        if word.lowercased() == clipboardWord { return .clipboard }
        return .starter(word)
    }

    /// The link for an ask: `seedboard://new/mindMap`.
    public static func link(_ ask: Ask) -> String {
        switch ask {
        case .starter(let id): return "seedboard://new/\(id)"
        case .clipboard: return "seedboard://new/\(clipboardWord)"
        }
    }

    /// What was made, and the one line to say when it is not quite what was asked for.
    public struct Made: Equatable, Sendable {
        public var board: Board
        public var line: String?
    }

    /// The board a link opens.
    /// - A starter: a fresh board from that starter of the shelf — the owner's own version when he changed it,
    ///   capitals in the id do not matter. A starter he removed, or one this device does not know, gives a blank
    ///   board and says so.
    /// - The clipboard: the same rule as "New board from text" (a list becomes a mind map, anything else one
    ///   sticky note, the board named after its first line). Nothing on the clipboard gives a blank board and says so.
    public static func board(for ask: Ask, shelf: StarterShelf, clipboard: String?, now: Date = Date()) -> Made {
        switch ask {
        case .starter(let id):
            let wanted = id.lowercased()
            if let found = shelf.shown.first(where: { $0.id.lowercased() == wanted }),
               let board = shelf.makeBoard(from: found.id, now: now) {
                // A starter a newer Seedboard wrote would make a board that cannot be saved.
                guard board.canBeChanged else {
                    return Made(board: Starter.blank.board(now: now),
                                line: "This starter was made by a newer Seedboard. Update the app to use it. A blank board was made instead.")
                }
                return Made(board: board, line: nil)
            }
            return Made(board: Starter.blank.board(now: now), line: "That starter is not here any more. This is a blank board.")
        case .clipboard:
            let words = (clipboard ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else {
                return Made(board: Starter.blank.board(now: now), line: "There were no words to paste. This is a blank board.")
            }
            return Made(board: Outside.board(title: nil, text: words, now: now), line: nil)
        }
    }
}

// MARK: - A long press on the app's icon

/// One line of the menu a long press on the app's icon shows (iPhone and iPad).
public struct QuickAction: Equatable, Sendable {
    /// The hand-drawn mark beside the line.
    public enum Mark: String, Sendable, CaseIterable {
        /// A plus: a new board.
        case add
        case mindMap
        /// The clipboard.
        case paste
        /// A board: one of the pinned boards.
        case board
    }

    public var title: String
    /// The small grey line under the title; nil for none.
    public var subtitle: String?
    /// Where the line leads: `seedboard://new/…` or `seedboard://board/<id>`.
    public var link: String
    public var mark: Mark
}

public enum QuickActions {
    /// How many pinned boards the menu offers.
    public static let pinnedShown = 2
    /// How many lines the device shows (iPhone and iPad show four of the app's own; a fifth falls off).
    public static let most = 4

    /// The lines, at most four, in order: New board, New mind map (only while there is room for it), New board
    /// from the clipboard, then the first two pinned boards as the list shows them (each with its count line under
    /// the name). 0.6: with two boards pinned, New mind map makes way, so both pinned boards fit. A board made by
    /// a newer Seedboard is offered too: it opens to be read.
    public static func list(pinned: [Board]) -> [QuickAction] {
        let boards = pinned.filter(\.pinned).prefix(pinnedShown).map { board in
            let name = ParagonExport.oneLine(board.title)
            return QuickAction(title: name.isEmpty ? "Board" : name, subtitle: board.countLine,
                               link: "seedboard://board/\(board.id.uuidString)", mark: .board)
        }
        var out = [QuickAction(title: "New board", subtitle: nil, link: NewLink.link(.starter(Starter.blank.id)), mark: .add)]
        if boards.count + 3 <= most {
            out.append(QuickAction(title: "New mind map", subtitle: nil, link: NewLink.link(.starter(Starter.mindMap.id)), mark: .mindMap))
        }
        out.append(QuickAction(title: "New board from the clipboard", subtitle: nil, link: NewLink.link(.clipboard), mark: .paste))
        return out + boards
    }
}

// MARK: - The ways a picture comes in from the Picture tile

/// Holding the Picture tile (iPhone and iPad) opens a small plate with these three ways.
public enum PictureWay: String, CaseIterable, Identifiable, Sendable {
    case photos, camera, scan

    public var id: String { rawValue }

    /// The word on the plate.
    public var word: String {
        switch self {
        case .photos: return "Photos"
        case .camera: return "Take a photo"
        case .scan: return "Scan a page"
        }
    }

    /// The most pictures one visit to Photos or one scan puts on a board (the same as the Photos picker allows).
    public static let most = 12

    /// How many of the scanned pages land on the board, and the line to say when some were left out.
    public static func pages(scanned: Int) -> (land: Int, line: String?) {
        let land = min(max(scanned, 0), most)
        guard scanned > land else { return (land, nil) }
        return (land, "A scan puts \(most) pages on a board at most. The first \(most) of \(scanned) are here.")
    }

    /// The line said when the way needs a camera and this device has none.
    public static let noCamera = "This device has no camera."
}
