import Foundation
import CoreGraphics
import SeedboardCore

// A made-up board with drawings on it, for pictures and tests: `-sampleData -board Sketch`.
// The lines are made in code, with a small wobble, so they look drawn by hand — and they are the
// same on every run (the wobble comes from a fixed row of numbers, not from chance).

extension Sample {
    /// A hand that is never quite steady: the same row of numbers every time.
    private struct Hand {
        private var state: UInt64 = 0x5EED_B0A2_D000_0002

        /// A number between -1 and 1.
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) % 20_001) / 10_000 - 1
        }

        /// A line through the corner points as a hand would draw it: a point every 3 points of way,
        /// swaying slowly to either side by up to `sway`, with a little tremble on top.
        mutating func line(_ corners: [CGPoint], sway: Double = 1.2) -> [CGPoint] {
            var out: [CGPoint] = []
            let phase = next() * 3, phase2 = next() * 3
            var travelled = 0.0
            for (a, b) in zip(corners, corners.dropFirst()) {
                let length = Double(hypot(b.x - a.x, b.y - a.y))
                guard length > 0 else { continue }
                let across = CGPoint(x: -(b.y - a.y) / length, y: (b.x - a.x) / length)
                let steps = max(1, Int(length / 3))
                for k in 0...steps {
                    let t = Double(k) / Double(steps)
                    let way = travelled + length * t
                    let off = sway * (0.7 * sin(way / 23 + phase) + 0.3 * sin(way / 7 + phase2)) + 0.25 * next()
                    out.append(CGPoint(x: a.x + (b.x - a.x) * t + across.x * off, y: a.y + (b.y - a.y) * t + across.y * off))
                }
                travelled += length
            }
            return out
        }

        /// Part of an oval, in degrees (0 = right, 90 = down), a little uneven as a hand's is.
        mutating func arc(centre: CGPoint, radii: CGSize, from: Double, to: Double, sway: Double = 1.4) -> [CGPoint] {
            let steps = max(8, Int(abs(to - from) / 6))
            let phase = next() * 3
            return (0...steps).map { k in
                let angle = (from + (to - from) * Double(k) / Double(steps)) * .pi / 180
                let grow = 1 + sway * sin(angle * 2 + phase) / Double(max(radii.width, radii.height)) + 0.004 * next()
                return CGPoint(x: Double(centre.x) + cos(angle) * Double(radii.width) * grow,
                               y: Double(centre.y) + sin(angle) * Double(radii.height) * grow)
            }
        }

        /// How hard a Pencil presses along a line: it lands lightly, leans in, and lifts lightly.
        mutating func pressure(_ count: Int, firm: Double = 0.34) -> [Double] {
            (0..<count).map { i in
                let t = Double(i) / Double(max(count - 1, 1))
                let lean = min(1, t / 0.15) * min(1, (1 - t) / 0.2 + 0.25)
                return min(max(firm * lean + 0.04 * next() + 0.05 * sin(t * 9), 0.02), 1)
            }
        }
    }

    /// "Sketch ideas": a rough floor plan, a circled word with an arrow, a tick — three drawings in
    /// different colours and thicknesses, beside two notes and a few words.
    static func sketch(now: Date = Date()) -> Board {
        var board = Board(title: "Sketch ideas", created: now.addingTimeInterval(-86_400 * 2), colour: "purple")
        var hand = Hand()
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

        /// One stroke, thinned as the app thins a drawn line. `pencil`: with pressure, as the Pencil gives it.
        @discardableResult
        func stroke(_ raw: [CGPoint], _ colour: String, _ width: InkWidth, into drawing: UUID?, pencil: Bool = false, firm: Double = 0.34) -> UUID? {
            let line = Ink.thin(raw, pressure: pencil ? hand.pressure(raw.count, firm: firm) : nil, tolerance: Ink.tolerance(scale: 1))
            return board.addStroke(line.points, pressure: line.pressure, colour: colour, width: width, to: drawing)
        }

        board.add(.note, centre: p(-120, 60), text: "Cabin, first idea\n6 × 8 m, one floor", colour: "yellow")

        // A rough floor plan: the outer walls in one go (thick, plain ink; the last corner does not
        // quite meet the first), two inner walls, a door that swings in, a window.
        let plan = stroke(hand.line([p(2, 3), p(300, 0), p(303, 198), p(-2, 201), p(1, -2)]), "", .thick, into: nil)
        stroke(hand.line([p(182, 2), p(180, 122)]), "", .medium, into: plan)
        stroke(hand.line([p(179, 121), p(301, 119)]), "", .medium, into: plan)
        stroke(hand.arc(centre: p(96, 199), radii: CGSize(width: 38, height: 38), from: 270, to: 358), "blue", .thin, into: plan, pencil: true)
        stroke(hand.line([p(96, 200), p(97, 162)], sway: 0.5), "blue", .thin, into: plan, pencil: true)
        stroke(hand.line([p(40, -6), p(92, -7)], sway: 0.5), "teal", .medium, into: plan)
        stroke(hand.line([p(41, 6), p(91, 7)], sway: 0.5), "teal", .medium, into: plan)
        // (Free text keeps its left edge when it takes the size of its words: 60 left of the middle given here.)
        board.add(.text, centre: p(122, 96), text: "Living")
        board.add(.text, centre: p(282, 60), text: "Bed")
        board.add(.text, centre: p(280, 160), text: "Bath")

        // A word with a ring round it (the ring goes a little past where it began) and an arrow to the plan.
        board.add(.text, centre: p(494, 58), text: "Lake side")
        let ring = stroke(hand.arc(centre: p(470, 58), radii: CGSize(width: 66, height: 27), from: -150, to: 228), "red", .medium, into: nil, pencil: true)
        stroke(hand.line([p(404, 76), p(360, 92), p(318, 100)], sway: 1.6), "orange", .medium, into: ring, pencil: true)
        stroke(hand.line([p(333, 88), p(317, 100), p(334, 109)], sway: 0.4), "orange", .medium, into: ring, pencil: true)

        // A tick beside a note: a quick, firm stroke.
        stroke(hand.line([p(408, 186), p(425, 207), p(463, 158)], sway: 0.6), "green", .thick, into: nil, pencil: true, firm: 0.5)
        board.add(.note, centre: p(560, 190), text: "Permit is in", colour: "green")

        board.changed = now.addingTimeInterval(-7_200)
        return board
    }
}
