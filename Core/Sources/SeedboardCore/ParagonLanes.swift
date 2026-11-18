import Foundation

// How a frame with lanes is handed over to PARAGON: its things are listed lane by lane under the
// lane's name — "who does what" stays readable in the note.

extension ParagonExport {
    /// One frame with lanes: its heading and, per lane that holds something with words, the lane's name and its things.
    struct LaneList {
        var frame: String
        var lanes: [(name: String, things: [Item])]
    }

    /// Every frame with lanes, in board order; a lane with nothing to say is left out, and so is a frame with no such lane.
    static func laneLists(_ board: Board) -> [LaneList] {
        board.items.filter { $0.kind == .frame && $0.lanes != nil }.compactMap { frame in
            guard let lanes = frame.lanes else { return nil }
            var filled: [(name: String, things: [Item])] = []
            for (n, things) in board.thingsByLane(in: frame.id).enumerated() {
                let worded = things.filter { !oneLine($0.text).isEmpty }
                if !worded.isEmpty { filled.append((oneLine(lanes.name(n)), worded)) }
            }
            return filled.isEmpty ? nil : LaneList(frame: oneLine(frame.text), lanes: filled)
        }
    }

    /// For a note: per frame with lanes a `## Frame name` section ("Lanes" when the frame has no name)
    /// with a `### Lane name` list of its things under it.
    static func laneText(_ board: Board) -> String {
        var out = ""
        for list in laneLists(board) {
            out += "## \(list.frame.isEmpty ? "Lanes" : list.frame)\n\n"
            for lane in list.lanes {
                out += "### \(lane.name)\n\n"
                out += lane.things.map { "- \(oneLine($0.text))" }.joined(separator: "\n") + "\n\n"
            }
        }
        return out
    }

    /// For a project: per lane one group of tasks — `### Frame name: Lane name` (or `### Lane name`)
    /// with the lane's flow shapes as tasks — and the shapes used, so "Steps" does not list them again.
    static func laneTasks(_ board: Board) -> (groups: [[String]], used: Set<UUID>) {
        var groups: [[String]] = []
        var used = Set<UUID>()
        for list in laneLists(board) {
            for lane in list.lanes {
                let shapes = lane.things.filter { $0.kind.isShape }
                guard !shapes.isEmpty else { continue }
                groups.append(["### \(list.frame.isEmpty ? lane.name : "\(list.frame): \(lane.name)")"] + shapes.map { "- [ ] \(oneLine($0.text))" })
                used.formUnion(shapes.map(\.id))
            }
        }
        return (groups, used)
    }
}
