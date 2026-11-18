import SwiftUI
import Combine
import SeedboardCore

// What the bar beside the chosen thing, the small controls, the press-and-hold menu and the
// clipboard tell each other about the board on screen (0.2, picks 7, 17, 18).

/// One desk for the board that is open (one board is open at a time, as with `MenuDesk`).
@MainActor
final class BarDesk: ObservableObject {
    static let shared = BarDesk()

    /// A drag is going on on the board (a thing, a size knob, the choosing box): the bar beside
    /// the chosen thing is out of the way until it ends.
    @Published var dragging = false
    /// The control under the pointer (the Mac): a plus-handle there grows and shows its plus.
    @Published var hot: Controls.Kind?
    /// The press-and-hold menu that is open (iPhone and iPad).
    @Published var menu: BoardMenu.Open?

    /// Where the pointer is over the bare board, in the board view's own points. nil: it is somewhere else.
    var pointer: CGPoint?
    /// The board view's top left corner in the window.
    var origin = CGPoint.zero
    /// The parts of the window where a bar lies over the board: a right-click there is not for the board.
    private var shields: [String: CGRect] = [:]

    func shield(_ name: String, _ frame: CGRect?) { shields[name] = frame }

    /// True when a bar covers the board at this point (in the board view's own points).
    func covered(_ p: CGPoint) -> Bool {
        let inWindow = CGPoint(x: p.x + origin.x, y: p.y + origin.y)
        return shields.values.contains { $0.contains(inWindow) }
    }

    // MARK: Pasting again

    /// The clipboard's stamp, the spot (board points) and how often the same clip was pasted there.
    private var lastPaste: (stamp: Int, spot: CGPoint, count: Int)?

    /// The things were copied from this spot: a paste right onto it is set off, so it can be seen.
    func copied(stamp: Int, from spot: CGPoint?) {
        lastPaste = spot.map { (stamp, $0, 0) }
    }

    /// Where a paste lands: at the spot the first time, 28 further right and down each time the
    /// same clip is pasted at (nearly) the same spot again.
    func pasteSpot(stamp: Int, at spot: CGPoint) -> CGPoint {
        var first = spot
        var count = 0
        if let last = lastPaste, last.stamp == stamp, hypot(last.spot.x - spot.x, last.spot.y - spot.y) < 20 {
            first = last.spot
            count = last.count + 1
        }
        lastPaste = (stamp, first, count)
        let step = Clip.step(again: count)
        return CGPoint(x: first.x + step.width, y: first.y + step.height)
    }
}

/// On a bar that lies over the board (tools, zoom, the bar of the chosen thing): the Mac's
/// right-click and pointer feedback leave that part of the board alone.
struct BoardShield: ViewModifier {
    let name: String

    init(_ name: String) { self.name = name }

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .background(GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.frame(in: .global), initial: true) { _, frame in BarDesk.shared.shield(name, frame) }
                    .onDisappear { BarDesk.shared.shield(name, nil) }
            })
        #else
        content
        #endif
    }
}
