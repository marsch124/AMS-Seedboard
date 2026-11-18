import Foundation
import CoreGraphics

/// The ways a new board can begin.
public enum Starter: String, CaseIterable, Identifiable, Sendable {
    case blank, mindMap, flow, prosCons, steps
    case timeline
    case sequence
    case decisionGrid, weeklyReview, swot

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .blank: return "Blank board"
        case .mindMap: return "Mind map"
        case .flow: return "Flow"
        case .prosCons: return "Pros and cons"
        case .steps: return "Plan in steps"
        case .timeline: return "Timeline"
        case .sequence: return "Who does what"
        case .decisionGrid: return "Decision grid"
        case .weeklyReview: return "Weekly review"
        case .swot: return "SWOT"
        }
    }

    public var hint: String {
        switch self {
        case .blank: return "An empty sheet, you start from nothing"
        case .mindMap: return "One idea in the middle, branches around it"
        case .flow: return "Shapes with arrows and a yes or no choice"
        case .prosCons: return "Two columns of sticky notes"
        case .steps: return "Five steps in a row, each with a note"
        case .timeline: return "Bars on days, with what comes after what"
        case .sequence: return "People in a row, messages in order"
        case .decisionGrid: return "Options down, what matters across"
        case .weeklyReview: return "Done, Stuck, Next week and Ideas"
        case .swot: return "Strengths, weaknesses, chances, threats"
        }
    }

    /// A new board with this start on it, centred round (0,0).
    public func board(title: String? = nil, now: Date = Date()) -> Board {
        var board = Board(title: title ?? (self == .blank ? "New board" : name), created: now)
        if self == .timeline { return Board.timelineStart(title: board.title, now: now) }
        if self == .sequence { return Board.sequenceStart(title: board.title, now: now) }
        switch self {
        case .blank:
            break
        case .timeline:
            break
        case .sequence:
            break
        case .decisionGrid:
            board.decisionGridStart()
        case .weeklyReview:
            board.framesStart([("Done", "green", "Finished a thing"), ("Stuck", "red", "Waiting on something"),
                               ("Next week", "blue", "Plan a thing"), ("Ideas", "purple", "Try something new")])
        case .swot:
            board.framesStart([("Strengths", "green", "What goes well"), ("Weaknesses", "red", "What is hard"),
                               ("Opportunities", "blue", "What could help"), ("Threats", "orange", "What could go wrong")])
        case .mindMap:
            let centre = board.addMap(from: [OutlineNode("Main idea", [
                OutlineNode("First thought"), OutlineNode("Second thought"),
                OutlineNode("Third thought"), OutlineNode("Fourth thought"),
            ])], title: nil, at: .zero)
            if let i = board.index(of: centre) { board.items[i].bothSides = true }
            board.layoutMaps()
        case .flow:
            let gap = 70.0
            let kinds: [(ItemKind, String)] = [(.round, "Start"), (.box, "Step"), (.diamond, "Decision?"), (.box, "Do it")]
            let total = kinds.map { Double($0.0.defaultSize.width) }.reduce(0, +) + gap * Double(kinds.count - 1)
            var left = -total / 2
            var ids: [UUID] = []
            var diamondMid = CGPoint.zero
            for (kind, text) in kinds {
                let w = Double(kind.defaultSize.width)
                let mid = CGPoint(x: left + w / 2, y: 0)
                // Coloured from the start: the Start is green, the decision purple, the steps blue.
                ids.append(board.add(kind, centre: mid, text: text, colour: kind == .round ? "green" : kind == .diamond ? "purple" : "blue"))
                if kind == .diamond { diamondMid = mid }
                left += w + gap
            }
            let again = Double(ItemKind.box.defaultSize.height)
            let low = board.add(.box, centre: CGPoint(x: diamondMid.x,
                                                      y: diamondMid.y + Double(ItemKind.diamond.defaultSize.height) / 2 + gap + again / 2),
                                text: "Think again", colour: "blue")
            board.link(from: ids[0], to: ids[1])
            board.link(from: ids[1], to: ids[2])
            board.link(from: ids[2], to: ids[3], text: "Yes")
            board.link(from: ids[2], to: low, text: "No")
            for i in board.links.indices where !board.links[i].text.isEmpty {
                board.links[i].colour = board.links[i].text == "Yes" ? "green" : "red"
            }
        case .prosCons:
            let question = board.add(.text, centre: CGPoint(x: 0, y: -250), text: "What are we deciding?")
            if let i = board.index(of: question) {
                let size = Board.roughSize(for: "What are we deciding?")
                board.items[i].w = Double(size.width)
                board.items[i].x = -board.items[i].w / 2
            }
            let columns: [(String, String, String, String, CGFloat)] = [
                ("Pros", "green", "A good thing", "green", -200), ("Cons", "red", "A bad thing", "pink", 200),
            ]
            for (name, colour, noteText, noteColour, x) in columns {
                let frame = board.add(.frame, centre: CGPoint(x: x, y: 0), text: name, colour: colour)
                board.resize(frame, to: CGRect(x: x - 180, y: -210, width: 360, height: 420))
                board.add(.note, centre: CGPoint(x: x, y: -90), text: noteText, colour: noteColour)
                board.add(.note, centre: CGPoint(x: x, y: 70), text: noteText, colour: noteColour)
            }
        case .steps:
            let gap = 70.0
            let w = Double(ItemKind.box.defaultSize.width)
            let total = w * 5 + gap * 4
            var previous: UUID?
            for n in 1...5 {
                let x = -total / 2 + Double(n - 1) * (w + gap) + w / 2
                let box = board.add(.box, centre: CGPoint(x: x, y: 0), text: "Step \(n)", colour: "blue")
                board.add(.note, centre: CGPoint(x: x, y: 28 + 30 + 55), text: "What it needs")
                if let previous { board.link(from: previous, to: box) }
                previous = box
            }
        }
        return board
    }
}

// 0.9 starters: a decision grid, and boards made of four frames (Weekly review, SWOT).
extension Board {
    /// Four frames in two rows of two, 360 x 250 with 20 between, each with a name, a colour and one note inside.
    mutating func framesStart(_ parts: [(String, String, String)]) {
        let w = 360.0, h = 250.0, gap = 20.0
        for (n, part) in parts.enumerated() {
            let col = Double(n % 2), row = Double(n / 2)
            let x = -w - gap / 2 + col * (w + gap), y = -h - gap / 2 + row * (h + gap)
            let frame = add(.frame, centre: CGPoint(x: x + w / 2, y: y + h / 2), text: part.0, colour: part.1)
            resize(frame, to: CGRect(x: x, y: y, width: w, height: h))
            add(.note, centre: CGPoint(x: x + w / 2, y: y + h / 2 + 15), text: part.2, colour: part.1 == "red" ? "pink" : part.1)
        }
    }

    /// One frame with three row lanes (the options, down) and three words above it (what matters, across);
    /// one note in every cell.
    mutating func decisionGridStart() {
        let left = -282.0, top = -210.0, width = 564.0, height = 420.0
        let frame = add(.frame, centre: CGPoint(x: left + width / 2, y: top + height / 2), text: "Which one?", colour: "blue")
        resize(frame, to: CGRect(x: left, y: top, width: width, height: height))
        if let i = index(of: frame) {
            var lanes = Lanes(way: .rows, count: 3)
            lanes.names = ["Option A", "Option B", "Option C"]
            items[i].lanes = lanes
        }
        let columns = ["Price", "Effort", "Fun"]
        let laneRoom = (height - Lanes.titleBand) / 3
        for (c, word) in columns.enumerated() {
            let cx = left + Lanes.header + 90 + Double(c) * 180
            let head = add(.text, centre: CGPoint(x: cx, y: top - 34), text: word)
            if let i = index(of: head) {
                let size = Board.roughSize(for: word)
                items[i].w = Double(size.width)
                items[i].x = cx - items[i].w / 2
            }
            for r in 0..<3 {
                let cy = top + Lanes.titleBand + laneRoom * (Double(r) + 0.5)
                let note = add(.note, centre: CGPoint(x: cx, y: cy), text: r == 0 ? "How it looks" : "", colour: Palette.notes[c % Palette.notes.count])
                if let i = index(of: note) { items[i].w = 150; items[i].h = 100; items[i].x = cx - 75; items[i].y = cy - 50 }
            }
        }
    }
}
