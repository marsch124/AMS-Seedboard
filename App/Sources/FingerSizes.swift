import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Sizes for a finger: on iPhone and iPad every button has a press area of at least 44 × 44 points.
/// The press area grows more than the look, so the bars stay compact. The Mac keeps its sizes.
enum Finger {
    #if os(iOS)
    static let on = true
    static var phone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    #else
    static let on = false
    static let phone = false
    #endif

    /// Two quick presses on empty board show the whole board (true) or make a sticky note as on the
    /// Mac and in 0.1 (false). One switch, should the owner want the sticky note back.
    static let twoPressesFit = on

    /// A chip in the bar for what is chosen: its height, and the gap to the next chip and the next row.
    static let chipHeight: CGFloat = on ? 36 : 28
    static let chipGap: CGFloat = on ? 8 : 5
    /// A shape button in that bar.
    static let shape = on ? CGSize(width: 36, height: 36) : CGSize(width: 30, height: 28)
    /// Smaller, Bigger, Whole board.
    static let zoom = on ? CGSize(width: 36, height: 36) : CGSize(width: 28, height: 28)
    /// Undo and Redo at the bottom of the iPhone.
    static let undo = on ? CGSize(width: 36, height: 36) : CGSize(width: 30, height: 28)
    /// The gap between two small buttons that sit side by side.
    static let pairGap: CGFloat = on ? 8 : 2
    /// A colour dot, and the gap to the next one.
    static let dot: CGFloat = on ? 30 : 22
    static let dotGap: CGFloat = on ? 14 : 7
    /// The room kept free left and right of the tools for the Undo and the zoom buttons.
    static let side: CGFloat = on ? 176 : 150
}

extension View {
    /// iPhone and iPad: the press area reaches this much further than the look, across and down.
    /// Nothing moves and nothing looks different. The Mac: no change.
    @ViewBuilder
    func pressRoom(_ across: CGFloat, _ down: CGFloat) -> some View {
        #if os(iOS)
        self
            .padding(.horizontal, across)
            .padding(.vertical, down)
            .contentShape(Rectangle())
            .padding(.horizontal, -across)
            .padding(.vertical, -down)
        #else
        self
        #endif
    }
}
