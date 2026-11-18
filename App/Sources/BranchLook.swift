import SwiftUI
import SeedboardCore

// 0.5 (pick 8), PICTURES FIRST: how a mind map's branches are drawn. Until the owner has picked, the two new
// looks are behind the launch word `-branches A` / `-branches B`; without it every branch is as in 0.4.

enum BranchLook: Equatable {
    /// 0.4: every branch line 2.6 points, the words beside the end of the line.
    case today
    /// A: thick to thin — main branch 3.4, second level 2.4, third and deeper 1.8.
    case weights
    /// B: A, and the line runs on under the idea's words; the ideas under it start from the end of that underline.
    case onLine

    static let current: BranchLook = {
        switch LaunchOptions.value(for: "-branches")?.uppercased() {
        case "A": return .weights
        case "B": return .onLine
        default: return .today
        }
    }()

    /// How thick the line TO an idea of this depth is (1 = a main branch).
    func weight(depth: Int) -> CGFloat {
        switch self {
        case .today: return 2.6
        case .weights, .onLine: return depth <= 1 ? 3.4 : (depth == 2 ? 2.4 : 1.8)
        }
    }

    /// How far under the middle of an idea its underline runs (look B): 2 points under its words.
    static func foot(of idea: CGRect) -> CGFloat { idea.maxY - 2 }

    /// The line from `parent` to `child`. `parentDepth` 0 = the middle idea (a box: the line leaves its side).
    func path(from parent: CGRect, parentDepth: Int, to child: CGRect, side: Side) -> Path {
        var path = Path()
        guard self == .onLine else {
            let ends = Route.branch(from: parent, to: child, side: side)
            path.move(to: ends.start)
            let midX = (ends.start.x + ends.end.x) / 2
            path.addCurve(to: ends.end, control1: CGPoint(x: midX, y: ends.start.y), control2: CGPoint(x: midX, y: ends.end.y))
            return path
        }
        let right = side == .right
        // It leaves the middle idea at the middle of its side, and any other idea at the end of its underline.
        let start = CGPoint(x: right ? parent.maxX : parent.minX,
                            y: parentDepth == 0 ? parent.midY : BranchLook.foot(of: parent))
        let foot = BranchLook.foot(of: child)
        let near = CGPoint(x: right ? child.minX : child.maxX, y: foot)
        let far = CGPoint(x: right ? child.maxX : child.minX, y: foot)
        path.move(to: start)
        let midX = (start.x + near.x) / 2
        path.addCurve(to: near, control1: CGPoint(x: midX, y: start.y), control2: CGPoint(x: midX, y: near.y))
        // …and runs on under the words.
        path.addLine(to: far)
        return path
    }
}
