import SwiftUI
import SeedboardCore

// 0.19, the bar beside the chosen thing (picks 10, 12, 14, 15): the last colours first in the colour row,
// "Stack", sticky notes in two sizes ("Small Note" / "Normal Note"), "Put in a frame".

/// The SF Symbols this part uses (Apple's own); the names are in one place so one can be swapped.
enum Marks19Canvas {
    static let stack = "rectangle.stack"
    static let putInFrame = "square.dashed"
    static let smallNote = "square.arrowtriangle.4.outward"
    static let normalNote = "square.arrowtriangle.4.outward"
}

/// The last colours used, kept on this device (never in the board, never in iCloud).
enum RecentColours {
    static let key = "recentColours19"

    static var names: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func used(_ name: String) {
        UserDefaults.standard.set(Canvas19.remembered(name, in: names), forKey: key)
    }

    /// The colour names in the order the row shows them.
    static func ordered(_ offered: [String]) -> [String] { Canvas19.colourRow(offered, recent: names) }
}

extension BoardSession {
    /// "Stack": the chosen free things fall into one column.
    func stackChosen() {
        let ids = selection
        guard editing == nil else { return }
        change { $0.stack(ids) }
    }

    /// "Small Note" / "Normal Note" for the chosen sticky notes.
    func setNoteSize(small: Bool) {
        let ids = selection
        guard editing == nil else { return }
        change(widen: ids) { $0.setNoteSize(ids, small: small) }
    }

    /// "Put in a frame": a frame grows round the chosen things, is chosen, and its name field opens.
    func putChosenInFrame() {
        guard !readOnly, board.canFrame(selection) else { return }
        if editing != nil { commitEdit() }
        let ids = selection
        var made: UUID?
        change { made = $0.putInFrame(ids) }
        if let made { beginEdit(made, isNew: true) }
    }

    var stackCount: Int { selection.count > 1 ? board.stackable(selection).count : 0 }
    var canPutInFrame: Bool { !readOnly && editing == nil && !selection.isEmpty && board.canFrame(selection) }
    var chosenNotes: [Item] { board.noteIDs(selection).compactMap { board.item($0) } }
}

extension BarActions {
    /// Stack, Small Note / Normal Note, Put in a frame: they go in just before the hairline of "Remove" (behind the "…" when narrow).
    func withCanvas19(_ list: [BarAction]) -> [BarAction] {
        let session = session
        var extra: [BarAction] = []
        if session.stackCount >= 2 {
            extra.append(act("stack", "Stack", .symbol(Marks19Canvas.stack), show: .wideWord, drop: 6) { session.stackChosen() })
        }
        let notes = session.chosenNotes
        if !notes.isEmpty, notes.count == session.selection.count {
            let allSmall = notes.allSatisfy { $0.textSize == TextSize.small }
            extra.append(act(allSmall ? "normalNote" : "smallNote", allSmall ? "Normal Note" : "Small Note",
                             .symbol(allSmall ? Marks19Canvas.normalNote : Marks19Canvas.smallNote),
                             show: .wideWord, drop: 6) { session.setNoteSize(small: !allSmall) })
        }
        if session.canPutInFrame {
            extra.append(act("putInFrame", "Put in a frame", .symbol(Marks19Canvas.putInFrame), show: .wideWord, drop: 6) { session.putChosenInFrame() })
        }
        guard !extra.isEmpty, !list.isEmpty else { return list }
        var all = list
        let at = all.lastIndex { $0.id == prefix + "remove" } ?? all.count
        all.insert(contentsOf: extra, at: at)
        return all
    }
}
