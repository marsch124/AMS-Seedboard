import SwiftUI
import SeedboardCore

// Tidy shapes (0.5, pick 30): a line that was plainly meant as a shape becomes the real thing.
// Draw a box, an oval or a diamond in one line and hold the tip still for a moment before lifting:
// the sketch becomes a real Box, Oval or Diamond of that size and place. A line drawn from one
// thing to another, held still at its end, becomes an arrow between them. The rules are in
// SeedboardCore (InkShape.swift); here is the switch, where it is kept, and the one step that
// swaps the sketch for the shape.
//
// It works for whatever draws — the Pencil, and a finger or the mouse while the Draw tool is on.
// Only a line that begins a NEW sketch is looked at. The line is kept first (one step) and swapped
// second (another step), so one Undo gives the raw line back.

/// The switch "Tidy shapes": kept on this device (not in iCloud, never in the board).
enum TidyShapes {
    private static let key = "ink.tidyShapes"

    /// On or off when a board opens. The launch word `-tidyShapes` turns it on for pictures and screen tests.
    static var stored: Bool {
        if LaunchOptions.arguments.contains("-tidyShapes") { return true }
        // Pictures and tests otherwise start as a new owner does.
        guard !LaunchOptions.sampleData else { return Finger.tidyShapesAtFirst }
        return UserDefaults.standard.object(forKey: key) as? Bool ?? Finger.tidyShapesAtFirst
    }

    static func keep(_ on: Bool) {
        if !LaunchOptions.sampleData { UserDefaults.standard.set(on, forKey: key) }
    }

    /// Seconds on a clock that never jumps: for "has the tip come to rest?" (`InkRest`).
    static var now: Double { ProcessInfo.processInfo.systemUptime }
}

extension BoardSession {
    /// A line was just kept as the sketch `drawing` (InkDesk.swift, `inkEnded`). When the switch is
    /// on, the line began a new sketch (`joined` false) and the tip rested at its end, the sketch
    /// becomes the shape or the arrow it was meant as — a step of its own for Undo.
    func tidyAfterStroke(_ drawing: UUID?, joined: Bool) {
        guard let drawing, !joined, ink.tidyShapes, !readOnly, !board.placesItself,
              ink.rest.rested(until: TidyShapes.now) else { return }
        change { _ = $0.tidyInk(drawing, reach: InkShape.reach / Double(scale)) }
    }
}

/// The switch in the Draw plate: full colour while on, as the chosen pen and thickness are.
struct InkTidySwitch: View {
    @ObservedObject var session: BoardSession
    @ObservedObject var desk: InkDesk

    var body: some View {
        Button {
            desk.tidyShapes.toggle()
            session.takeKeys()
        } label: {
            Text("Tidy shapes")
                .font(Txt.label)
                .foregroundStyle(desk.tidyShapes ? Color.white : Part.drawing.text)
                .padding(.horizontal, 9)
                .frame(height: Finger.shape.height)
                .background(desk.tidyShapes ? Part.drawing.fill : Part.drawing.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .pressRoom(4, 4)
        }
        .buttonStyle(PressStyle())
        .help("Draw a box, an oval or a diamond and hold still for a moment: it becomes a real shape. A line from one thing to another becomes an arrow.")
        .accessibilityLabel("Tidy shapes")
        .accessibilityValue(desk.tidyShapes ? "On" : "Off")
        .accessibilityAddTraits(desk.tidyShapes ? .isSelected : [])
        .accessibilityIdentifier("draw.tidy")
        #if DEBUG
        .onAppear { session.tidyDemoIfAsked() }
        #endif
    }
}

#if DEBUG
// For pictures and for seeing the whole chain run without a Pencil: the launch word `-tidyDemo`
// (with `-draw`, and `-tidyShapes` to have the switch on) draws six lines by itself, each through
// the very calls a hand's line goes through, resting half a second at its end: a wobbly
// rectangle, an oval, a diamond, a line from the first to the second, a triangle and a scribble.
// With the switch on the first three become a Box, an Oval and a Diamond, the fourth an arrow, and
// the last two stay sketches; with it off all six stay sketches. `-tidyDemo undo` draws only the
// rectangle and then takes one step back: the raw line is there again.
extension BoardSession {
    private static var tidyDemoUsed = false

    func tidyDemoIfAsked() {
        guard !BoardSession.tidyDemoUsed, LaunchOptions.arguments.contains("-tidyDemo"), !readOnly, !board.placesItself else { return }
        BoardSession.tidyDemoUsed = true
        // Below whatever is on the board, in board points.
        let x = Double(board.bounds?.minX ?? 0), y = Double(board.bounds?.maxY ?? 0) + 80
        func walk(_ corners: [(Double, Double)], wobble: Double) -> [CGPoint] {
            var out: [CGPoint] = []
            for i in 1..<corners.count {
                let a = corners[i - 1], b = corners[i]
                let parts = max(1, Int(hypot(b.0 - a.0, b.1 - a.1) / 3))
                for k in 0..<parts {
                    let t = Double(k) / Double(parts), n = Double(out.count)
                    out.append(CGPoint(x: x + a.0 + (b.0 - a.0) * t + sin(n * 0.37 + 1.3) * wobble,
                                       y: y + a.1 + (b.1 - a.1) * t + cos(n * 0.29 + 0.4) * wobble))
                }
            }
            if let last = corners.last { out.append(CGPoint(x: x + last.0, y: y + last.1)) }
            return out
        }
        let round: [(Double, Double)] = (0...48).map { i in
            let a = Double(i) / 48 * 2 * .pi
            return (335 + 75 * cos(a), 45 + 45 * sin(a))
        }
        let lines: [[CGPoint]] = [
            walk([(0, 0), (160, 4), (157, 92), (2, 88), (0, 6)], wobble: 2.5),
            walk(round, wobble: 2),
            walk([(595, 0), (670, 50), (595, 100), (520, 50), (590, 2)], wobble: 2.5),
            walk([(140, 45), (200, 38), (275, 45)], wobble: 1.5),
            walk([(80, 170), (160, 260), (0, 260), (80, 170)], wobble: 2),
            walk([(260, 170), (410, 190), (260, 210), (410, 230), (260, 250)], wobble: 2),
        ]
        // `-tidyDemo undo`: only the first line, then one Undo — the raw line must be back.
        let undoOnly = LaunchOptions.value(for: "-tidyDemo") == "undo"
        func draw(_ n: Int) {
            guard n < (undoOnly ? 1 : lines.count) else {
                if undoOnly { undo() }
                fit()
                return
            }
            let dots = lines[n].map { InkDot(location: toScreen($0), force: nil, time: TidyShapes.now, kind: .pointer) }
            inkBegan(dots[0])
            inkMoved(Array(dots.dropFirst()))
            // The tip rests, then lifts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.inkEnded(cancelled: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { draw(n + 1) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { draw(0) }
    }
}
#endif
