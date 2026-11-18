import SwiftUI
import AMSIcons

/// Marks that are new in 0.2, by the name the screens use; each is a drawing in the shared icon library.
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
    // 0.3: a picture on a board; save a board as a starter
    case picture, saveStarter
    // 0.4: a caption under a picture, cropping a picture (stand-ins until the lead swaps them)
    case caption, crop
    // 0.5: a door to another board; next note and
    // next shape while typing; turn a thing into another kind; tidy a pile into a grid; sort by colour; break an idea
    // into notes; a bar is done; catch up; share, as PDF, as words, print; take a photo, scan a page.
    case door, nextNote, nextShape, turnInto, tidy, byColour, breakNotes, done, catchUp
    case share, pdf, words, print, camera, scan
    // 0.10: the buttons of 0.9 that borrowed a neighbour's mark or showed only words.
    case balance, highlighter, lasso, makeTyped, drawOnIt, vote, tickList, legend, focus, showFrames, smallMap

    /// The drawing in the shared icon library (AMS-Icons, the seed family).
    var standIn: AppMark {
        switch self {
        case .timeline: return .seedTimeline
        case .bar: return .seedBar
        case .milestone: return .seedMilestone
        case .today: return .seedToday
        case .calendar: return .seedCalendar
        case .draw: return .seedDraw
        case .rubber: return .seedRubber
        case .thin: return .seedThin
        case .medium: return .seedMedium
        case .thick: return .seedThick
        case .sequence: return .seedSequence
        case .person: return .seedPerson
        case .answer: return .seedAnswer
        case .document: return .seedDocument
        case .slanted: return .seedSlanted
        case .store: return .seedStore
        case .lanes: return .seedLanes
        case .lineUp: return .seedLineUp
        case .evenGaps: return .seedEvenGaps
        case .sameSize: return .seedSameSize
        case .oneWay: return .seedOneWay
        case .bothWays: return .seedBothWays
        case .noEnds: return .seedNoEnds
        case .dashed: return .seedDashed
        case .moveUp: return .seedMoveUp
        case .moveDown: return .seedMoveDown
        case .outLevel: return .seedOutLevel
        case .ideaUnder: return .seedIdeaUnder
        case .nextIdea: return .seedNextIdea
        case .branch: return .seedBranch
        case .bringBack: return .seedBringBack
        case .earlier: return .seedEarlier
        case .export: return .seedExport
        case .search: return .seedSearch
        case .cut: return .seedCut
        case .paste: return .seedPaste
        case .rename: return .seedRename
        case .picture: return .seedPicture
        case .saveStarter: return .seedSaveStarter
        // Stand-ins until the lead swaps them for the real drawings.
        case .caption: return .seedCaption
        case .crop: return .seedCrop
        // 0.5: the real drawings (AMS-Icons 8e79eaf).
        case .door: return .seedDoor
        case .nextNote: return .seedNextNote
        case .nextShape: return .seedNextShape
        case .turnInto: return .seedTurnInto
        case .tidy: return .seedTidy
        case .byColour: return .seedByColour
        case .breakNotes: return .seedBreakNotes
        case .done: return .seedDone
        case .catchUp: return .seedCatchUp
        case .share: return .seedShare
        case .pdf: return .seedPDF
        case .words: return .seedWords
        case .print: return .seedPrint
        case .camera: return .seedCamera
        case .scan: return .seedScan
        // 0.10 (AMS-Icons a6bf561).
        case .balance: return .seedBalance
        case .highlighter: return .seedHighlighter
        case .lasso: return .seedLasso
        case .makeTyped: return .seedMakeTyped
        case .drawOnIt: return .seedDrawOnIt
        case .vote: return .seedVote
        case .tickList: return .seedTickList
        case .legend: return .seedLegend
        case .focus: return .seedFocus
        case .showFrames: return .seedShowFrames
        case .smallMap: return .seedSmallMap
        }
    }
}

/// A menu line with its hand-drawn mark (0.10). Menus take only pictures, so the mark is drawn once into
/// a template picture the menu tints like its words.
struct MarkLabel: View {
    let words: String
    let mark: NewMark
    init(_ words: String, _ mark: NewMark) { self.words = words; self.mark = mark }

    var body: some View {
        if let picture = MarkPicture.image(mark) {
            Label { Text(words) } icon: { picture }
        } else {
            Text(words)
        }
    }
}

@MainActor
enum MarkPicture {
    private static var made: [NewMark: Image] = [:]

    static func image(_ mark: NewMark) -> Image? {
        if let done = made[mark] { return done }
        let renderer = ImageRenderer(content: AppMarkView(mark.standIn, size: 18, colour: .black).frame(width: 18, height: 18))
        renderer.scale = 3
        guard let cg = renderer.cgImage else { return nil }
        #if os(macOS)
        let ns = NSImage(cgImage: cg, size: NSSize(width: 18, height: 18))
        ns.isTemplate = true
        let picture = Image(nsImage: ns)
        #else
        let picture = Image(uiImage: UIImage(cgImage: cg, scale: 3, orientation: .up).withRenderingMode(.alwaysTemplate))
        #endif
        made[mark] = picture
        return picture
    }
}
