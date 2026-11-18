import SwiftUI
import AMSIcons

/// Marks that are new in 0.2. Until they are drawn in the shared icon library each one shows a
/// stand-in; when the library has them, only `standIn` below changes — the screens keep their names.
enum NewMark: String, CaseIterable {
    // Timeline board
    case timeline, bar, milestone, today, calendar
    // Drawing with the Pencil
    case draw, rubber, thin, medium, thick
    // Who does what (sequence)
    case sequence, person, answer
    // Shapes and lanes
    case document, slanted, store, lanes
    // Tidy
    case lineUp, evenGaps, sameSize
    // Arrows
    case oneWay, bothWays, noEnds, dashed
    // Mind maps
    case moveUp, moveDown, outLevel, ideaUnder, nextIdea, branch
    // Boards
    case bringBack, earlier, export, search, cut, paste, rename

    var standIn: AppMark {
        switch self {
        case .timeline, .calendar: return .seedStarter
        case .bar, .document, .slanted: return .seedBox
        case .milestone: return .seedDiamond
        case .today, .bringBack: return .seedPin
        case .draw, .rubber, .thin, .medium, .thick, .rename: return .seedText
        case .sequence, .answer, .oneWay, .bothWays, .noEnds, .dashed: return .seedArrow
        case .person: return .seedRound
        case .store: return .seedOval
        case .lanes: return .seedFrame
        case .lineUp, .evenGaps, .sameSize, .search: return .seedFit
        case .moveUp, .moveDown, .outLevel, .ideaUnder, .nextIdea, .branch: return .seedMindMap
        case .earlier, .export, .cut, .paste: return .seedBoard
        }
    }
}
