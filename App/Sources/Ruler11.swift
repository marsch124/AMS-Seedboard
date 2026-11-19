import SwiftUI
import SeedboardCore

// 0.11 (pick 37): the ruler. A straight edge on the board while the Draw tool is on: drag the middle grip to move it,
// turn it with two fingers on the grip or by dragging the round handle at its end. Lines drawn along it come out
// straight (`Ruler.snapped`, applied in InkDesk.inkEnded). It is not part of the board: nothing is saved, and it goes
// when the Draw tool is left. The bar of the edge itself never takes a touch, so drawing right beside it works.

extension BoardSession {
    /// The Ruler button: place it in the middle of what is shown, or take it away.
    func toggleRuler() {
        if ink.ruler != nil {
            ink.ruler = nil
        } else {
            let size = viewSize
            let middle = toBoard(CGPoint(x: size.width / 2, y: size.height / 2))
            ink.ruler = Ruler(centre: middle, angle: 0, length: Ruler.defaultLength / Double(max(scale, 0.01)))
        }
    }
}

struct RulerLayer: View {
    @ObservedObject var session: BoardSession
    @ObservedObject var desk: InkDesk
    let paint: Paint

    @State private var movedFrom: CGPoint?
    @State private var turnedFrom: Double?

    var body: some View {
        if desk.on, let ruler = desk.ruler {
            let scale = session.scale, offset = session.offset
            let screen = { (p: CGPoint) in CGPoint(x: p.x * scale + offset.width, y: p.y * scale + offset.height) }
            let a = screen(ruler.start), b = screen(ruler.end), mid = screen(ruler.centre)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    var edge = Path()
                    edge.move(to: a)
                    edge.addLine(to: b)
                    ctx.stroke(edge, with: .color(Part.drawing.fill.opacity(0.22)), style: StrokeStyle(lineWidth: 26, lineCap: .round))
                    ctx.stroke(edge, with: .color(Part.drawing.fill), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    // Little marks along the edge, every 24 points.
                    let long = hypot(b.x - a.x, b.y - a.y)
                    if long > 1 {
                        let d = CGPoint(x: (b.x - a.x) / long, y: (b.y - a.y) / long)
                        var ticks = Path()
                        var at = 24.0
                        while at < Double(long) {
                            let p = CGPoint(x: a.x + d.x * CGFloat(at), y: a.y + d.y * CGFloat(at))
                            ticks.move(to: p)
                            ticks.addLine(to: CGPoint(x: p.x - d.y * 6, y: p.y + d.x * 6))
                            at += 24
                        }
                        ctx.stroke(ticks, with: .color(Part.drawing.fill.opacity(0.7)), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                grip(at: mid, id: "ruler.move")
                    .gesture(moving(ruler).simultaneously(with: turning(ruler)))
                grip(at: b, id: "ruler.turn")
                    .gesture(handleTurn(ruler))
            }
            .coordinateSpace(name: RulerSpace.name)
        }
    }

    private func grip(at p: CGPoint, id: String) -> some View {
        Circle()
            .fill(Part.drawing.fill)
            .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
            .frame(width: 22, height: 22)
            .background(Color.white.opacity(0.001).frame(width: 44, height: 44))
            .contentShape(Circle().inset(by: -11))
            .offset(x: p.x - 11, y: p.y - 11)
            .accessibilityLabel(id == "ruler.move" ? "Move the ruler" : "Turn the ruler")
            .accessibilityIdentifier(id)
    }

    /// Dragging the middle grip moves the ruler.
    private func moving(_ ruler: Ruler) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if movedFrom == nil { movedFrom = ruler.centre }
                guard let from = movedFrom else { return }
                let s = max(session.scale, 0.01)
                desk.ruler?.centre = CGPoint(x: from.x + value.translation.width / s, y: from.y + value.translation.height / s)
            }
            .onEnded { _ in movedFrom = nil }
    }

    /// Two fingers turning on the middle grip.
    private func turning(_ ruler: Ruler) -> some Gesture {
        RotationGesture()
            .onChanged { angle in
                if turnedFrom == nil { turnedFrom = ruler.angle }
                if let from = turnedFrom { desk.ruler?.angle = from + angle.radians }
            }
            .onEnded { _ in turnedFrom = nil }
    }

    /// Dragging the round handle at the end swings the ruler round its middle.
    private func handleTurn(_ ruler: Ruler) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(RulerSpace.name))
            .onChanged { value in
                let mid = session.toScreen(ruler.centre)
                let angle = atan2(Double(value.location.y - mid.y), Double(value.location.x - mid.x))
                if angle.isFinite { desk.ruler?.angle = angle }
            }
    }
}

enum RulerSpace { static let name = "rulerSpace" }
