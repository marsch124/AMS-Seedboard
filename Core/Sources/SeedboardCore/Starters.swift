import Foundation
import CoreGraphics

/// The ways a new board can begin.
public enum Starter: String, CaseIterable, Identifiable, Sendable {
    case blank, mindMap, flow, prosCons, steps
    case timeline

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .blank: return "Blank board"
        case .mindMap: return "Mind map"
        case .flow: return "Flow"
        case .prosCons: return "Pros and cons"
        case .steps: return "Plan in steps"
        case .timeline: return "Timeline"
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
        }
    }

    /// A new board with this start on it, centred round (0,0).
    public func board(title: String? = nil, now: Date = Date()) -> Board {
        var board = Board(title: title ?? (self == .blank ? "New board" : name), created: now)
        if self == .timeline { return Board.timelineStart(title: board.title, now: now) }
        switch self {
        case .blank:
            break
        case .timeline:
            break
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
                ids.append(board.add(kind, centre: mid, text: text))
                if kind == .diamond { diamondMid = mid }
                left += w + gap
            }
            let again = Double(ItemKind.box.defaultSize.height)
            let low = board.add(.box, centre: CGPoint(x: diamondMid.x,
                                                      y: diamondMid.y + Double(ItemKind.diamond.defaultSize.height) / 2 + gap + again / 2),
                                text: "Think again")
            board.link(from: ids[0], to: ids[1])
            board.link(from: ids[1], to: ids[2])
            board.link(from: ids[2], to: ids[3], text: "Yes")
            board.link(from: ids[2], to: low, text: "No")
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
                let box = board.add(.box, centre: CGPoint(x: x, y: 0), text: "Step \(n)")
                board.add(.note, centre: CGPoint(x: x, y: 28 + 30 + 55), text: "What it needs")
                if let previous { board.link(from: previous, to: box) }
                previous = box
            }
        }
        return board
    }
}
