import Foundation

/// Rules for the menu bar and the keys (pick 25).
public enum MenuRules {
    /// One line of the Insert menu: a tool, and the letter key that makes the same thing.
    public struct ToolLine: Equatable, Sendable {
        public let name: String
        public let letter: Character
        /// The thing the tool makes; nil is the arrow tool (it joins two shapes).
        public let kind: ItemKind?
    }

    /// The seven tools of the tool bar, in its order.
    public static let tools: [ToolLine] = [
        ToolLine(name: "Mind map", letter: "m", kind: .idea),
        ToolLine(name: "Box", letter: "b", kind: .box),
        ToolLine(name: "Diamond", letter: "d", kind: .diamond),
        ToolLine(name: "Arrow", letter: "a", kind: nil),
        ToolLine(name: "Sticky note", letter: "n", kind: .note),
        ToolLine(name: "Text", letter: "t", kind: .text),
        ToolLine(name: "Frame", letter: "f", kind: .frame),
    ]

    /// Two shapes that have a letter but no button of their own.
    public static let moreShapes: [ToolLine] = [
        ToolLine(name: "Round box", letter: "u", kind: .round),
        ToolLine(name: "Oval", letter: "o", kind: .oval),
    ]

    /// A letter key makes a thing only while the board's drawing surface has the keys, no words are
    /// being typed and nothing is chosen. With one thing chosen a letter starts typing in it; in a text
    /// field it is a letter. Only in the first case may a menu line carry the letter as its key, so a
    /// menu key can never take a letter away from words.
    public static func lettersAreTools(surfaceHasKeys: Bool, typing: Bool, chosen: Int, arrowChosen: Bool, readOnly: Bool) -> Bool {
        surfaceHasKeys && !typing && chosen == 0 && !arrowChosen && !readOnly
    }

    /// The longest press of Space that still counts as "start typing" (Mac).
    public static let shortPress: TimeInterval = 0.5

    /// Space was let go on the Mac. Held with a drag it slid the board; pressed shortly without one
    /// it starts typing in the one chosen thing, as Space always did.
    public static func spaceStartsTyping(slid: Bool, held: TimeInterval, chosen: Int, typing: Bool) -> Bool {
        !slid && held < shortPress && chosen == 1 && !typing
    }
}
