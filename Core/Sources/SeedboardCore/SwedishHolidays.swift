import Foundation

/// 0.9: Sweden's public holidays, shaded on a timeline's Days and Weeks scales. English names.
public struct Holiday: Equatable, Sendable {
    public var day: Day
    public var name: String
}

public enum SwedishHolidays {
    /// Easter Sunday (the Gregorian rule).
    public static func easter(_ year: Int) -> Day {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return Day(year: year, month: month, day: day)
    }

    /// The first day from `start` (on or after) that falls on this weekday (0 Monday … 6 Sunday).
    private static func first(weekday: Int, from start: Day) -> Day {
        var day = start
        while day.weekday != weekday { day = day + 1 }
        return day
    }

    /// The holidays of one year, in date order.
    public static func holidays(in year: Int) -> [Holiday] {
        let easter = easter(year)
        func fixed(_ month: Int, _ day: Int) -> Day { Day(year: year, month: month, day: day) }
        return [
            Holiday(day: fixed(1, 1), name: "New Year's Day"),
            Holiday(day: fixed(1, 6), name: "Epiphany"),
            Holiday(day: easter - 2, name: "Good Friday"),
            Holiday(day: easter, name: "Easter Sunday"),
            Holiday(day: easter + 1, name: "Easter Monday"),
            Holiday(day: fixed(5, 1), name: "May Day"),
            Holiday(day: easter + 39, name: "Ascension Day"),
            Holiday(day: easter + 49, name: "Whit Sunday"),
            Holiday(day: fixed(6, 6), name: "National Day"),
            Holiday(day: first(weekday: 4, from: fixed(6, 19)), name: "Midsummer Eve"),
            Holiday(day: first(weekday: 5, from: fixed(6, 20)), name: "Midsummer Day"),
            Holiday(day: first(weekday: 5, from: fixed(10, 31)), name: "All Saints' Day"),
            Holiday(day: fixed(12, 24), name: "Christmas Eve"),
            Holiday(day: fixed(12, 25), name: "Christmas Day"),
            Holiday(day: fixed(12, 26), name: "Boxing Day"),
            Holiday(day: fixed(12, 31), name: "New Year's Eve"),
        ].sorted { $0.day < $1.day }
    }

    /// The holidays within these days (inclusive), by day.
    public static func names(from first: Day, to last: Day) -> [Day: String] {
        guard first <= last else { return [:] }
        var found: [Day: String] = [:]
        for year in first.parts.year...last.parts.year {
            for holiday in holidays(in: year) where holiday.day >= first && holiday.day <= last { found[holiday.day] = holiday.name }
        }
        return found
    }
}
