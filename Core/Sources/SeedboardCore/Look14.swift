import Foundation
import CoreGraphics

// 0.14, lane "look": Copy the look (15), big and small words (17), zoom to the chosen things (19),
// today's date while typing (26). The rules are here so they can be tested.

/// 15: what "Copy look" keeps of one thing: its colour, its shape kind (a flowchart shape) and its text size (a free text).
public struct CopiedLook: Equatable, Sendable {
    public var kind: ItemKind
    /// The colour as the thing shows it ("" = none, for a shape). nil: the thing has no colour of its own.
    public var colour: String?
    /// "title", "small" or nil (normal): only a free text carries one.
    public var textSize: String?

    public init(kind: ItemKind, colour: String?, textSize: String?) {
        self.kind = kind
        self.colour = colour
        self.textSize = textSize
    }
}

public extension Board {
    /// The look of one thing; nil when it has none worth copying (a picture, a door, a row of a timeline …).
    func lookToCopy(_ id: UUID) -> CopiedLook? {
        guard let item = item(id) else { return nil }
        switch item.kind {
        case .note, .frame, .drawing:
            return CopiedLook(kind: item.kind, colour: colourInUse(of: id), textSize: nil)
        case .idea:
            guard item.parent != nil else { return nil }
            return CopiedLook(kind: .idea, colour: colourInUse(of: id), textSize: nil)
        case .text:
            return CopiedLook(kind: .text, colour: nil, textSize: item.textSize)
        default:
            guard item.kind.isShape else { return nil }
            return CopiedLook(kind: item.kind, colour: item.colour, textSize: nil)
        }
    }

    /// Can this thing take any part of the look? (Used to switch "Paste look" on.)
    func canTakeLook(_ look: CopiedLook, _ id: UUID) -> Bool {
        guard let item = item(id), !isHidden(id) else { return false }
        return Board.lookParts(look, on: item).any
    }

    /// What of a look fits a kind of thing: a note keeps being a note (colour only, from the note colours),
    /// a shape takes colour and shape kind from a shape, a free text takes only the text size from a free text.
    internal static func lookParts(_ look: CopiedLook, on item: Item) -> (colour: String?, kind: ItemKind?, size: String??, any: Bool) {
        var colour: String?
        var kind: ItemKind?
        var size: String??
        switch item.kind {
        case .note:
            if let c = look.colour, Palette.notes.contains(c) { colour = c }
        case .frame:
            if let c = look.colour, Palette.names.contains(c) { colour = c }
        case .drawing:
            if let c = look.colour, Palette.names.contains(c) { colour = c }
        case .idea:
            if item.parent != nil, let c = look.colour, Palette.names.contains(c) { colour = c }
        case .text:
            if look.kind == .text { size = .some(look.textSize) }
        default:
            if item.kind.isShape {
                if let c = look.colour, c.isEmpty || Palette.names.contains(c) { colour = c }
                if look.kind.isShape, look.kind != item.kind { kind = look.kind }
            }
        }
        return (colour, kind, size, colour != nil || kind != nil || size != nil)
    }

    /// Puts a look on these things (only what fits each). Gives how many things changed.
    @discardableResult
    mutating func pasteLook(_ look: CopiedLook, on ids: [UUID]) -> Int {
        guard canBeChanged else { return 0 }
        var changed = 0
        for id in ids {
            guard let i = index(of: id), !isHidden(id) else { continue }
            let parts = Board.lookParts(look, on: items[i])
            guard parts.any else { continue }
            if let colour = parts.colour {
                switch items[i].kind {
                case .idea:
                    if let branch = mainBranch(of: id), let b = index(of: branch) { items[b].colour = colour }
                case .drawing:
                    recolourSketch(id, to: colour)
                default:
                    items[i].colour = colour
                }
            }
            if let kind = parts.kind { setKind(id, to: kind) }
            if let size = parts.size, let j = index(of: id) { items[j].textSize = size }
            changed += 1
        }
        return changed
    }
}

/// 17: the three sizes of a free text.
public enum TextSize {
    public static let title = "title"
    public static let small = "small"

    /// The size in points of a free text: title 28 (bold-ish), normal 17, small 13.
    public static func look(_ stored: String?) -> (size: Double, bold: Bool) {
        switch stored {
        case title: return (28, true)
        case small: return (13, false)
        default: return (17, false)
        }
    }

    /// The words for the menu: "Title", "Normal", "Small".
    public static func word(_ stored: String?) -> String {
        switch stored {
        case title: return "Title"
        case small: return "Small"
        default: return "Normal"
        }
    }
}

/// 26: today's date in words, "19 Nov 2026".
public enum DateWords {
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    public static func short(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day, (1...12).contains(m) else { return "" }
        return "\(d) \(months[m - 1]) \(y)"
    }
}

public extension Typing {
    /// Words put in where the cursor stands (or over what is chosen). `from` and `to` count UTF-16 units;
    /// out-of-range values mean the end of the words. Gives the new words and where the cursor stands afterwards.
    static func insert(_ text: String, in words: String, from: Int, to: Int) -> (words: String, cursor: Int) {
        let units = Array(words.utf16)
        let low = from < 0 || from > units.count ? units.count : from
        let high = to < low || to > units.count ? low : to
        let put = Array(text.utf16)
        let new = units[..<low] + put + units[high...]
        return (String(decoding: Array(new), as: UTF16.self), low + put.count)
    }
}
