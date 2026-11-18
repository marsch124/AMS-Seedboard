import Foundation
import CoreGraphics

// 0.9, the `paragon` lane: three small rules of the hand-over to PARAGON.
//  - 40: send only the things inside one frame (`Board.frameOnly`);
//  - 41: how a task's due day, as PARAGON has it now, is shown on its to-do box (`DueLook`);
//  - 42: "Today's three": up to three things go to the Inbox as tasks due today (`ParagonExport.todayThree`).
// Seedboard still only ADDS: nothing here opens or changes anything in PARAGON's folder.

public extension Board {
    /// The things whose middle lies inside the frame (the frame itself is not one of them), in board order.
    func thingsInside(frame id: UUID) -> [Item] {
        guard let frame = item(id), frame.kind == .frame else { return [] }
        return items.filter { $0.id != id && frame.frame.contains($0.centre) }
    }

    /// A thing's words as one line (what its task says); empty when it has none.
    func thingWords(_ id: UUID) -> String { ParagonExport.oneLine(item(id)?.text ?? "") }

    /// The frame's words as one line; empty when it has none.
    func frameName(_ id: UUID) -> String { ParagonExport.oneLine(item(id)?.text ?? "") }

    /// A board that holds just what lies inside one frame, for sending that frame alone. It keeps the board's
    /// identity and the list of ticks already sent; it carries no "sent" mark. The name is the frame's words.
    /// `keepFrame`: the frame itself stays (for the picture, which shows the frame). A frame with lanes stays
    /// anyway: its lanes are what the note is made from. An idea whose parent lies outside becomes a middle.
    /// nil: not a frame, or nothing lies inside it.
    func frameOnly(_ id: UUID, keepFrame: Bool = false) -> Board? {
        guard let frame = item(id), frame.kind == .frame else { return nil }
        let inside = thingsInside(frame: id)
        guard !inside.isEmpty else { return nil }
        var keep = Set(inside.map(\.id))
        if keepFrame || frame.lanes != nil { keep.insert(id) }
        var part = self
        let name = frameName(id)
        if !name.isEmpty { part.title = name }
        part.sent = nil
        if sent != nil {
            for tick in sentTodos where keep.contains(tick) && sentTask(tick) == nil {
                part.sentTasks.append(SentTask(id: tick, words: "", place: SentTask.note))
            }
        }
        part.items = items.filter { keep.contains($0.id) }
        part.links = links.filter { keep.contains($0.from) && keep.contains($0.to) }
        for i in part.items.indices {
            guard let parent = part.items[i].parent, !keep.contains(parent) else { continue }
            let colour = branchColour(of: part.items[i].id)
            part.items[i].parent = nil
            part.items[i].side = nil
            if part.items[i].colour.isEmpty { part.items[i].colour = colour }
        }
        return part
    }
}

// MARK: 41 — the due day on a to-do box

/// What stands beside a to-do box that PARAGON has a due day for.
public struct DueLook: Equatable, Sendable {
    public enum Tone: Equatable, Sendable {
        /// Due later: ordinary small words.
        case later
        /// Due today.
        case today
        /// Past due and not done: faint red.
        case late
    }
    public var words: String
    public var tone: Tone

    /// "5 Dec", or "Today"; `late` when the day has passed and the task is not done. A done or cancelled task
    /// keeps its day in ordinary words. nil: no day, or one that is no day ("2026-13-45").
    public static func of(_ iso: String?, state: TodoState?, today: Day) -> DueLook? {
        guard let iso, let day = Day(iso: iso), iso.count >= 10 else { return nil }
        if day == today { return DueLook(words: "Today", tone: state == .done || state == .cancelled ? .later : .today) }
        let finished = state == .done || state == .cancelled
        return DueLook(words: day.short, tone: day < today && !finished ? .late : .later)
    }
}

// MARK: 42 — Today's three

public extension ParagonExport {
    /// The most things "Today's three" takes.
    static let todayMost = 3

    /// What "Today's three" sends: one Inbox task per chosen thing that is not in PARAGON yet, in board order,
    /// each with the day today as PARAGON writes it (` >2026-11-18`) and, when `way` is given, its way back.
    /// nil: more than three are chosen, or none of them can become a task.
    static func todayThree(board: Board, chosen: Set<UUID>, now: Date, way: WayBack? = nil,
                           calendar: Calendar = .current) -> LinesToSend? {
        guard !chosen.isEmpty, chosen.count <= todayMost, !board.placesItself else { return nil }
        let day = Day.today(now, calendar: calendar).iso
        let inPara = Set(board.sentTodos).union(board.sentTasks.map(\.id))
        var out = LinesToSend(lines: [], tasks: [], place: SentTask.inbox, notePath: nil)
        for item in board.items where chosen.contains(item.id) && !inPara.contains(item.id) {
            switch item.kind {
            case .idea, .box, .round, .diamond, .oval, .note, .text, .person, .document, .slanted, .store: break
            default: continue
            }
            let words = oneLine(item.text)
            guard !words.isEmpty else { continue }
            let line = Self.words("\(words) >\(day)", with: way)
            out.lines.append(line)
            out.tasks.append(MadeTask(id: item.id, words: line))
        }
        return out.tasks.isEmpty ? nil : out
    }
}
