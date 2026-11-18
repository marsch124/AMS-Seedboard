import SwiftUI
import SeedboardCore

// 0.5, pick 16: one small purple line under the board's top bar, on a board that is a note or a project in
// PARAGON — "Project “Summer cabin” · 5 of 13 done · checked 14:02" with "Open in PARAGON".
// What it says was READ from PARAGON's note and is kept on this device (EchoKeeper.swift).

struct SentLine: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    /// The place above the tools, used on a timeline and a "Who does what" board (their top holds the dates and
    /// the names). Every other board carries the line under the top bar.
    var low = false
    @ObservedObject private var echo = EchoKeeper.shared

    var body: some View {
        if !session.starterDraft, low == session.board.placesItself, let sent = session.board.sent, let line = echo.line(for: session.board) {
            // Wide enough: the whole line. Otherwise without "checked …" and with a short "Open".
            ViewThatFits(in: .horizontal) {
                row(line, open: "Open in PARAGON", sent)
                row(echo.line(for: session.board, short: true) ?? line, open: "Open", sent)
            }
            // Its own element with its button inside, so both keep their own names for the screen tests.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("board.sentLine")
        }
    }

    private func row(_ words: String, open: String, _ sent: SentInfo) -> some View {
        HStack(spacing: 6) {
            GlyphView(glyph: .app(.send), size: 13, colour: Part.paragon.text)
            Text(words)
                .font(Txt.pill)
                .foregroundStyle(Part.paragon.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("board.sentLine.words")
            if echo.canOpen(session.board) {
                Button {
                    model.openInParagon(sent)
                    session.takeKeys()
                } label: {
                    Text(open)
                        .font(Txt.pill.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Look.paragonButton, in: Capsule())
                        .pressRoom(4, 11)
                }
                .buttonStyle(PressStyle(wash: nil))
                .help("Open this note in PARAGON")
                .accessibilityLabel("Open in PARAGON")
                .accessibilityIdentifier("board.sentLine.open")
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, echo.canOpen(session.board) ? 4 : 10)
        .padding(.vertical, 3)
        .background(Part.paragon.soft, in: Capsule())
        .overlay(Capsule().stroke(Part.paragon.text.opacity(0.35)))
    }
}

/// The small line on a board's card: "Changed 2 days ago", and for a board that is a note or a project in
/// PARAGON "Changed 2 days ago · 5 of 13 done". A card is narrow: when that does not fit it says
/// "2 days ago · 5 of 13 done", and when that does not fit either, "5 of 13 done".
struct DoneWords: View {
    let changed: String
    /// " · 5 of 13 done", or nothing (`EchoKeeper.doneTail`).
    let tail: String

    var body: some View {
        if tail.isEmpty {
            Text(changed)
        } else {
            ViewThatFits(in: .horizontal) {
                Text(changed + tail)
                Text(changed.replacingOccurrences(of: "Changed ", with: "") + tail)
                Text(tail.replacingOccurrences(of: " · ", with: ""))
            }
        }
    }
}
