import SwiftUI
import Combine
import UniformTypeIdentifiers
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
import PhotosUI
#endif

// Pictures on a board (0.3). A picture is an item of kind `.picture`; the picture itself is a file of
// its own in the Pictures folder (PictureStore.swift), named in `Item.picture`, written once and never changed.
// Ways in: the Picture tool, the letter P and Insert ▸ Picture… (a picker), Paste (ClipBoard.swift), and a drop.

/// Asks for the picker from anywhere (the tool, the letter P, the Insert menu, the board's menu). The board's
/// own `PictureHost` answers; `spot` (board points) is where it was asked for, nil: the middle of the view.
@MainActor
final class PictureDesk {
    static let shared = PictureDesk()
    let ask = PassthroughSubject<CGPoint?, Never>()
}

/// The Picture tile of the tool row: asks for a picture and lays it in the middle of the view.
struct PictureTool: View {
    @ObservedObject var session: BoardSession
    @Environment(\.toolSide) private var side

    var body: some View {
        Button {
            // 0.5: the press that opened the plate of ways (hold the tile) is not a press as well.
            if PictureHold.swallow() { return }
            session.commitEdit()
            PictureDesk.shared.ask.send(nil)
        } label: {
            GlyphView(glyph: .new(.picture), size: ToolSize.mark(side), colour: Part.pictures.text)
                .frame(width: side, height: side)
                .background(Part.pictures.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .pressRoom(3, 3)
        }
        .buttonStyle(PressStyle(tint: Part.pictures.text))
        .help("Picture (P)")
        .accessibilityLabel("Picture (P)")
        .accessibilityIdentifier("tool.picture")
        // 0.5 (iPhone and iPad): hold the tile for "Photos · Take a photo · Scan a page" (PictureWays.swift).
        .modifier(PictureWaysHold(session: session))
    }
}

/// Insert ▸ Picture… (the Mac menu bar, and the iPad's with a keyboard). The letter P only while letters are tools.
struct PictureInsertLine: View {
    let enabled: Bool
    let letter: Bool

    var body: some View {
        let button = Button("Picture…") { PictureDesk.shared.ask.send(nil) }.disabled(!enabled)
        if letter { button.keyboardShortcut("p", modifiers: []) } else { button }
    }
}

/// On the drawing surface (`ClipKeys`): answers the picker, redraws when a picture arrives, and — for pictures
/// of the launch words — chooses the first picture (`-pickPicture`).
struct PictureHost: ViewModifier {
    @ObservedObject var session: BoardSession
    #if !os(macOS)
    @State private var showing = false
    @State private var chosen: [PhotosPickerItem] = []
    @State private var spot: CGPoint?
    #endif

    func body(content: Content) -> some View {
        let base = content
            .onReceive(PictureStore.shared.arrived) { _ in session.objectWillChange.send() }
            .onReceive(PictureDesk.shared.ask) { place in ask(at: place) }
            .onAppear {
                // Launch words for pictures of the screen: -pickPicture chooses the first picture, -cropPicture opens its crop page.
                let crop = LaunchOptions.arguments.contains("-cropPicture")
                guard LaunchOptions.arguments.contains("-pickPicture") || crop,
                      let item = session.board.items.first(where: { $0.kind == .picture }) else { return }
                session.select(item.id)
                if crop { session.cropping = item.id }
            }
        #if os(macOS)
        base
        #else
        base
            .photosPicker(isPresented: $showing, selection: $chosen, maxSelectionCount: 12, matching: .images)
            .onChange(of: chosen) { _, items in
                guard !items.isEmpty else { return }
                chosen = []
                let place = spot
                Task { @MainActor in
                    var all: [Data] = []
                    for item in items { if let data = try? await item.loadTransferable(type: Data.self) { all.append(data) } }
                    session.lay(pictures: all, at: place)
                }
            }
        #endif
    }

    private func ask(at place: CGPoint?) {
        guard !session.readOnly, !session.board.placesItself else {
            AppModel.shared.say("A picture cannot be put on this board.", tone: .problem)
            return
        }
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Choose a picture"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { answer in
            guard answer == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in
                session.lay(pictures: urls.compactMap { try? Data(contentsOf: $0) }, at: place)
                session.takeKeys()
            }
        }
        #else
        spot = place
        showing = true
        #endif
    }
}

extension BoardSession {
    /// Lays pictures that came in (a picker, the clipboard, a drop) on the board, chosen. `point` (board points): where
    /// the first one's middle goes, the next ones 28 further down and right; nil: a free place near the middle of the view.
    /// A picture that cannot be read is said, never silently dropped.
    func lay(pictures: [Data], at point: CGPoint? = nil) {
        guard !readOnly, !board.placesItself else {
            AppModel.shared.say("A picture cannot be put on this board.", tone: .problem)
            return
        }
        guard !pictures.isEmpty else { return }
        // The board was closed while the pictures were on their way (the photos were loading, a drop was read):
        // a board that is no longer shown must not save its older state over the open one (0.5).
        let closed = "The pictures were not laid: the board was closed."
        guard SafetyRules.maySave(asking: self, shown: AppModel.shared.session) else {
            AppModel.shared.say(closed, tone: .problem)
            return
        }
        commitEdit()
        Task { @MainActor in
            var made: Set<UUID> = []
            var failed = 0
            var spot = point
            for data in pictures {
                let taken = await Task.detached(priority: .userInitiated) { PictureStore.shared.take(data) }.value
                guard SafetyRules.maySave(asking: self, shown: AppModel.shared.session) else {
                    AppModel.shared.say(closed, tone: .problem)
                    return
                }
                guard let taken else { failed += 1; continue }
                // Never under his hands: while he types or drags, the picture waits (else the typing's Escape or the
                // drag's next move would take it away again).
                while busy {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard SafetyRules.maySave(asking: self, shown: AppModel.shared.session) else {
                        AppModel.shared.say(closed, tone: .problem)
                        return
                    }
                }
                let size = Board.pictureSize(forPixels: taken.pixels)
                let at = spot ?? freeSpot(near: visibleCentre, size: size)
                var id: UUID?
                change { id = $0.addPicture(name: taken.name, pixelSize: taken.pixels, centre: at) }
                if let id { made.insert(id) }
                if let s = spot { spot = CGPoint(x: s.x + 28, y: s.y + 28) }
            }
            if !made.isEmpty {
                selectedLink = nil
                selection = made
                if let first = made.first { reveal(first) }
            }
            if failed > 0 { AppModel.shared.say(failed == 1 ? "That could not be read as a picture." : "\(failed) could not be read as pictures.", tone: .problem) }
        }
    }
}

/// The caption's lettering: the app's small label size (12 points on the board, grown and shrunk with the board).
enum PictureCaption {
    static let size: CGFloat = 12
    static let font = Font.system(size: size)

    /// The caption broken into lines no wider than the picture (a word wider than that is cut where it must).
    static func lines(_ words: String, width: CGFloat) -> [String] {
        func wide(_ text: String) -> CGFloat { Lettering.measure(text, size: size, bold: false, maxWidth: .greatestFiniteMagnitude).width }
        var out: [String] = []
        for paragraph in words.components(separatedBy: .newlines) {
            var line = ""
            for word in paragraph.split(separator: " ") {
                var piece = String(word)
                let tryLine = line.isEmpty ? piece : line + " " + piece
                if wide(tryLine) <= width || line.isEmpty && piece.count <= 1 { line = tryLine; continue }
                if !line.isEmpty { out.append(line); line = "" }
                // A very long word: cut it where the line is full.
                while wide(piece) > width, piece.count > 1 {
                    var n = piece.count - 1
                    while n > 1, wide(String(piece.prefix(n))) > width { n -= 1 }
                    out.append(String(piece.prefix(n)))
                    piece = String(piece.dropFirst(n))
                }
                line = piece
            }
            out.append(line)
        }
        return out
    }
}

// MARK: Drawing

extension BoardPainter {
    /// Draws one picture in its frame (corner radius 4), the picture filling it. A file that is not here yet
    /// (missing, or iCloud is still bringing it) is a soft plate with the picture mark and "Picture not here yet".
    /// The picture for PARAGON, Share, Export and the list's small pictures (`handles` off) is read at once.
    func drawPicture(_ item: Item, _ ctx: GraphicsContext) {
        drawPictureBody(item, ctx)
        drawPictureMarks(item, ctx)
        drawCaption(item, ctx)
    }

    /// The caption: under the picture, 6 points below it, centred, wrapped to the picture's width, in the small label size
    /// and the secondary ink. It is not part of the picture's box. While it is typed, the field shows it instead.
    private func drawCaption(_ item: Item, _ ctx: GraphicsContext) {
        guard editing != item.id, let room = item.captionFrame else { return }
        var y = room.minY
        for line in PictureCaption.lines(item.captionWords, width: room.width) {
            ctx.draw(Text(line).font(PictureCaption.font).foregroundColor(paint.faint), at: CGPoint(x: room.midX, y: y), anchor: .top)
            y += CGFloat(Item.captionLine)
        }
    }

    private func drawPictureBody(_ item: Item, _ ctx: GraphicsContext) {
        let f = item.frame
        let box = Path(roundedRect: f, cornerRadius: 4)
        let store = PictureStore.shared
        if let name = item.picture, let image = handles ? store.image(name, shown: shownPixels(item, ctx)) : (PaperPictures.image(name) ?? store.imageNow(name)) {
            var inside = ctx
            inside.clip(to: box)
            if let part = Item.cleanCrop(item.crop) {
                // Cropped (0.4): the whole picture lies on the board at its own scale; only the part shows in the box.
                let wholeW = f.width / CGFloat(part[2]), wholeH = f.height / CGFloat(part[3])
                inside.draw(Image(decorative: image, scale: 1),
                            in: CGRect(x: f.minX - CGFloat(part[0]) * wholeW, y: f.minY - CGFloat(part[1]) * wholeH, width: wholeW, height: wholeH))
            } else {
                // It keeps its shape (resizing does); a little difference is cropped, never stretched.
                let k = max(f.width / CGFloat(image.width), f.height / CGFloat(image.height))
                let w = CGFloat(image.width) * k, h = CGFloat(image.height) * k
                inside.draw(Image(decorative: image, scale: 1), in: CGRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h))
            }
            ctx.stroke(box, with: .color(Part.pictures.text.opacity(0.28)), lineWidth: 0.75)
            return
        }
        ctx.fill(box, with: .color(Part.pictures.soft))
        ctx.stroke(box, with: .color(Part.pictures.text.opacity(0.5)), lineWidth: 1)
        let side = max(14, min(40, min(f.width, f.height) * 0.42))
        // The words only when the file was looked for and is not on this device; a plain plate while it is being read (0.5).
        let words = f.height >= 70 && f.width >= 90 && (item.picture.map { store.isMissing($0) } ?? true)
        let mark = CGRect(x: f.midX - side / 2, y: f.midY - side / 2 - (words ? 9 : 0), width: side, height: side * 0.8)
        Self.pictureMark(mark, in: ctx, colour: Part.pictures.text, line: max(1.2, side / 14))
        if words {
            let font: Font = f.width >= 150 ? Txt.label : Font.caption2
            ctx.draw(Text("Picture not here yet").font(font).foregroundStyle(Part.pictures.text),
                     at: CGPoint(x: f.midX, y: mark.maxY + 5), anchor: .top)
        }
    }

    /// How many screen pixels long the WHOLE picture is drawn right now (two pixels a point); 0 when it is out of
    /// view. The store reads a picture in full only when it is shown clearly larger than its memory copy.
    private func shownPixels(_ item: Item, _ ctx: GraphicsContext) -> Double {
        let f = item.frame
        guard ctx.clipBoundingRect.intersects(f) else { return 0 }
        let part = item.shownPart
        return Double(max(f.width / CGFloat(part[2]), f.height / CGFloat(part[3])) * scale) * 2
    }

    /// The picture mark drawn as shapes: a frame, a sun and two hills, one round line, no fill.
    static func pictureMark(_ r: CGRect, in ctx: GraphicsContext, colour: Color, line: CGFloat) {
        let style = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
        ctx.stroke(Path(roundedRect: r, cornerRadius: r.height * 0.14), with: .color(colour), style: style)
        let sun = CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.18, width: r.width * 0.16, height: r.width * 0.16)
        ctx.stroke(Path(ellipseIn: sun), with: .color(colour), style: style)
        var hills = Path()
        hills.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.12))
        hills.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.5))
        hills.addLine(to: CGPoint(x: r.minX + r.width * 0.58, y: r.minY + r.height * 0.74))
        hills.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.58))
        hills.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.12))
        ctx.stroke(hills, with: .color(colour), style: style)
    }
}
