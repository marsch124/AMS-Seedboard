import Foundation

// 0.11: a sane range for dates (pick 3), the starter's picture "from today" (pick 20), and the board's own due day (pick 47).

/// The years a date may have. A date outside is refused on the Dates page, and a board file that holds one never
/// makes the timeline draw a mark for every day in between.
public enum DayRange {
    public static let firstYear = 1900
    public static let lastYear = 2200
    /// The most date marks the timeline draws in one go (a screen holds a few hundred).
    public static let mostMarks = 1500

    public static func sane(_ day: Day) -> Bool { (firstYear...lastYear).contains(day.parts.year) }

    /// The plain line for a refused date.
    public static let refusal = "Pick a date between the years \(firstYear) and \(lastYear)."

    /// The last day to draw from a first one: never more than `mostMarks` days on.
    public static func drawEnd(from first: Day, to last: Day) -> Day { min(last, first + mostMarks) }
}

public extension StarterShelf {
    /// The board of an own timeline starter as its small picture shows it: moved to "from today", as a new board from it
    /// would get. The stamp is the start of today, so the kept picture is drawn again each day, not each second.
    static func shownBoard(_ board: Board, now: Date = Date(), calendar: Calendar = .current) -> Board {
        guard board.isTimeline else { return board }
        var b = board
        move(&b, byDays: Day(now, calendar: calendar) - Day(board.changed, calendar: calendar))
        b.changed = calendar.startOfDay(for: now)
        return b
    }
}

public extension Board {
    /// The due day, when the board holds a sane one.
    var dueDay: Day? {
        guard let due, let day = Day(iso: due), DayRange.sane(day) else { return nil }
        return day
    }

    /// "Due 12 Jan" (with the year when it is not this year), and whether it is past (before today).
    func dueWords(today: Day = .today()) -> (text: String, past: Bool)? {
        guard let day = dueDay else { return nil }
        let sameYear = day.parts.year == today.parts.year
        return ("Due " + (sameYear ? day.short : day.long), day < today)
    }

    /// A due day is set, or taken away (nil). A day outside the sane years is not set.
    mutating func setDue(_ day: Day?) {
        if let day { if DayRange.sane(day) { due = day.iso } } else { due = nil }
    }
}

extension ParagonExport {
    /// A project text with the board's own due day as the project's `due:` (it wins over the timeline's last day).
    static func withBoardDue(_ text: String, board: Board) -> String {
        guard let day = board.dueDay, text.hasPrefix("---\n"), let close = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) else { return text }
        var head = String(text[text.startIndex..<close.lowerBound])
        head = head.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.hasPrefix("due:") }.joined(separator: "\n")
        return head + "\ndue: \(day.iso)" + text[close.lowerBound...]
    }
}
