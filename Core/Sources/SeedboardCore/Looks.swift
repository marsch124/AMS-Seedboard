import Foundation
import CoreGraphics

// 0.5, the owner's picks for the look: where a mind map's branch runs (thick to thin, the words on the line),
// and the order of the starters in the home page's strip.

public extension Route {
    /// How thick the line TO an idea of this depth is: a main branch 3.4, the second level 2.4, deeper 1.8.
    static func branchWeight(depth: Int) -> Double {
        depth <= 1 ? 3.4 : (depth == 2 ? 2.4 : 1.8)
    }

    /// The height an idea's underline runs at: 2 points above the bottom of its box, under its words.
    static func branchFoot(of idea: CGRect) -> CGFloat { idea.maxY - 2 }

    /// A mind-map branch with the words on the line: it leaves the middle idea (`parentDepth` 0, a box) at the
    /// middle of its side, and any other idea at the far end of that idea's underline; it arrives at the near
    /// end of the child's foot (`near`) and runs on under the child's words to their far end (`end`).
    static func branchLine(from parent: CGRect, parentDepth: Int, to child: CGRect, side: Side)
        -> (start: CGPoint, near: CGPoint, end: CGPoint) {
        let right = side == .right
        let start = CGPoint(x: right ? parent.maxX : parent.minX,
                            y: parentDepth == 0 ? parent.midY : branchFoot(of: parent))
        let foot = branchFoot(of: child)
        return (start,
                CGPoint(x: right ? child.minX : child.maxX, y: foot),
                CGPoint(x: right ? child.maxX : child.minX, y: foot))
    }
}

public extension StarterShelf {
    /// The starters in the home page's strip: the Blank board always first — on an iPad held upright the list
    /// (and its New board button) can be hidden, so the strip's first card is the sure way to a new board — then
    /// the others in the owner's own order. The chooser and the Starters page keep his order untouched (`shown`).
    var strip: [ShelfStarter] {
        let all = shown
        return all.filter { $0.builtin == .blank } + all.filter { $0.builtin != .blank }
    }
}
