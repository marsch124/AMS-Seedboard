import SwiftUI
import SeedboardCore

// Pictures on a board (0.3). A picture is an item of kind `.picture`; the picture itself is a file of
// its own in the Pictures folder, named in `Item.picture`, written once and never changed.

/// The Picture tile of the tool row: asks for a picture and lays it in the middle of the view.
struct PictureTool: View {
    @ObservedObject var session: BoardSession
    @Environment(\.toolSide) private var side

    var body: some View {
        Button {
            // The pictures work fills this in: choose a picture, then lay it on the board.
            session.takeKeys()
        } label: {
            GlyphView(glyph: .new(.picture), size: ToolSize.mark(side), colour: Part.pictures.text)
                .frame(width: side, height: side)
                .background(Part.pictures.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .pressRoom(3, 3)
        }
        .buttonStyle(.plain)
        .help("Picture (P)")
        .accessibilityLabel("Picture (P)")
        .accessibilityIdentifier("tool.picture")
    }
}

extension BoardPainter {
    /// Draws one picture in its frame. The pictures work fills this in; until then, a plain plate.
    func drawPicture(_ item: Item, _ ctx: GraphicsContext) {
        let box = Path(roundedRect: item.frame, cornerRadius: 4)
        ctx.fill(box, with: .color(Part.pictures.soft))
        ctx.stroke(box, with: .color(Part.pictures.text.opacity(0.5)), lineWidth: 1)
    }
}
