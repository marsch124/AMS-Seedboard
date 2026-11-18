import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#endif

// Lanes in frames (0.2, pick 16). The rules are in SeedboardCore (`Lanes.swift`). Here: "Lanes" in
// the bar of a chosen frame with its plate, how the lanes are drawn, the soft light on the frame or
// lane a thing is dragged over, the lines between lanes that can be dragged, and a lane's name
// typed in place.

/// The name of one lane while it is typed. It goes onto the board when the typing ends.
struct LaneTyping: Equatable {
    let frame: UUID
    let lane: Int
    var draft: String
}

/// What the painter shows on frames beyond the board itself.
struct FrameShow: Equatable {
    /// The frames and lanes a dragged thing is over: they light up softly.
    var lit: [FrameSpot] = []
    /// The lane whose name is being typed: the field shows it, the board does not.
    var typing: FrameSpot?
}

extension SnapShow {
    /// For pictures: `-lit` lights the frame or lane of the chosen things, as if they were being dragged.
    private static let litForPictures = LaunchOptions.arguments.contains("-lit")

    @MainActor
    func frames(for session: BoardSession) -> FrameShow {
        var show = FrameShow(lit: over, typing: session.laneTyping.map { FrameSpot(frame: $0.frame, lane: $0.lane) })
        if SnapShow.litForPictures, over.isEmpty { show.lit = session.board.spots(ofDragged: session.selection) }
        return show
    }
}

// MARK: The session's side

extension BoardSession {
    /// Lanes for the chosen frame: none (`way` nil), or 2 to 5 rows or columns. One step for Undo.
    func setLanes(_ way: Lanes.Way?, count: Int = 3) {
        guard let item = single, item.kind == .frame else { return }
        if editing != nil { commitEdit() }
        laneTyping = nil
        change { $0.setLanes(item.id, way: way, count: count) }
    }

    /// Two presses on a lane's name band: its name is typed in place. False when the point is on no name band.
    @discardableResult
    func beginLaneName(of id: UUID, at point: CGPoint) -> Bool {
        guard !readOnly, let item = board.item(id), let lane = item.laneName(at: point) else { return false }
        return beginLaneName(of: id, lane: lane)
    }

    @discardableResult
    func beginLaneName(of id: UUID, lane: Int) -> Bool {
        guard !readOnly, let lanes = board.item(id)?.lanes, lanes.names.indices.contains(lane) else { return false }
        if editing != nil { commitEdit() }
        if laneTyping != nil { commitLaneName() }
        selection = [id]
        selectedLink = nil
        laneTyping = LaneTyping(frame: id, lane: lane, draft: lanes.names[lane])
        return true
    }

    /// The typing ends: the name goes onto the board as one step for Undo. `next` goes on with the next lane's name.
    func commitLaneName(next: Bool = false) {
        guard let typed = laneTyping else { return }
        laneTyping = nil
        change { $0.setLaneName(typed.frame, lane: typed.lane, to: typed.draft) }
        if next, !beginLaneName(of: typed.frame, lane: typed.lane + 1) { takeKeys() }
    }

    /// Escape: the name stays what it was.
    func cancelLaneName() {
        laneTyping = nil
        takeKeys()
    }

    /// The line after a lane of the chosen frame follows the drag (between `liveStart` and `liveEnd`).
    func liveLaneLine(_ id: UUID, line: Int, to place: CGFloat) {
        live { $0.moveLaneLine(id, line: line, to: place) }
    }
}

// MARK: Drawing

extension BoardPainter {
    /// A frame's lanes — their name bands, the lines between them, their names — and the soft light
    /// on a frame or lane that a dragged thing is over. Drawn on the frame, under everything in it.
    func drawLanes(_ item: Item, _ ctx: inout GraphicsContext) {
        let lit = frames.lit.filter { $0.frame == item.id }
        guard item.lanes != nil || !lit.isEmpty else { return }
        let f = item.frame
        let colour = paint.line(item.colour.isEmpty ? "teal" : item.colour)
        let box = Path(roundedRect: f, cornerRadius: 14)
        var inside = ctx
        inside.clip(to: box)

        if let lanes = item.lanes {
            let rects = lanes.rects(in: f), headers = lanes.headers(in: f)
            for header in headers {
                inside.fill(Path(header), with: .color(colour.opacity(paint.night ? 0.20 : 0.13)))
            }
            for spot in lit {
                if let lane = spot.lane, rects.indices.contains(lane) {
                    inside.fill(Path(rects[lane]), with: .color(colour.opacity(paint.night ? 0.24 : 0.17)))
                }
            }
            let room = Lanes.room(in: f)
            var lines = Path()
            lines.move(to: CGPoint(x: f.minX, y: room.minY)); lines.addLine(to: CGPoint(x: f.maxX, y: room.minY))
            for i in 0..<(lanes.count - 1) {
                guard let line = lanes.line(i, in: f) else { continue }
                lines.move(to: line.from); lines.addLine(to: line.to)
            }
            switch lanes.way {
            case .rows:
                lines.move(to: CGPoint(x: f.minX + Lanes.header, y: room.minY)); lines.addLine(to: CGPoint(x: f.minX + Lanes.header, y: f.maxY))
            case .columns:
                lines.move(to: CGPoint(x: f.minX, y: room.minY + Lanes.header)); lines.addLine(to: CGPoint(x: f.maxX, y: room.minY + Lanes.header))
            }
            inside.stroke(lines, with: .color(colour.opacity(0.6)), lineWidth: 1.1)

            for (i, header) in headers.enumerated() where frames.typing != FrameSpot(frame: item.id, lane: i) {
                let named = lanes.names.indices.contains(i) && !lanes.names[i].isEmpty
                // An empty lane says "Lane 2" faintly on the live board only, never in a picture.
                guard named || handles else { continue }
                let long = (lanes.way == .rows ? header.height : header.width) - 10
                let text = laneLabel(lanes.name(i), colour: named ? colour : paint.faint, room: long, inside)
                var layer = inside
                layer.clip(to: Path(header))
                if lanes.way == .rows {
                    // The name of a row stands upright in its band, reading from the bottom up.
                    layer.translateBy(x: header.midX, y: header.midY)
                    layer.rotate(by: .degrees(-90))
                    layer.draw(text, at: .zero, anchor: .center)
                } else {
                    layer.draw(text, at: CGPoint(x: header.midX, y: header.midY), anchor: .center)
                }
            }
        } else {
            inside.fill(box, with: .color(colour.opacity(paint.night ? 0.20 : 0.14)))
        }

        if !lit.isEmpty { ctx.stroke(box, with: .color(colour), lineWidth: 2.6) }
    }

    /// A lane's name on one line; one that is too long for its band ends in "…".
    private func laneLabel(_ words: String, colour: Color, room: CGFloat, _ ctx: GraphicsContext) -> GraphicsContext.ResolvedText {
        func made(_ shown: String) -> GraphicsContext.ResolvedText {
            ctx.resolve(Text(shown).font(Lettering.font(size: 12, bold: true)).foregroundColor(colour))
        }
        var shown = words
        var text = made(shown)
        while shown.count > 1, text.measure(in: CGSize(width: 4000, height: 100)).width > room {
            shown = String(shown.dropLast(shown.hasSuffix("…") ? 2 : 1)) + "…"
            text = made(shown)
        }
        return text
    }
}

// MARK: The bar and the plate

/// "Lanes" in the bar of a chosen frame: opens the plate with none, or 2 to 5 rows or columns.
struct LanesChip: View {
    @ObservedObject var session: BoardSession
    let item: Item
    /// For pictures: `-plate lanes` (with `-pick`) opens the plate at once.
    @State private var shown = LaunchOptions.value(for: "-plate") == "lanes"

    var body: some View {
        Button { shown = true } label: {
            BarChip(word: "Lanes", glyph: .new(.lanes), part: .frames, on: shown || item.lanes != nil)
        }
        .buttonStyle(PressStyle(tint: Part.frames.text))
        .help("Split the frame into named lanes")
        .accessibilityIdentifier("sel.lanes")
        .modifier(PlatePresenter(shown: $shown, edge: .bottom, height: 250, closed: { session.takeKeys() }) {
            LanesPlate(lanes: item.lanes, pick: { way, count in
                session.setLanes(way, count: count)
                shown = false
            }, cancel: { shown = false })
        })
    }
}

/// No lanes, or 2 to 5 of them as rows or as columns. What the frame has now is in full colour.
struct LanesPlate: View {
    let lanes: Lanes?
    let pick: (Lanes.Way?, Int) -> Void
    let cancel: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlateHeading(title: "Lanes", glyph: .new(.lanes), part: .frames, cancel: cancel)
            choice("No lanes", on: lanes == nil, id: "lanes.none") { pick(nil, 0) }
            ForEach(Lanes.Way.allCases, id: \.self) { way in
                HStack(spacing: 6) {
                    Text(way.word)
                        .font(Txt.label)
                        .frame(width: 68, alignment: .leading)
                    ForEach(Lanes.fewest...Lanes.most, id: \.self) { n in
                        choice("\(n)", on: lanes?.way == way && lanes?.count == n, id: "lanes.\(way.rawValue).\(n)", label: "\(n) \(way.word.lowercased())") {
                            pick(way, n)
                        }
                    }
                }
            }
            Text("Press a lane's name twice to type it. Drag the line between two lanes to move it.")
                .font(Txt.note)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: plateWidth)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plate.lanes")
    }

    private var plateWidth: CGFloat? {
        #if os(macOS)
        return 300
        #else
        return sizeClass == .compact ? nil : 300
        #endif
    }

    private func choice(_ word: String, on: Bool, id: String, label: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(word)
                .font(Txt.bigPill)
                .foregroundStyle(on ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .frame(minWidth: 44)
                .frame(height: 32)
                .background(on ? Part.frames.fill : Part.frames.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(tint: Part.frames.text))
        .accessibilityLabel(label ?? word)
        .accessibilityIdentifier(id)
    }
}

// MARK: On the board: the lines that can be dragged, and a name typed in place

/// Lies over the board. For a chosen frame with lanes it puts a grip on every line between two
/// lanes (drag it to move the line); while a lane's name is typed it shows the field.
struct LaneOverlay: View {
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @FocusState private var typing: Bool
    /// The line being dragged, and where it stood on the board when the drag began.
    @State private var grabbed: (line: Int, start: CGFloat)?

    private var paint: Paint { Paint(scheme) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !session.readOnly, session.editing == nil, session.laneTyping == nil,
               let frame = session.single, frame.kind == .frame, let lanes = frame.lanes {
                ForEach(0..<(lanes.count - 1), id: \.self) { line in
                    grip(frame, lanes, line)
                }
            }
            if let typed = session.laneTyping, let frame = session.board.item(typed.frame), let lanes = frame.lanes,
               lanes.names.indices.contains(typed.lane) {
                nameField(frame, lanes, typed)
            }
        }
        .onChange(of: session.selection) { _, chosen in
            // Something else was chosen: the typing ends and the name is kept.
            if let typed = session.laneTyping, chosen != [typed.frame] { session.commitLaneName() }
        }
    }

    // MARK: The lines

    private func grip(_ frame: Item, _ lanes: Lanes, _ line: Int) -> some View {
        let ends = lanes.line(line, in: frame.frame) ?? (frame.frame.origin, frame.frame.origin)
        let a = session.toScreen(ends.from), b = session.toScreen(ends.to)
        let rows = lanes.way == .rows
        let colour = paint.line(frame.colour.isEmpty ? "teal" : frame.colour)
        return Capsule()
            .fill(colour)
            .frame(width: rows ? 34 : 5, height: rows ? 5 : 34)
            .overlay(Capsule().stroke(paint.plate, lineWidth: 1))
            // The whole line takes the drag, 7 points to each side of it.
            .frame(width: rows ? max(b.x - a.x, 14) : 14, height: rows ? 14 : max(b.y - a.y, 14))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if grabbed?.line != line {
                            grabbed = (line, rows ? ends.from.y : ends.from.x)
                            session.liveStart()
                        }
                        guard let start = grabbed?.start else { return }
                        let way = (rows ? value.translation.height : value.translation.width) / max(session.scale, 0.01)
                        session.liveLaneLine(frame.id, line: line, to: start + way)
                    }
                    .onEnded { _ in
                        grabbed = nil
                        session.liveEnd(keep: true)
                        session.takeKeys()
                    }
            )
            #if os(macOS)
            .onHover { inside in
                if inside { (rows ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).push() } else { NSCursor.pop() }
            }
            #endif
            .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            .accessibilityLabel("Line between lane \(line + 1) and lane \(line + 2)")
            .accessibilityIdentifier("lanes.line.\(line)")
    }

    // MARK: A name typed in place

    private func nameField(_ frame: Item, _ lanes: Lanes, _ typed: LaneTyping) -> some View {
        let headers = lanes.headers(in: frame.frame)
        let band = session.toScreen(headers[typed.lane])
        let rows = lanes.way == .rows
        let colour = paint.line(frame.colour.isEmpty ? "teal" : frame.colour)
        // A row's name stands upright on the board; while it is typed it lies level, at the top of its band.
        let width: CGFloat = rows ? 170 : min(max(band.width - 6, 110), 220)
        let centre = rows ? CGPoint(x: band.minX + 3 + width / 2, y: band.minY + 16) : CGPoint(x: band.midX, y: band.midY)
        return TextField(lanes.name(typed.lane), text: Binding(
            get: { session.laneTyping?.draft ?? "" },
            set: { session.laneTyping?.draft = $0 }))
            .textFieldStyle(.plain)
            .font(Lettering.font(size: max(12 * session.scale, 12), bold: true))
            .foregroundStyle(colour)
            .multilineTextAlignment(rows ? .leading : .center)
            .focused($typing)
            .id("\(typed.frame)-\(typed.lane)")
            .submitLabel(.done)
            .onSubmit { session.commitLaneName() }
            .onKeyPress(.tab, phases: .down) { _ in
                // Tab: this name is kept and the next lane's name is typed.
                session.commitLaneName(next: true)
                return .handled
            }
            .onKeyPress(.escape, phases: .down) { _ in
                session.cancelLaneName()
                return .handled
            }
            .onAppear {
                DispatchQueue.main.async { typing = true }
            }
            .onChange(of: typing) { was, now in
                // A press somewhere else takes the keys away: the name is kept.
                if was, !now, session.laneTyping?.frame == typed.frame, session.laneTyping?.lane == typed.lane { session.commitLaneName() }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: width)
            .background(paint.plate, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(paint.chosen, lineWidth: 1.5))
            .position(centre)
            .accessibilityIdentifier("lanes.nameField")
    }
}
