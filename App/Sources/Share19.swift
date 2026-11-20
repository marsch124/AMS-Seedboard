import SwiftUI
import SeedboardCore

// 0.19, the `share` lane: "Share Picture of This Frame" (pick 43) and the Preview on the Send page (pick 44).
// No new SF Symbols: the share mark is the one "Share…" already wears (`.new(.share)`).

extension BoardSession {
    /// The one chosen frame, when a picture of it alone can be shared.
    var frameForPicture: Item? {
        guard !board.placesItself, let item = single, item.kind == .frame else { return nil }
        return item
    }

    /// Makes the picture of the chosen frame (and what lies in it) and opens the system's share choice.
    func shareFramePicture() {
        guard let frame = frameForPicture else { return }
        commitEdit()
        guard let part = board.framePicture(of: frame.id), SharePicture.show(part, fromFiles: true) else {
            AppModel.shared.say("The picture could not be made.", tone: .problem)
            return
        }
    }
}

extension BarActions {
    /// "Share Picture of This Frame": in the bar of a chosen frame and in its menu (`sel.frame.picture`, `menu.frame.picture`).
    func shareFramePicture(drop: Int = 4) -> [BarAction] {
        let session = session
        guard session.frameForPicture != nil else { return [] }
        return [act("frame.picture", "Share Picture of This Frame", .new(.share), show: .wideWord, drop: drop) { session.shareFramePicture() }]
    }
}

/// The Preview on the Send page: the first lines of the text that is written, "Show all" for the rest.
struct SendPreviewBox: View {
    let preview: SendPreviewText
    @State private var all = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Part.paragon.text)
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.shown(all: all))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("send.preview.text")
                if preview.hidden > 0 {
                    Button(all ? "Show less" : "Show all (\(preview.hidden) more lines)") { all.toggle() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Part.paragon.text)
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("send.preview.toggle")
                }
            }
            .padding(8)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("send.preview")
    }
}
