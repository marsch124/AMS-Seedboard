import SwiftUI
import SeedboardCore

// "Crop the picture" (0.4): a page over the board. The WHOLE picture is fitted into the page; over it lies a frame with four
// round corner grips. Drag a grip to change the frame, drag inside it to move it; everything outside is dimmed. The frame never
// leaves the picture and never gets smaller than 44 points on screen. Save applies `Board.cropPicture` (one Undo takes it back);
// the picture's file is never changed. Plain SwiftUI gestures: finger, mouse and trackpad.

struct CropPage: View {
    @ObservedObject var session: BoardSession
    let id: UUID
    /// The part that is shown, as x, y, width, height of the whole picture (each 0 to 1).
    @State private var part = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var started = false
    /// What the part was when the present drag began.
    @State private var dragBase: CGRect?
    @Environment(\.colorScheme) private var scheme

    private var item: Item? { session.board.item(id) }
    private var image: CGImage? { item?.picture.flatMap { PictureStore.shared.imageNow($0) } }
    private static let grip: CGFloat = 44

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                GlyphView(glyph: .new(.crop), size: 18, colour: Part.pictures.text)
                Text("Crop the picture").font(Txt.cardTitle).foregroundStyle(Part.pictures.text)
                Spacer(minLength: 0)
            }
            if let image {
                GeometryReader { box in
                    stage(image, in: box.size)
                }
            } else {
                Spacer()
                Text("Picture not here yet").font(Txt.label).foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 10) {
                Button("Cancel") { close() }
                    .buttonStyle(PressStyle())
                    .font(.body.weight(.medium))
                    .foregroundStyle(Part.pictures.text)
                    .frame(minHeight: 36)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("crop.cancel")
                Spacer(minLength: 0)
                Button("Whole picture") { part = CGRect(x: 0, y: 0, width: 1, height: 1) }
                    .buttonStyle(PressStyle())
                    .font(.body.weight(.medium))
                    .foregroundStyle(Part.pictures.text)
                    .frame(minHeight: 36)
                    .accessibilityIdentifier("crop.whole")
                Button("Save") { save() }
                    .buttonStyle(FilledButton(.pictures))
                    .disabled(image == nil)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("crop.save")
            }
        }
        .padding(12)
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 600, minHeight: 440, idealHeight: 500)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("crop.page")
        .onAppear {
            guard !started else { return }
            started = true
            let p = item?.shownPart ?? [0, 0, 1, 1]
            part = CGRect(x: p[0], y: p[1], width: p[2], height: p[3])
        }
    }

    private func close() {
        session.cropping = nil
        session.takeKeys()
    }

    private func save() {
        let whole = part.minX <= 0.0005 && part.minY <= 0.0005 && part.width >= 0.9995 && part.height >= 0.9995
        session.change { $0.cropPicture(id, to: whole ? nil : [part.minX, part.minY, part.width, part.height].map(Double.init)) }
        close()
    }

    // MARK: The picture, the dimming, the frame and its grips

    private func stage(_ image: CGImage, in room: CGSize) -> some View {
        let shape = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        // Half a grip of air all round, so the corner grips are whole and can be pressed at the page's edge too.
        let air = Self.grip / 2
        let k = min(max(room.width - 2 * air, 1) / shape.width, max(room.height - 2 * air, 1) / shape.height)
        let fitted = CGSize(width: shape.width * k, height: shape.height * k)
        let origin = CGPoint(x: (room.width - fitted.width) / 2, y: (room.height - fitted.height) / 2)
        let whole = CGRect(origin: origin, size: fitted)
        let box = CGRect(x: whole.minX + part.minX * whole.width, y: whole.minY + part.minY * whole.height,
                         width: part.width * whole.width, height: part.height * whole.height)
        let least = CGSize(width: min(1, max(Item.cropLeast, Self.grip / whole.width)), height: min(1, max(Item.cropLeast, Self.grip / whole.height)))
        return ZStack(alignment: .topLeading) {
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: whole.width, height: whole.height)
                .position(x: whole.midX, y: whole.midY)
            // Everything outside the frame is dimmed.
            Path { path in
                path.addRect(whole)
                path.addRect(box)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            // The frame: a white line with a coloured one beside it, and thirds to help the eye.
            Path { path in
                path.addRect(box)
                for n in 1...2 {
                    let x = box.minX + box.width * CGFloat(n) / 3, y = box.minY + box.height * CGFloat(n) / 3
                    path.move(to: CGPoint(x: x, y: box.minY)); path.addLine(to: CGPoint(x: x, y: box.maxY))
                    path.move(to: CGPoint(x: box.minX, y: y)); path.addLine(to: CGPoint(x: box.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.9), lineWidth: 1)
            .allowsHitTesting(false)
            // Inside the frame: drag to move it.
            Color.clear
                .contentShape(Rectangle())
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let base = dragBase ?? part
                        dragBase = base
                        let dx = drag.translation.width / whole.width, dy = drag.translation.height / whole.height
                        part = CGRect(x: min(max(base.minX + dx, 0), 1 - base.width), y: min(max(base.minY + dy, 0), 1 - base.height),
                                      width: base.width, height: base.height)
                    }
                    .onEnded { _ in dragBase = nil })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Crop frame")
                .accessibilityIdentifier("crop.frame")
            ForEach(Corner.allCases, id: \.self) { corner in
                let at = Self.point(of: corner, in: box)
                ZStack {
                    Circle().fill(Part.pictures.fill).frame(width: 22, height: 22)
                    Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 22, height: 22)
                }
                .frame(width: Self.grip, height: Self.grip)
                .contentShape(Circle())
                .position(at)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let base = dragBase ?? part
                        dragBase = base
                        part = Self.moved(corner, of: base, by: CGSize(width: drag.translation.width / whole.width, height: drag.translation.height / whole.height), least: least)
                    }
                    .onEnded { _ in dragBase = nil })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Corner")
                .accessibilityIdentifier("crop.grip.\(corner.rawValue)")
            }
        }
        .frame(width: room.width, height: room.height)
        .clipped()
    }

    private static func point(of corner: Corner, in r: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: r.minX, y: r.minY)
        case .topRight: return CGPoint(x: r.maxX, y: r.minY)
        case .bottomLeft: return CGPoint(x: r.minX, y: r.maxY)
        case .bottomRight: return CGPoint(x: r.maxX, y: r.maxY)
        }
    }

    /// The part with one corner dragged by this much (of the whole picture): the opposite corner stays, the frame stays
    /// inside the picture and keeps at least `least`.
    static func moved(_ corner: Corner, of base: CGRect, by d: CGSize, least: CGSize) -> CGRect {
        var left = base.minX, right = base.maxX, top = base.minY, bottom = base.maxY
        switch corner {
        case .topLeft, .bottomLeft: left = min(max(base.minX + d.width, 0), right - least.width)
        case .topRight, .bottomRight: right = max(min(base.maxX + d.width, 1), left + least.width)
        }
        switch corner {
        case .topLeft, .topRight: top = min(max(base.minY + d.height, 0), bottom - least.height)
        case .bottomLeft, .bottomRight: bottom = max(min(base.maxY + d.height, 1), top + least.height)
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
