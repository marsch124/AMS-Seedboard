import SwiftUI
import SeedboardCore
import AMSIcons
#if os(macOS)
import AppKit
#endif

/// "Removed and earlier versions": removed boards come back under their own identity, and an earlier
/// version of a board opens as a copy. Reached from Settings › Your boards (pushed there), and shown
/// over the main window when a line on the board asks for it. Its colour is `Part.kept`.
struct KeptPage: View {
    /// Open this board's earlier versions and scroll to them.
    var focus: UUID?
    /// Closes everything the page is shown in (Settings, or its own sheet), so a board can be seen.
    let closeAll: () -> Void

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var shelf = KeptShelf()
    @State private var loaded = false
    @State private var opened: Set<UUID> = []
    @State private var forGood: RemovedCopy?
    @State private var back: Board?
    @State private var problem: String?
    @State private var working = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    if loaded && shelf.removed.isEmpty {
                        Text("Nothing was removed in the last 30 days.")
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("kept.removedEmpty")
                    }
                    ForEach(shelf.removed) { copy in
                        RemovedRow(copy: copy, working: working,
                                   bringBack: { bringBack(copy) }, forGood: { forGood = copy })
                    }
                    if shelf.waiting > 0 {
                        Text(shelf.waiting == 1 ? "1 more removed board is on its way from iCloud."
                                                : "\(shelf.waiting) more removed boards are on their way from iCloud.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("kept.waiting")
                    }
                } header: {
                    header("Removed", .bringBack)
                } footer: {
                    Text("A removed board is kept for 30 days. Bring back returns it as it was, on every device.")
                }

                Section {
                    if loaded && shelf.groups.isEmpty {
                        Text("No earlier versions are kept yet.")
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("kept.earlierEmpty")
                    }
                    ForEach(shelf.groups) { group in
                        GroupRow(group: group, open: opened.contains(group.id)) {
                            if opened.contains(group.id) { opened.remove(group.id) } else { opened.insert(group.id) }
                        }
                        .id(group.id)
                        if opened.contains(group.id) {
                            ForEach(group.versions) { version in
                                VersionRow(version: version, title: group.title, working: working) { openAsCopy(version) }
                            }
                            if group.hidden > 0 {
                                Text(group.hidden == 1 ? "1 older version of this device is kept but not listed."
                                                       : "\(group.hidden) older versions of this device are kept but not listed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 21)
                            }
                        }
                    }
                } header: {
                    header("Earlier versions", .earlier)
                } footer: {
                    Text("A copy of every board is kept once a day, 14 days back; a version that lost against another device's is kept 30 days. Open as a copy makes a new board; the board itself stays as it is.")
                }
            }
            .environment(\.defaultMinListRowHeight, 10)
            .task {
                await reload()
                // One board only, or the one that was asked for: its versions are open at once.
                if let focus, shelf.groups.contains(where: { $0.id == focus }) {
                    opened = [focus]
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    withAnimation { proxy.scrollTo(focus, anchor: .top) }
                } else if shelf.groups.count == 1, let only = shelf.groups.first {
                    opened = [only.id]
                }
            }
        }
        // (The Mac's sheet says the page's name itself, in colour: BringBackBars.swift.)
        #if !os(macOS)
        .navigationTitle("Removed and earlier versions")
        #endif
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .buttonStyle(FilledButton(.kept))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("kept.done")
            }
        }
        .safeAreaInset(edge: .bottom) { notice }
        .confirmationDialog("Remove “\(forGood?.board.title ?? "")” for good?",
                            isPresented: Binding(get: { forGood != nil }, set: { if !$0 { forGood = nil } }),
                            titleVisibility: .visible) {
            Button("Remove for good", role: .destructive) {
                if let copy = forGood { removeForGood(copy) }
                forGood = nil
            }
            .accessibilityIdentifier("kept.forGoodConfirm")
            Button("Cancel", role: .cancel) { forGood = nil }
        } message: {
            Text("This cannot be undone. Links to it from PARAGON's notes will no longer open it.")
        }
        .accessibilityIdentifier("kept.page")
    }

    private func header(_ title: String, _ mark: NewMark) -> some View {
        HStack(spacing: 6) {
            GlyphView(glyph: .new(mark), size: 16, colour: Part.kept.text)
            PartHeader(title, .kept)
        }
    }

    /// The short line after something was done: a board is back (with "Open"), or why something did not work.
    @ViewBuilder
    private var notice: some View {
        if let board = back {
            HStack(spacing: 10) {
                Text("“\(board.title)” is back.")
                    .font(Txt.label)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Button("Open") {
                    model.open(board.id)
                    showMainWindow()
                    closeAll()
                }
                .font(Txt.label.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.22), in: Capsule())
                .buttonStyle(PressStyle(wash: nil))
                .accessibilityIdentifier("kept.open")
            }
            .padding(.leading, 12)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .background(Part.kept.fill, in: Capsule())
            .padding(.bottom, 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("kept.notice")
        } else if let problem {
            Text(problem)
                .font(Txt.label)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Part.kept.fill, in: Capsule())
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .accessibilityIdentifier("kept.problem")
        }
    }

    // MARK: What the buttons do

    private func reload() async {
        shelf = await model.keptShelf()
        loaded = true
    }

    private func bringBack(_ copy: RemovedCopy) {
        guard !working else { return }
        working = true
        Task {
            let board = await model.bringBack(removed: copy.id)
            back = board
            problem = board == nil ? "“\(copy.board.title)” could not be brought back: no copy of it can be read." : nil
            await reload()
            working = false
        }
    }

    private func removeForGood(_ copy: RemovedCopy) {
        guard !working else { return }
        working = true
        Task {
            await model.removeForGood(copy.id)
            back = nil
            problem = nil
            await reload()
            working = false
        }
    }

    private func openAsCopy(_ version: EarlierVersion) {
        guard !working else { return }
        working = true
        Task {
            let result = await model.openAsCopy(version)
            working = false
            if result.board != nil {
                showMainWindow()
                closeAll()
            } else {
                back = nil
                problem = result.problem
            }
        }
    }

    /// On the Mac the page may be in the Settings window: the board opens in the main window, which comes forward.
    private func showMainWindow() {
        #if os(macOS)
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main") == true }?.makeKeyAndOrderFront(nil)
        #endif
    }
}

// MARK: - Rows

/// One removed board: its small picture, name, what is on it, when it went and how long it is still kept.
private struct RemovedRow: View {
    let copy: RemovedCopy
    let working: Bool
    let bringBack: () -> Void
    let forGood: () -> Void

    var body: some View {
        let now = Date()
        let left = KeptRules.daysLeft(since: copy.removed, now: now)
        HStack(spacing: 9) {
            KeptThumb(board: copy.board)
                .frame(width: 50, height: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text(copy.board.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(copy.board.countLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // The last three days are said in the page's colour.
                Text(KeptRules.removedLine(removed: copy.removed, now: now))
                    .font(.caption)
                    .foregroundStyle(left <= 3 ? Part.kept.text : Color.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("kept.removedLine.\(copy.board.title)")
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Button(action: bringBack) { Text("Bring back").lineLimit(1) }
                    .buttonStyle(FilledButton(.kept))
                    .disabled(working)
                    .accessibilityIdentifier("kept.bringBack.\(copy.board.title)")
                Button(action: forGood) { Text("Remove for good").font(.caption).lineLimit(1) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .disabled(working)
                    .accessibilityIdentifier("kept.forGood.\(copy.board.title)")
            }
            .fixedSize()
        }
        .padding(.vertical, 1)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kept.removed.\(copy.board.title)")
    }
}

/// One board that has earlier versions: press it to see them.
private struct GroupRow: View {
    let group: VersionGroup
    let open: Bool
    let toggle: () -> Void

    private var state: String? {
        switch group.state {
        case .inList: return nil
        case .removed: return "removed"
        case .lost: return "not in your boards any more"
        }
    }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                ControlMarkView(.chevron, size: 13, colour: Part.kept.text)
                    .rotationEffect(.degrees(open ? 90 : 0))
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text([group.countLine, state].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("kept.board.\(group.title)")
    }
}

/// One earlier version: where it came from and its date, what is on it, and "Open as a copy".
private struct VersionRow: View {
    let version: EarlierVersion
    let title: String
    let working: Bool
    let open: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(KeptRules.sourceLine(version, now: Date()))
                    .font(Txt.label)
                    .lineLimit(2)
                Text(version.counts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: open) { Text("Open as a copy").lineLimit(1) }
                .buttonStyle(SoftButton(.kept))
                .disabled(working)
                .fixedSize()
                .accessibilityIdentifier("kept.openCopy.\(title).\(version.sourceWord)")
        }
        .padding(.leading, 21)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kept.version.\(title)")
    }
}

private extension EarlierVersion {
    /// One word for the screen tests: "daily", "away", "here" or "aside".
    var sourceWord: String {
        switch source {
        case .daily: return "daily"
        case .setAside(.away): return "away"
        case .setAside(.here): return "here"
        case .setAside(.none): return "aside"
        }
    }
}

/// A second button beside a full-colour one: the part's colour as words on its soft tint.
private struct SoftButton: ButtonStyle {
    let part: Part
    @Environment(\.isEnabled) private var enabled

    init(_ part: Part) { self.part = part }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(part.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(part.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(part.text.opacity(0.3)))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.5)
            .contentShape(Rectangle())
    }
}

/// A board as a small drawing (the whole board, fitted in), drawn by the board's own painter.
private struct KeptThumb: View {
    let board: Board
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let paint = Paint(scheme)
        Canvas { ctx, size in
            guard let all = board.bounds, all.width > 0, all.height > 0 else { return }
            let box = all.insetBy(dx: -24, dy: -24)
            let scale = min(size.width / box.width, size.height / box.height)
            var sheet = ctx
            sheet.translateBy(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)
            sheet.scaleBy(x: scale, y: scale)
            sheet.translateBy(x: -box.minX, y: -box.minY)
            var painter = BoardPainter(board: board, facts: MapFacts(board), paint: paint)
            painter.handles = false
            painter.ground = paint.canvas
            painter.draw(&sheet)
        }
        .background(paint.canvas, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(paint.edge))
        .accessibilityHidden(true)
    }
}
