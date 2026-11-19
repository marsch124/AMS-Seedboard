import SwiftUI
import SeedboardCore

// 0.11 (pick 26): one small purple line for the things that went to PARAGON's Inbox —
// "2 waiting for PARAGON", then "2 in PARAGON" once the read-back has seen them filed, and after a day
// "2 not filed yet — open PARAGON". Worked out from what the board keeps and what was read back; nothing is stored.

struct InboxWaitLine: View {
    @ObservedObject var session: BoardSession
    var low = false
    @ObservedObject private var echo = ParagonEcho.shared
    @EnvironmentObject private var model: AppModel
    /// The words still in PARAGON's waiting list (read only); nil = not readable.
    @State private var waiting: Set<String>?

    var body: some View {
        if !session.starterDraft, low == session.board.placesItself,
           let words = InboxWait.line(for: session.board, seen: echo.read[session.board.id] ?? [:], waiting: waiting) {
            HStack(spacing: 6) {
                GlyphView(glyph: .app(.send), size: 13, colour: Part.paragon.text)
                Text(words)
                    .font(Txt.pill)
                    .foregroundStyle(Part.paragon.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("board.inboxWait.words")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Part.paragon.soft, in: Capsule())
            .overlay(Capsule().stroke(Part.paragon.text.opacity(0.35)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("board.inboxWait")
            .task(id: session.board.sentTasks.count) {
                // Read the waiting list now and every 30 s while the line is shown. Read only.
                while !Task.isCancelled {
                    let url = model.place?.outbox
                    waiting = await Task.detached(priority: .utility) { () -> Set<String>? in
                        guard let url else { return nil }
                        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
                        guard let data = try? Data(contentsOf: url) else { return nil }
                        return InboxWait.waitingTexts(in: data)
                    }.value
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                }
            }
        }
    }
}
