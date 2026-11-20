import Foundation

/// 0.19 (18): the board's paper colour (`Board.paper`). nil = the plain background every board has had.
/// The colours live here, in one place, so they can be tuned after a look. Day and night as 0xRRGGBB.
public enum PaperColour: String, CaseIterable, Sendable {
    case paper, warmGrey, nightBlue

    public var word: String {
        switch self {
        case .paper: return "Paper"
        case .warmGrey: return "Warm grey"
        case .nightBlue: return "Night blue"
        }
    }

    public var dayHex: Int {
        switch self {
        case .paper: return 0xFBF7EE
        case .warmGrey: return 0xF0EEEA
        case .nightBlue: return 0xEDF1F7
        }
    }

    public var nightHex: Int {
        switch self {
        case .paper: return 0x1F1C17
        case .warmGrey: return 0x252321
        case .nightBlue: return 0x151C2C
        }
    }

    /// The word of "no colour" in the row of swatches.
    public static let plainWord = "Plain"
}

public extension Board {
    /// nil is plain. An unknown stored word reads as plain and is kept as it is.
    var paperColour: PaperColour? {
        get { paper.flatMap(PaperColour.init(rawValue:)) }
        set { paper = newValue?.rawValue }
    }
}
