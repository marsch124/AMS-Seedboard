import Foundation

/// Rules for what is typed into an idea.
public enum Typing {
    private static func breaks(_ text: String) -> Int { text.unicodeScalars.filter { $0 == "\n" }.count }

    /// The screen keyboard's Return arrives as one new line break in the words. In an idea that
    /// means "this idea is done": the words come back without that break. nil when the change is
    /// not one new break (plain typing, or several lines pasted in, which stay as they are).
    /// Line breaks that were there before (made with Shift and Return) are kept.
    public static func withoutNewBreak(old: String, new: String) -> String? {
        guard breaks(new) == breaks(old) + 1 else { return nil }
        let before = Array(old.unicodeScalars)
        var after = Array(new.unicodeScalars)
        var at = 0
        while at < before.count, at < after.count, before[at] == after[at] { at += 1 }
        if at < after.count, after[at] == "\n" {
            after.remove(at: at)
        } else if let last = after.lastIndex(of: "\n") {
            after.remove(at: last)
        }
        var out = String.UnicodeScalarView()
        out.append(contentsOf: after)
        return String(out)
    }
}
