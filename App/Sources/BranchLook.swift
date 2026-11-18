import SwiftUI
import SeedboardCore

// 0.5 (pick 8, the owner's pick B): a mind map's branches run thick to thin, and an idea's words sit ON its line —
// the branch runs on under the words as an underline, and the ideas under it start from the end of that underline.
// The rule is in Core (Looks.swift: `Route.branchLine`, `Route.branchWeight`); this is its drawing. One painter
// (CanvasDraw.swift) draws the live board, the small pictures, the shared picture and PARAGON's picture.

enum BranchLook {
    /// How thick the line TO an idea of this depth is: a main branch 3.4, the second level 2.4, deeper 1.8.
    static func weight(depth: Int) -> CGFloat { CGFloat(Route.branchWeight(depth: depth)) }

    /// The line from `parent` to `child` and on under the child's words. `parentDepth` 0 = the middle idea.
    static func path(from parent: CGRect, parentDepth: Int, to child: CGRect, side: Side) -> Path {
        let line = Route.branchLine(from: parent, parentDepth: parentDepth, to: child, side: side)
        var path = Path()
        path.move(to: line.start)
        let midX = (line.start.x + line.near.x) / 2
        path.addCurve(to: line.near, control1: CGPoint(x: midX, y: line.start.y), control2: CGPoint(x: midX, y: line.near.y))
        // …and runs on under the words.
        path.addLine(to: line.end)
        return path
    }
}
