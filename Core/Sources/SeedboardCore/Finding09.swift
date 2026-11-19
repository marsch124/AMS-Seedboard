import Foundation

// 0.9, lane "finding": boards put away, one line under each board, words inside pictures found by the
// search, the device's search (Spotlight) told about every board, and the names of the Undo steps.
// No screen in here: every rule has a data test (Finding09Tests.swift).

// MARK: Put away (pick 46)

/// Which boards show in the list, and which are put away. A put-away board is never deleted: it only
/// leaves the list until it is brought back. It still travels to other devices like any change.
public enum PutAway {
    /// The boards that show in the list: those that are not put away.
    public static func listed(_ boards: [Board]) -> [Board] { boards.filter { $0.putAway == nil } }

    /// The put-away boards, the one put away last first.
    public static func away(_ boards: [Board]) -> [Board] {
        boards.filter { $0.putAway != nil }.sorted { ($0.putAway ?? .distantPast) > ($1.putAway ?? .distantPast) }
    }

    /// What the list shows for these words: with none, only the boards that are not put away; with words,
    /// every board that holds them, put-away ones too (they are marked, see `isMarked`).
    public static func shown(_ query: String, in boards: [Board]) -> [Board] {
        BoardSearch.words(query).isEmpty ? listed(boards) : BoardSearch.find(query, in: boards)
    }

    /// "Put away (3)" at the bottom of the list; nil when nothing is put away.
    public static func rowWords(_ boards: [Board]) -> String? {
        let n = boards.filter { $0.putAway != nil }.count
        return n == 0 ? nil : "Put away (\(n))"
    }

    /// The board is put away now. A pinned board is unpinned first (a put-away board has no place at the top).
    public static func putAway(_ board: inout Board, now: Date = Date()) {
        board.pinned = false
        board.putAway = now
    }

    /// The board is back in the list.
    public static func bringBack(_ board: inout Board) { board.putAway = nil }
}

public extension Board {
    /// The board is put away (out of the list).
    var isPutAway: Bool { putAway != nil }
}

// MARK: Finding words (picture words, pick 48)

public extension BoardSearch {
    /// How a board answers a search.
    enum Way: Equatable, Sendable {
        /// Not found.
        case none
        /// Found by its name or the words on it.
        case words
        /// Found only because of words read inside a picture: the list says "in a picture".
        case picture
    }

    /// How `board` answers `query`. An empty query finds everything by its words.
    static func way(_ query: String, board: Board) -> Way {
        let wanted = words(query)
        guard !wanted.isEmpty else { return .words }
        if board.holds(wanted) { return .words }
        return board.holdsWithPictures(wanted) ? .picture : .none
    }
}

public extension Board {
    /// The words read inside this board's pictures, one per line.
    var pictureText: String {
        items.compactMap { $0.pictureWords }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Everything the search reads: the board's words and the words inside its pictures.
    var searchableText: String {
        let pictures = pictureText
        return pictures.isEmpty ? readableText : readableText + "\n" + pictures
    }

    internal func holdsWithPictures(_ words: [String]) -> Bool {
        let all = BoardSearch.plain(searchableText)
        return words.allSatisfy { all.contains($0) }
    }

    /// Keeps the words read inside a picture ("" = read, none found). Only a picture that is still on the board.
    mutating func setPictureWords(_ id: UUID, _ words: String) {
        guard let i = index(of: id), items[i].kind == .picture else { return }
        items[i].pictureWords = String(words.prefix(2000))
    }

    /// Pictures whose words were never read: the background pass reads these (nil = not read; "" = none found).
    var picturesToRead: [Item] { items.filter { $0.kind == .picture && $0.picture != nil && $0.pictureWords == nil } }
}

// MARK: One line under each board (pick 47)

public extension Board {
    /// The words that count as "ideas": things that carry words. Pictures, sketches, doors, frames and the
    /// timeline and "Who does what" things are counted in their own ways.
    private var carriesWords: [Item] {
        let others: Set<ItemKind> = [.frame, .bar, .milestone, .phase, .who, .message, .band, .section, .drawing, .picture, .door]
        return items.filter { !others.contains($0.kind) && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The one small line under a board in the list, e.g. "34 ideas · 12 done · 3 late".
    /// - ordinary board: things with words ("ideas"); "done" = to-do things ticked off (`doneThings`: the ones
    ///   PARAGON's note says are done, read back on this device); nothing counts as late.
    /// - timeline: bars, milestones; "done" = marked done (or in `doneThings`); "late" = past their last day and not done.
    /// - "Who does what": its own short count (people, messages …).
    /// Parts that are 0 are left out; one is "1 idea", never "1 ideas". A board with nothing on it says "Empty".
    func listLine(doneThings: Set<UUID> = [], today: Day = .today()) -> String {
        if isSequence { return sequenceCountLine }
        if isTimeline {
            func count(_ kind: ItemKind, _ one: String, _ many: String) -> String? {
                let n = items.filter { $0.kind == kind }.count
                return n == 0 ? nil : (n == 1 ? "1 \(one)" : "\(n) \(many)")
            }
            var parts = [count(.bar, "bar", "bars"), count(.milestone, "milestone", "milestones")].compactMap { $0 }
            if parts.isEmpty { return timelineCountLine }
            let progress = timelineProgress(today: today, also: doneThings)
            // With progress to tell, bars and milestones are counted together so the line fits an iPhone row.
            if progress.done > 0 || progress.late > 0 {
                let n = items.filter { $0.kind == .bar || $0.kind == .milestone }.count
                parts = [n == 1 ? "1 thing" : "\(n) things"]
            }
            if progress.done > 0 { parts.append("\(progress.done) done") }
            if progress.late > 0 { parts.append("\(progress.late) late") }
            return parts.joined(separator: " · ")
        }
        let words = carriesWords
        guard !words.isEmpty else { return countLine }
        var parts = [words.count == 1 ? "1 idea" : "\(words.count) ideas"]
        let done = words.filter { $0.todo && doneThings.contains($0.id) }.count
        if done > 0 { parts.append("\(done) done") }
        return parts.joined(separator: " · ")
    }
}

// MARK: The device's search (pick 49)

/// What the device's search (Spotlight) is told about a board.
public struct SpotlightWords: Equatable, Sendable {
    /// The name.
    public var title: String
    /// A line of its words (what the result shows under the name).
    public var line: String
    /// What kind of board: "Board", "Timeline", "Who does what".
    public var kind: String
    /// Every word, searched but never shown: the board's words and the words inside its pictures.
    public var text: String

    public static let domain = "boards"
}

public extension Outside {
    /// The board's kind in a word, for the search.
    static func kindWord(of board: Board) -> String {
        if board.isTimeline { return "Timeline" }
        if board.isSequence { return "Who does what" }
        return "Board"
    }

    /// What the search is told: title, a line of its words (or the one-line count when there are none),
    /// its kind, and all the words. A put-away board is told like any other: it stays findable.
    static func spotlight(of board: Board, limit: Int = 20_000) -> SpotlightWords {
        let words = searchWords(of: board)
        return SpotlightWords(title: board.title,
                              line: words.isEmpty ? board.listLine() : words,
                              kind: kindWord(of: board),
                              text: String(board.searchableText.prefix(limit)))
    }
}

// MARK: The names of the Undo steps (pick 50)

/// Describes what one step changed, from the board before it and the board after it, in plain words.
public enum StepWords {
    private static func things(_ n: Int) -> String { n == 1 ? "1 thing" : "\(n) things" }

    /// "an idea", "a sticky note", "some text" …
    private static func one(_ kind: ItemKind) -> String {
        switch kind {
        case .idea: return "an idea"
        case .box: return "a box"
        case .round: return "a round box"
        case .diamond: return "a diamond"
        case .oval: return "an oval"
        case .note: return "a sticky note"
        case .text: return "some text"
        case .frame: return "a frame"
        case .bar: return "a bar"
        case .milestone: return "a milestone"
        case .phase: return "a phase"
        case .person: return "a person"
        case .document: return "a document"
        case .slanted: return "a slanted box"
        case .store: return "a store"
        case .who: return "a name"
        case .message: return "a message"
        case .band: return "a note"
        case .section: return "a section"
        case .drawing: return "a sketch"
        case .picture: return "a picture"
        case .door: return "a door"
        case .table: return "a table"
        case .block: return "a block"
        }
    }

    /// What changed between `before` and `after`: "Added a sticky note", "Removed 2 things", "Changed words",
    /// "Coloured 1 thing", "Moved 3 things" … One name per step: the first that fits wins.
    public static func describe(before: Board, after: Board) -> String {
        let old = Dictionary(before.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let new = Dictionary(after.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let added = after.items.filter { old[$0.id] == nil }
        let removed = before.items.filter { new[$0.id] == nil }
        let both = after.items.compactMap { item in old[item.id].map { (was: $0, now: item) } }

        if !added.isEmpty {
            if added.count == 1, let first = added.first { return "Added \(one(first.kind))" }
            return "Added \(things(added.count))"
        }
        if !removed.isEmpty { return "Removed \(things(removed.count))" }

        let reworded = both.filter { $0.was.text != $0.now.text }.count
        let linkWords = after.links.filter { link in before.links.first { $0.id == link.id }.map { $0.text != link.text } ?? false }.count
        if reworded + linkWords > 0 { return "Changed words" }

        let linksAdded = after.links.filter { link in !before.links.contains { $0.id == link.id } }.count
        if linksAdded > 0 { return linksAdded == 1 ? "Added an arrow" : "Added \(linksAdded) arrows" }
        let linksRemoved = before.links.filter { link in !after.links.contains { $0.id == link.id } }.count
        if linksRemoved > 0 { return linksRemoved == 1 ? "Removed an arrow" : "Removed \(linksRemoved) arrows" }

        let coloured = both.filter { $0.was.colour != $0.now.colour }.count
        let arrowsColoured = after.links.filter { link in before.links.first { $0.id == link.id }.map { $0.colour != link.colour } ?? false }.count
        if coloured + arrowsColoured > 0 { return "Coloured \(things(coloured + arrowsColoured))" }

        let moved = both.filter { $0.was.x != $0.now.x || $0.was.y != $0.now.y }.count
        let resized = both.filter { ($0.was.w != $0.now.w || $0.was.h != $0.now.h) && $0.was.x == $0.now.x && $0.was.y == $0.now.y }.count
        if moved > 0 { return "Moved \(things(moved))" }
        if resized > 0 { return "Resized \(things(resized))" }

        let drawn = both.filter { $0.was.strokes != $0.now.strokes }.count
        if drawn > 0 { return "Changed a sketch" }
        let ticked = both.filter { $0.was.todo != $0.now.todo || $0.was.doneDay != $0.now.doneDay }.count
        if ticked > 0 { return "Changed to-do marks" }
        let voted = both.filter { $0.was.votes != $0.now.votes }.count
        if voted > 0 { return "Gave a vote" }
        let locked = both.filter { $0.was.locked != $0.now.locked }.count
        if locked > 0 { return "Pinned in place" }
        if before.title != after.title { return "Renamed the board" }
        if before.pinned != after.pinned { return after.pinned ? "Pinned the board" : "Unpinned the board" }
        if before.putAway != after.putAway { return after.putAway == nil ? "Brought the board back" : "Put the board away" }
        if before.colour != after.colour { return "Coloured the board" }
        if both.contains(where: { $0.was != $0.now }) { return "Changed 1 thing" }
        return "Changed the board"
    }

    /// "Moved 3 things · 21:40": the name with the time, in the owner's own clock.
    public static func line(_ words: String, at time: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: time)
        return "\(words) · " + String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// One step of the undo list.
    public struct Step: Equatable, Sendable {
        /// How many Undos take the board back to just before this step (1 = the newest).
        public var undos: Int
        public var words: String
        public var time: Date
    }

    /// The list, newest first: `before[i]` is the board before step i (oldest first), `now` the board today,
    /// `times[i]` when step i was taken. At most `limit` steps.
    public static func list(before: [Board], now: Board, times: [Date], limit: Int = 120) -> [Step] {
        var steps: [Step] = []
        let n = before.count
        guard n > 0, times.count == n else { return [] }
        for i in stride(from: n - 1, through: 0, by: -1) {
            let after = i + 1 < n ? before[i + 1] : now
            steps.append(Step(undos: n - i, words: describe(before: before[i], after: after), time: times[i]))
            if steps.count >= limit { break }
        }
        return steps
    }
}
