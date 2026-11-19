import Foundation

// Seedboard 0.16: milestones made before 0.15 are purple, and purple means PARAGON.
// One question turns them all orange at once. Rules only — no screen.

public enum OrangeMilestones {
    /// Asked once per device.
    public static let askedKey = "ask.orangeMilestones.v1"

    /// How many purple milestones there are, and on how many timelines (only boards that can be changed).
    public static func count(_ boards: [Board]) -> (milestones: Int, timelines: Int) {
        var milestones = 0, timelines = 0
        for board in boards where board.isTimeline && board.canBeChanged {
            let n = board.purpleMilestones
            if n > 0 { milestones += n; timelines += 1 }
        }
        return (milestones, timelines)
    }

    /// The words of the question, for example "5 milestones on 2 timelines are purple."
    public static func line(_ found: (milestones: Int, timelines: Int)) -> String {
        let m = found.milestones == 1 ? "1 milestone" : "\(found.milestones) milestones"
        let t = found.timelines == 1 ? "1 timeline" : "\(found.timelines) timelines"
        return "\(m) on \(t) \(found.milestones == 1 ? "is" : "are") purple. Purple means PARAGON in Seedboard, and new milestones are orange."
    }
}

public extension Board {
    /// Milestones drawn purple on this board.
    var purpleMilestones: Int { items.filter { $0.kind == .milestone && $0.colour == "purple" }.count }

    /// Every purple milestone becomes orange. Other colours stay.
    mutating func makeMilestonesOrange() {
        for i in items.indices where items[i].kind == .milestone && items[i].colour == "purple" {
            items[i].colour = TimelineColours.milestone
        }
    }
}
