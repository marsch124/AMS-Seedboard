import SwiftUI
import SeedboardCore
#if os(iOS)
import UIKit
#endif

// The screens of drawing by hand (0.2): the Draw tool in the tool pill, its small plate (pen and
// rubber, three thicknesses, the colours), the light layer the running line is drawn on, and the
// Pencil's double-tap and squeeze.

// MARK: The tool

/// The eighth tool. On: a finger and the mouse draw; pressed again (or Escape): off.
struct DrawTool: View {
    @ObservedObject var session: BoardSession
    @ObservedObject var desk: InkDesk
    @Environment(\.toolSide) private var side

    var body: some View {
        Button {
            session.toggleDraw()
            session.takeKeys()
        } label: {
            GlyphView(glyph: .new(.draw), size: ToolSize.mark(side), colour: desk.on ? .white : Part.drawing.text)
                .frame(width: side, height: side)
                .background(desk.on ? Part.drawing.fill : Part.drawing.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .pressRoom(3, 3)
        }
        .buttonStyle(PressStyle(tint: Part.drawing.text))
        .help("Draw (S)")
        .accessibilityLabel("Draw")
        .accessibilityValue(desk.on ? "On" : "Off")
        .accessibilityIdentifier("tool.draw")
        // Another tool takes over: the arrow tool, or a thing that was just made and waits for its words.
        .onChange(of: session.linking) { _, linking in if linking { desk.leave() } }
        .onChange(of: session.editing) { _, editing in if editing != nil { desk.leave() } }
    }
}

// MARK: The plate

/// Shown while the Draw tool is on: pen or rubber, thin / medium / thick, the colours, Done.
/// With the tool off it shows only when the Pencil's double-tap switched to the rubber, as one small line.
struct DrawPlate: View {
    @ObservedObject var session: BoardSession
    @ObservedObject var desk: InkDesk
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if session.readOnly || session.board.isTimeline {
            EmptyView()
        } else if desk.on {
            VStack(spacing: 4) {
                if desk.target != nil {
                    Text("Drawing on the picture. Press Done when you are finished.")
                        .font(Txt.note)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("draw.onPicture")
                }
                plate
                if InkDesk.pencilOnly {
                    Text("Fingers slide the board: “Only Draw with Apple Pencil” is on in Settings.")
                        .font(Txt.note)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("draw.pencilOnly")
                }
            }
        } else if desk.rubber && desk.target == nil {
            rubberLine
        } else if desk.fade {
            fadeLine
        }
    }

    private var plate: some View {
        WrapRow(spacing: Finger.chipGap) {
            HStack(spacing: Finger.chipGap) {
                tile(.draw, "draw.pen", "Pen", on: pen) { desk.usePen() }
                tile(.highlighter, "draw.highlighter", "Highlighter (H)", on: desk.highlighter) { desk.highlighter.toggle() }
                tile(.rubber, "draw.rubber", "Rubber", on: desk.rubber) { desk.rubber = true }
                tile(.lasso, "draw.lasso", "Lasso (L): draw a loop round pencil lines to choose them", on: desk.lasso) { desk.lasso.toggle() }
            }
            if desk.rubber {
                // 0.9: how near a line the rubber must come; it takes whole lines.
                HStack(spacing: Finger.chipGap) {
                    ForEach(RubberSize.allCases, id: \.self) { size in
                        word(size.word, "draw.rubber." + size.rawValue, on: desk.rubberSize == size, help: size.word + " rubber") { desk.rubberSize = size }
                    }
                }
            } else if desk.highlighter {
                highlightDots
            } else if !desk.lasso {
                HStack(spacing: Finger.chipGap) {
                    tile(.thin, "draw.thin", "Thin", on: pen && desk.width == .thin) { desk.pick(width: .thin) }
                    tile(.medium, "draw.medium", "Medium", on: pen && desk.width == .medium) { desk.pick(width: .medium) }
                    tile(.thick, "draw.thick", "Thick", on: pen && desk.width == .thick) { desk.pick(width: .thick) }
                }
                dots
                if Pencil19.showHoldTip {
                    Text("Hold at the end of a shape to make it neat.")
                        .font(Txt.note)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("draw.holdTip")
                        .onAppear { Pencil19.tipSeen() }
                }
            }
            // 0.11: a ruler to draw along (picks 37) and "Fade" for every pencil line of this board (38).
            HStack(spacing: Finger.chipGap) {
                tile(.ruler, "draw.ruler", "Ruler: lines drawn along it come out straight", on: desk.ruler != nil) {
                    session.toggleRuler()
                }
                tile(.fade, "draw.fade", "Fade: show the pencil lines of this board lighter", on: desk.fade) {
                    desk.fade.toggle()
                    session.objectWillChange.send()
                }
            }
            if desk.target == nil { InkTidySwitch(session: session, desk: desk) }
            Button("Done") {
                desk.leave()
                session.takeKeys()
            }
            .buttonStyle(FilledButton(.drawing))
            .accessibilityIdentifier("draw.done")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Part.drawing.text.opacity(0.35)))
        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("draw.plate")
    }

    /// The ordinary pen is in use (not the highlighter, rubber or lasso).
    private var pen: Bool { !desk.rubber && !desk.highlighter && !desk.lasso }

    /// A small button with a word (the plate has no hand-drawn mark for it yet).
    private func word(_ title: String, _ id: String, on: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            Text(title)
                .font(Txt.label)
                .foregroundStyle(on ? Color.white : Part.drawing.text)
                .padding(.horizontal, 9)
                .frame(height: Finger.shape.height)
                .background(on ? Part.drawing.fill : Part.drawing.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .pressRoom(4, 4)
        }
        .buttonStyle(PressStyle())
        .help(help)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    /// The highlighter's four colours.
    private var highlightDots: some View {
        let paint = Paint(scheme)
        return HStack(spacing: Finger.on ? 10 : Finger.dotGap) {
            ForEach(Ink.highlighterColours, id: \.self) { name in
                Button {
                    desk.pick(highlightColour: name)
                    session.takeKeys()
                } label: {
                    Circle()
                        .fill(paint.line(name).opacity(0.55))
                        .frame(width: Finger.on ? 26 : Finger.dot, height: Finger.on ? 26 : Finger.dot)
                        .pressRoom(5, 9)
                }
                .buttonStyle(PressStyle(wash: nil))
                .modifier(InUseRing(on: desk.highlightColour == name))
                .accessibilityLabel(name.capitalized + " highlighter")
                .accessibilityIdentifier("draw.highlight." + name)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
    }

    /// Plain ink first, then the palette.
    private var dots: some View {
        let paint = Paint(scheme)
        return HStack(spacing: Finger.on ? 10 : Finger.dotGap) {
            ForEach(InkRecent.order(recent: desk.recent, all: [""] + Palette.names), id: \.self) { name in
                Button {
                    desk.pick(colour: name)
                    session.takeKeys()
                } label: {
                    Circle()
                        .fill(InkDraw.colour(name, paint: paint))
                        .frame(width: Finger.on ? 26 : Finger.dot, height: Finger.on ? 26 : Finger.dot)
                        .pressRoom(5, 9)
                }
                .buttonStyle(PressStyle(wash: nil))
                .modifier(InUseRing(on: pen && desk.colour == name))
                .accessibilityLabel(name.isEmpty ? "Ink" : name.capitalized)
                .accessibilityIdentifier("draw.colour." + (name.isEmpty ? "ink" : name))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
    }

    private func tile(_ mark: NewMark, _ id: String, _ help: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            session.takeKeys()
        } label: {
            GlyphView(glyph: .new(mark), size: 20, colour: on ? .white : Part.drawing.text)
                .frame(width: Finger.shape.width, height: Finger.shape.height)
                .background(on ? Part.drawing.fill : Part.drawing.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .pressRoom(4, 4)
        }
        .buttonStyle(PressStyle(tint: Part.drawing.text))
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    /// "Fade" is on and the plate is closed: one small line says so, with the button that brings the lines back.
    private var fadeLine: some View {
        HStack(spacing: 8) {
            Text("Pencil lines are faded")
                .font(Txt.label)
            Button("Show") {
                desk.fade = false
                session.objectWillChange.send()
                session.takeKeys()
            }
            .buttonStyle(FilledButton(.drawing))
            .accessibilityIdentifier("draw.fadeOff")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Part.drawing.text.opacity(0.35)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("draw.fadeLine")
    }

    /// The Pencil rubs (after its double-tap) and no plate says so: one small line does.
    private var rubberLine: some View {
        HStack(spacing: 8) {
            GlyphView(glyph: .new(.rubber), size: 16, colour: Part.drawing.text)
            Text("The Pencil rubs out")
                .font(Txt.label)
            Button("Pen") {
                desk.rubber = false
                session.takeKeys()
            }
            .buttonStyle(FilledButton(.drawing))
            .accessibilityIdentifier("draw.backToPen")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Part.drawing.text.opacity(0.35)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("draw.rubberLine")
    }
}

// MARK: The wet line

/// A light layer over the board that draws only the line running under the tip (and the rubber's
/// ring). It alone listens to `WetLine`: a new sample repaints this one line — the board below is
/// not laid out, measured or painted again until the tip lifts.
struct InkLayer: View {
    @ObservedObject var wet: WetLine
    let offset: CGSize
    let scale: CGFloat
    let paint: Paint

    var body: some View {
        Canvas { ctx, _ in
            guard wet.live || wet.rubberAt != nil else { return }
            var sheet = ctx
            sheet.translateBy(x: offset.width, y: offset.height)
            sheet.scaleBy(x: scale, y: scale)
            if wet.live, wet.lasso {
                // The lasso's loop: a thin dashed line that closes itself.
                var loop = Path()
                if let first = wet.points.first {
                    loop.move(to: first)
                    for p in wet.points.dropFirst() { loop.addLine(to: p) }
                    loop.closeSubpath()
                }
                sheet.fill(loop, with: .color(Part.drawing.fill.opacity(0.10)))
                sheet.stroke(loop, with: .color(Part.drawing.fill),
                             style: StrokeStyle(lineWidth: 1.5 / scale, lineCap: .round, lineJoin: .round, dash: [5 / scale, 4 / scale]))
            } else if wet.live, wet.highlighter {
                InkDraw.highlight(wet.points + wet.ahead, colour: InkDraw.colour(wet.colour, paint: paint), in: sheet)
            } else if wet.live {
                // The same painting as a kept line; the predicted way is the last bit of it.
                InkDraw.stroke(wet.points + wet.ahead, pressure: wet.pressed ? wet.pressure + wet.aheadPressure : nil,
                               base: wet.width.points, colour: InkDraw.colour(wet.colour, paint: paint), in: sheet)
            }
            if let at = wet.rubberAt {
                let r = CGFloat(wet.rubberReach) / scale
                let ring = Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: r * 2, height: r * 2))
                sheet.fill(ring, with: .color(paint.plate.opacity(0.6)))
                sheet.stroke(ring, with: .color(paint.faint), lineWidth: 1.5 / scale)
                // 0.11 (pick 36): the ring says its size (Small, Medium or Large), just under it.
                if let size = RubberSize.allCases.first(where: { abs($0.screenReach - wet.rubberReach) < 0.5 }) {
                    let screen = CGPoint(x: at.x * scale + offset.width, y: (at.y + r) * scale + offset.height + 3)
                    ctx.draw(Text(size.word).font(.caption2).foregroundStyle(paint.faint), at: screen, anchor: .top)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: The Pencil's double-tap and squeeze

extension View {
    /// The Pencil's double-tap (and squeeze, where the Pencil has one) swaps pen and rubber or
    /// opens the Draw tool's plate — whichever the owner chose in Settings › Apple Pencil.
    @ViewBuilder
    func pencilTaps(_ desk: InkDesk) -> some View {
        #if os(iOS)
        if #available(iOS 17.5, *) {
            modifier(PencilTaps(desk: desk))
        } else {
            background(OldPencilTaps(desk: desk))
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
@available(iOS 17.5, *)
private struct PencilTaps: ViewModifier {
    let desk: InkDesk
    @Environment(\.preferredPencilDoubleTapAction) private var onTap
    @Environment(\.preferredPencilSqueezeAction) private var onSqueeze

    private func wish(_ action: PencilPreferredAction) -> InkDesk.PencilWish {
        switch action {
        case .switchEraser, .switchPrevious: return .swap
        case .showColorPalette, .showInkAttributes, .showContextualPalette: return .plate
        // "Off" in Settings, or a shortcut the system runs itself.
        default: return .nothing
        }
    }

    func body(content: Content) -> some View {
        content
            .onPencilDoubleTap { _ in desk.pencil(wish(onTap)) }
            .onPencilSqueeze { phase in
                if case .ended = phase { desk.pencil(wish(onSqueeze)) }
            }
    }
}

/// Before iOS 17.5: UIKit's own pencil interaction on a clear view (double-tap only; no Pencil squeezes there).
private struct OldPencilTaps: UIViewRepresentable {
    let desk: InkDesk

    func makeCoordinator() -> Listener { Listener(desk: desk) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let interaction = UIPencilInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) { context.coordinator.desk = desk }

    final class Listener: NSObject, UIPencilInteractionDelegate {
        var desk: InkDesk
        init(desk: InkDesk) { self.desk = desk }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            let wish: InkDesk.PencilWish
            switch UIPencilInteraction.preferredTapAction {
            case .switchEraser, .switchPrevious: wish = .swap
            case .showColorPalette, .showInkAttributes: wish = .plate
            default: wish = .nothing
            }
            MainActor.assumeIsolated { desk.pencil(wish) }
        }
    }
}
#endif
