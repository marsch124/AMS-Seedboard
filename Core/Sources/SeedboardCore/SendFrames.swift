import Foundation
import CoreGraphics

// 0.5, the `send` lane: a plain frame with a name is a heading.
//
// Sorting done by dragging notes into named frames ("Pros", "Cons") is kept in the words that leave the
// board: in a note and a project the frame's name is a `###` heading with its things under it, in "Copy
// the board as text" it is "Pros:" with its lines. A frame with lanes has its own rule (ParagonLanes.swift);
// a frame with no name gives no heading, its things are listed with the others.

extension ParagonExport {
    /// Things in reading order: row by row from the top, each row from left to right. A row is the topmost
    /// thing left and every thing whose middle lies within its height.
    static func readingOrder(_ things: [Item]) -> [Item] {
        var left = things.enumerated().sorted { a, b in
            (a.element.frame.minY, a.element.frame.minX, a.offset) < (b.element.frame.minY, b.element.frame.minX, b.offset)
        }.map(\.element)
        var out: [Item] = []
        while let top = left.first {
            let band = top.frame
            var row = left.filter { $0.id == top.id || ($0.centre.y >= band.minY && $0.centre.y <= band.maxY) }
            row = row.enumerated().sorted { ($0.element.centre.x, $0.offset) < ($1.element.centre.x, $1.offset) }.map(\.element)
            out.append(contentsOf: row)
            let taken = Set(row.map(\.id))
            left.removeAll { taken.contains($0.id) }
        }
        return out
    }

    /// The things of a board for which `wanted` holds, sorted by the named plain frames they lie in.
    /// `groups`: one per named frame without lanes that holds such a thing, the frames in reading order, their
    /// things in reading order. `loose`: the things in no such frame, in reading order. A thing belongs to the
    /// smallest named plain frame its middle lies in; the ideas a mind map places belong to none.
    static func framed(_ board: Board, _ wanted: (Item) -> Bool) -> (loose: [Item], groups: [(name: String, things: [Item])]) {
        let frames = board.items.filter { $0.kind == .frame && $0.lanes == nil && !oneLine($0.text).isEmpty }
        var inFrame: [UUID: [Item]] = [:]
        var loose: [Item] = []
        for item in board.items where item.kind != .frame && wanted(item) {
            var home: Item?
            if !(item.kind == .idea && item.parent != nil) {
                for frame in frames where frame.frame.contains(item.centre) {
                    if let h = home, h.w * h.h <= frame.w * frame.h { continue }
                    home = frame
                }
            }
            if let home { inFrame[home.id, default: []].append(item) } else { loose.append(item) }
        }
        let groups = readingOrder(frames).compactMap { frame -> (name: String, things: [Item])? in
            guard let things = inFrame[frame.id] else { return nil }
            return (oneLine(frame.text), readingOrder(things))
        }
        return (readingOrder(loose), groups)
    }

    /// What stands under "Notes" in a note and a project: first the things that lie in no named frame, then
    /// per named frame `### Name` with its things. Empty when there is nothing to say.
    /// (The loose things stand first: after the last heading they would read as part of that frame.)
    static func notesBody(_ board: Board, picture: Bool) -> String {
        let notes = framed(board, isNoteThing)
        var out = ""
        if !notes.loose.isEmpty { out += notes.loose.map { noteBullet($0, picture: picture) }.joined(separator: "\n") + "\n\n" }
        for group in notes.groups {
            out += "### \(group.name)\n\n"
            out += group.things.map { noteBullet($0, picture: picture) }.joined(separator: "\n") + "\n\n"
        }
        return out
    }

    /// The "## Notes" section of a note; nothing when the board has no such things.
    static func notesText(_ board: Board, picture: Bool) -> String {
        let body = notesBody(board, picture: picture)
        return body.isEmpty ? "" : "## Notes\n\n" + body
    }
}
