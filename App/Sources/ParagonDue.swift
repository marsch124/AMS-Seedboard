import SwiftUI
import SeedboardCore

// 0.9 (pick 41): the colours of the small due day beside a to-do box that PARAGON has a due day for.
// "5 Dec" in the faint grey of the board's small words, "Today" in PARAGON's purple, a task past due and
// not done in a faint red. All of them are read from PARAGON each time and drawn by `BoardPainter`.

extension Paint {
    /// Past due and not done: a faint red that reads by day and by night.
    var late: Color { Color(red: night ? 0xE0 / 255 : 0xC2 / 255, green: night ? 0x7A / 255 : 0x4B / 255, blue: night ? 0x72 / 255 : 0x45 / 255) }
    /// Due today: PARAGON's purple, the lighter shade by night.
    var today: Color { night ? Color(red: 0xB5 / 255, green: 0x9C / 255, blue: 0xEB / 255) : Part.paragon.fill }
}
