import SwiftUI
import SeedboardCore

// 0.5, the `send` lane: the parts of the Send page that are new — the look at the note the board became
// (reading only), the box "What PARAGON gets", the switches, and a sample for pictures.

extension ParagonGate {
    /// Looks at the note the board became: is it still at its place, and what stands in it?
    /// READING ONLY: nothing in PARAGON's folder is written, moved or asked to change. Call it off the main thread.
    /// nil when the board was never sent as a note or a project.
    static func look(at info: SentInfo?, in place: ParagonPlace) -> NoteLook? {
        guard let info else { return nil }
        // Only a place inside PARAGON's folder is looked at.
        let parts = info.path.split(separator: "/", omittingEmptySubsequences: false)
        guard !info.path.hasPrefix("/"), !parts.contains(".."), !parts.contains(""), info.path.lowercased().hasSuffix(".md") else { return .gone }
        let url = place.vault.appendingPathComponent(info.path)
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return .there(text: text) }
            return .notFetched
        }
        // A note iCloud has not brought to this device yet is listed as ".Name.md.icloud": it is there.
        let waiting = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        return fm.fileExists(atPath: waiting.path) ? .notFetched : .gone
    }
}

/// The box "What PARAGON gets": the rows of the very text Send writes, about nine rows high, scrolling.
struct ParagonGetsBox: View {
    let rows: [PreviewRow]
    /// The board whose small picture stands where the note's picture is; nil = a line of words instead.
    let picture: Board?
    let countLine: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What PARAGON gets")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Part.paragon.text)
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        line(row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .frame(height: 168)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("send.gets")
            Text(countLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("send.count")
        }
    }

    @ViewBuilder
    private func line(_ row: PreviewRow) -> some View {
        switch row.kind {
        case .picture:
            if let picture {
                BoardThumb(board: picture)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            } else {
                Text("The picture")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .heading(let level):
            Text(row.words)
                .font(level <= 2 ? .caption.weight(.bold) : .caption.weight(.semibold))
                .foregroundStyle(level <= 2 ? Color.primary : Part.paragon.text)
                .padding(.top, level <= 2 ? 3 : 1)
        case .task:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .stroke(Part.paragon.text, lineWidth: 1.3)
                    .background(RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(row.done ? Part.paragon.text : .clear))
                    .overlay {
                        if row.done {
                            // A drawn tick, white on the filled box: the task arrives done.
                            Path { p in
                                p.move(to: CGPoint(x: 2.3, y: 5.2))
                                p.addLine(to: CGPoint(x: 4.3, y: 7.3))
                                p.addLine(to: CGPoint(x: 7.8, y: 2.9))
                            }
                            .stroke(.white, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .frame(width: 10, height: 10)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                Text(row.words)
                    .font(.caption)
                    .foregroundStyle(row.done ? .secondary : .primary)
                    .strikethrough(row.done, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                if let day = row.day {
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Part.paragon.text)
                        .lineLimit(1)
                }
            }
            .padding(.leading, CGFloat(row.indent) * 14)
        case .plain:
            Text(row.words)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, CGFloat(row.indent) * 14)
        }
    }
}

/// A switch of the Send page: its words, a small drawn switch at the right. Looks like the branch switch.
struct SendSwitch: View {
    let words: String
    @Binding var on: Bool
    let identifier: String

    var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 8) {
                Text(words)
                    .font(Txt.label)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Capsule()
                    .fill(on ? Part.paragon.fill : Color.primary.opacity(0.22))
                    .frame(width: 38, height: 22)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle().fill(Color.white).padding(2)
                    }
                    .animation(Feel.moves ? .easeOut(duration: 0.12) : nil, value: on)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(words)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityIdentifier(identifier)
    }
}

/// For pictures of "Add what is new" on the sample boards: `-sentBefore` shows the open board as one that
/// went to PARAGON as a project a week ago, with its last three tasks (or its last one) new and one changed since;
/// `-sentGone` the same with the project gone from its place. Only with `-sampleData`; nothing is stored.
enum SendSample {
    static var on: Bool {
        LaunchOptions.sampleData && (LaunchOptions.arguments.contains("-sentBefore") || LaunchOptions.arguments.contains("-sentGone"))
    }

    static var look: NoteLook? {
        guard on else { return nil }
        return LaunchOptions.arguments.contains("-sentGone") ? .gone : .there(text: "")
    }

    static func board(_ board: Board) -> Board {
        guard on, board.sent == nil else { return board }
        var copy = board
        let when = Date().addingTimeInterval(-7 * 86_400)
        let title = ParagonExport.noteTitle(for: board.title)
        let all = ParagonExport.projectHandover(board: board, title: title, picture: nil, now: when).tasks
        // The last three tasks are new; on a board with few tasks, the last one.
        var known = Array(all.prefix(all.count > 3 ? all.count - 3 : max(all.count - 1, 0)))
        if !known.isEmpty {
            // A bar that has moved since (a timeline), a thing that was renamed since (any other board).
            known[0].words = board.isTimeline ? String(known[0].words.dropLast(10)) + "2026-01-01" : known[0].words + " (first plan)"
        }
        copy.noteSent(known, place: SentTask.note)
        copy.sent = SentInfo(when: when, kind: "project", title: title, path: "Projects/\(title).md")
        return copy
    }
}

#if DEBUG
extension BoardSession {
    /// For trying "Add what is new" (`-sendNow project+add`): a new bar on a timeline, a ticked sticky note on any other board.
    func layDownSomethingNewForTrying() {
        _ = change { board in
            if board.isTimeline {
                let last = board.items.compactMap { $0.span?.end }.max() ?? Day.today()
                board.addBar("Roof", start: last + 1, days: 10)
            } else if !board.isSequence {
                let id = board.add(.note, centre: board.arrivalSpot(size: ItemKind.note.defaultSize), text: "Order timber")
                if let i = board.index(of: id) { board.items[i].todo = true }
            }
        }
    }
}
#endif
