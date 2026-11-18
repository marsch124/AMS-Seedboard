import SwiftUI
import SeedboardCore
import AMSIcons

// 0.5, pick 13: how a door is drawn — a small card (190 × 56) with the other board's small picture at the
// left, then its colour dot and its name (two lines at most), and a small arrow head at the right that says
// "this leads somewhere". Its edge wears the other board's colour. A door whose board was removed, or has
// not arrived on this device, is a quiet card with a dashed edge, the door mark and one line that says so.
// Drawn by the board's own painter, so the live board, the small pictures and the picture for PARAGON agree.

enum DoorCard {
    /// The size of the name on a door.
    static let nameSize: CGFloat = 13
    /// The size of the line under the name of a door that leads nowhere right now.
    static let lineSize: CGFloat = 11
    /// Width to height of the small picture (the same as every small picture of a board).
    static let pictureShape: CGFloat = 1.6

    private static var fitted: [String: String] = [:]

    /// The name cut to what fits `lines` lines of this width, with "…" at the end when it was cut.
    /// Worked out once per name and width (main thread only, like all drawing).
    static func fit(_ name: String, width: CGFloat, lines: Int, size: CGFloat = nameSize, bold: Bool = true) -> String {
        let key = "\(Int(width))|\(lines)|\(Int(size * 10))|\(name)"
        if let have = fitted[key] { return have }
        let room = Lettering.measure(Array(repeating: "Ag", count: max(lines, 1)).joined(separator: "\n"), size: size, bold: bold, maxWidth: 10_000).height
        func fits(_ words: String) -> Bool { Lettering.measure(words, size: size, bold: bold, maxWidth: width).height <= room }
        var out = name
        if !fits(out) {
            var low = 0, high = name.count
            while low < high {
                let middle = (low + high + 1) / 2
                if fits(String(name.prefix(middle)).trimmingCharacters(in: .whitespaces) + "…") { low = middle } else { high = middle - 1 }
            }
            out = String(name.prefix(low)).trimmingCharacters(in: .whitespaces) + "…"
        }
        if fitted.count > 400 { fitted = [:] }
        fitted[key] = out
        return out
    }
}

extension BoardPainter {
    /// Draws one door (see the top of this file).
    func drawDoor(_ item: Item, _ ctx: GraphicsContext) {
        let f = item.frame
        let card = Path(roundedRect: f, cornerRadius: 10)
        let look = DoorLook.shared
        switch look.face(of: item) {
        case .open(let title, let colour):
            // By day the card lies a little above the board, like a shape.
            var body = ctx
            if !paint.night { body.addFilter(.shadow(color: .black.opacity(0.08), radius: 2.5, x: 0, y: 1)) }
            body.fill(card, with: .color(paint.plate))
            ctx.stroke(card, with: .color(paint.line(colour)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))

            // The other board's small picture, as it is now.
            let pad: CGFloat = 8
            let high = max(f.height - pad * 2, 8)
            let picture = CGRect(x: f.minX + pad, y: f.minY + pad, width: min(high * DoorCard.pictureShape, f.width * 0.4), height: high)
            let window = Path(roundedRect: picture, cornerRadius: 5)
            ctx.fill(window, with: .color(paint.canvas))
            if let board = item.door.flatMap({ look.boards[$0] }), let image = look.picture(of: board, night: paint.night) {
                var inside = ctx
                inside.clip(to: window)
                inside.draw(Image(decorative: image, scale: 2).interpolation(.high), in: picture)
            }
            ctx.stroke(window, with: .color(paint.edge), lineWidth: 0.75)

            // The small arrow head at the right edge.
            let tip = CGPoint(x: f.maxX - 10, y: f.midY)
            var head = Path()
            head.move(to: CGPoint(x: tip.x - 4, y: tip.y - 5.5))
            head.addLine(to: CGPoint(x: tip.x + 1.5, y: tip.y))
            head.addLine(to: CGPoint(x: tip.x - 4, y: tip.y + 5.5))
            ctx.stroke(head, with: .color(paint.line(colour)), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))

            // The colour dot and the name, two lines at most.
            let dot: CGFloat = 8
            let left = picture.maxX + 8
            let wordsLeft = left + dot + 5
            let width = max(f.maxX - 20 - wordsLeft, 20)
            let name = DoorCard.fit(title.isEmpty ? "Board" : title, width: width, lines: 2)
            let font = Lettering.font(size: DoorCard.nameSize, bold: true)
            let words = ctx.resolve(Text(name).font(font).foregroundColor(paint.ink))
            let size = words.measure(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            let oneLine = ctx.resolve(Text("Ag").font(font)).measure(in: CGSize(width: 200, height: 100)).height
            let top = f.midY - size.height / 2
            ctx.draw(words, in: CGRect(x: wordsLeft, y: top, width: width + 1, height: size.height + 1))
            ctx.fill(Path(ellipseIn: CGRect(x: left, y: top + oneLine / 2 - dot / 2, width: dot, height: dot)), with: .color(paint.line(colour)))

        case .removed(let name), .away(let name):
            var removed = false
            if case .removed = look.face(of: item) { removed = true }
            ctx.fill(card, with: .color(paint.plate.opacity(paint.night ? 0.6 : 0.7)))
            ctx.stroke(card, with: .color(paint.faint), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [5, 4]))

            // The door mark from the icon library, in its own stroke.
            let side = min(26, max(f.height - 20, 12))
            let box = CGRect(x: f.minX + 12, y: f.midY - side / 2, width: side, height: side)
            let mark = GridShape(d: NewMark.door.standIn.path).path(in: box)
            ctx.stroke(mark, with: .color(paint.faint), style: StrokeStyle(lineWidth: 1.9 * side / 24, lineCap: .round, lineJoin: .round))

            let left = box.maxX + 9
            let width = max(f.maxX - 8 - left, 20)
            let title = DoorCard.fit(name.isEmpty ? "A board" : name, width: width, lines: 1)
            let nameFont = Lettering.font(size: DoorCard.nameSize, bold: true)
            let line = removed ? Door.removedWords : Door.awayWords
            let lineFont = Font.system(size: DoorCard.lineSize, weight: .medium)
            let top = ctx.resolve(Text(title).font(nameFont).foregroundColor(paint.faint))
            let under = ctx.resolve(Text(DoorCard.fit(line, width: width, lines: 1, size: DoorCard.lineSize, bold: false))
                .font(lineFont).foregroundColor(removed ? Part.kept.text : paint.faint))
            let a = top.measure(in: CGSize(width: width + 40, height: 100)), b = under.measure(in: CGSize(width: width + 40, height: 100))
            let y = f.midY - (a.height + b.height + 1) / 2
            ctx.draw(top, at: CGPoint(x: left, y: y), anchor: .topLeading)
            ctx.draw(under, at: CGPoint(x: left, y: y + a.height + 1), anchor: .topLeading)
        }
    }
}
