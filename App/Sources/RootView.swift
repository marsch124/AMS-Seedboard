import SwiftUI
import SeedboardCore
import AMSIcons

/// The window: the boards on the left, the open board beside them.
/// On the iPhone the list comes first and a board opens over it.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            BoardList(showSettings: $showSettings) { id in
                model.open(id)
                compactColumn = .detail
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 226, max: 320)
        } detail: {
            if let session = model.session {
                BoardView(session: session)
                    .id(session.board.id)
            } else {
                NoBoard()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(model)
            #if os(macOS)
                .frame(width: 460, height: 520)
            #endif
        }
        .onChange(of: model.openID) { _, new in
            compactColumn = new == nil ? .sidebar : .detail
        }
        .onAppear {
            if LaunchOptions.settings { showSettings = true }
        }
    }
}

private struct NoBoard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            AppMarkView(.seedSprout, size: 46, colour: Part.boards.text)
            Text(model.loaded && model.boards.isEmpty ? "Start a thought" : "Choose a board")
                .font(Txt.big)
            Text("Every idea starts on a board.")
                .font(Txt.label)
                .foregroundStyle(.secondary)
            Button("New board") { model.newBoard(.blank) }
                .buttonStyle(FilledButton(.boards))
                .accessibilityIdentifier("empty.newBoard")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("board.none")
    }
}

/// The boards: Pinned, Recent, Sent to PARAGON.
struct BoardList: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showSettings: Bool
    let open: (UUID) -> Void

    @State private var showStarters = false
    @State private var renaming: Board?
    @State private var newName = ""
    @State private var removing: Board?

    var body: some View {
        VStack(spacing: 0) {
            Button { showStarters = true } label: {
                HStack(spacing: 6) {
                    ControlMarkView(.add, size: 15, colour: .white)
                    Text("New board")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(.boards))
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .accessibilityIdentifier("boards.new")
            .popover(isPresented: $showStarters, arrowEdge: .bottom) {
                StarterPicker { starter in
                    showStarters = false
                    open(model.newBoard(starter))
                }
                .presentationCompactAdaptation(.popover)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    section("Pinned", model.pinned)
                    section("Recent", model.recent)
                    section("Sent to PARAGON", model.sent, part: .paragon)
                    if model.loaded && model.boards.isEmpty {
                        Text("No boards yet. Press New board.")
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .padding(10)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .accessibilityIdentifier("boards.list")

            Divider()
            HStack {
                Button { showSettings = true } label: {
                    HStack(spacing: 5) {
                        ControlMarkView(.settings, size: 17, colour: Part.boards.text)
                        Text("Settings").font(Txt.label)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("boards.settings")
                Spacer()
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("boards.version")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .navigationTitle("Seedboard")
        .alert("Name of the board", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                if let board = renaming { model.rename(board.id, to: newName) }
                renaming = nil
            }
        }
        .confirmationDialog("Remove “\(removing?.title ?? "")”?",
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible) {
            Button("Remove the board", role: .destructive) {
                if let board = removing { model.remove(board.id) }
                removing = nil
            }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: {
            Text("It is kept for 30 days in the Removed folder.")
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    @ViewBuilder
    private func section(_ title: String, _ boards: [Board], part: Part = .boards) -> some View {
        if !boards.isEmpty {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .kerning(0.5)
                .foregroundStyle(part.text)
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 2)
            ForEach(boards) { board in
                row(board)
            }
        }
    }

    private func row(_ board: Board) -> some View {
        let chosen = model.openID == board.id
        let paint = Paint(night: false)
        return Button { open(board.id) } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(chosen ? Color.white : paint.line(board.colour))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 0) {
                    Text(board.title)
                        .font(.body.weight(chosen ? .semibold : .regular))
                        .lineLimit(1)
                    Text(board.countLine)
                        .font(.caption)
                        .foregroundStyle(chosen ? Color.white.opacity(0.85) : Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(chosen ? Color.white : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chosen ? Part.boards.fill : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("boards.row.\(board.title)")
        .contextMenu {
            Button("Rename…") {
                newName = board.title
                renaming = board
            }
            Button(board.pinned ? "Unpin" : "Pin to the top") { model.togglePin(board.id) }
            Button("Make a copy") { model.duplicate(board.id) }
            Menu("Colour") {
                ForEach(Palette.boards, id: \.self) { name in
                    Button(name.capitalized) { model.setColour(board.id, name) }
                }
            }
            if let sent = board.sent {
                Button("Open in PARAGON") { model.openInParagon(sent) }
            }
            Divider()
            Button("Remove…", role: .destructive) { removing = board }
        }
    }
}

/// The ways to begin a board.
private struct StarterPicker: View {
    let pick: (Starter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Start with")
                .font(.caption.weight(.bold))
                .foregroundStyle(Part.boards.text)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            ForEach(Starter.allCases) { starter in
                Button { pick(starter) } label: {
                    HStack(spacing: 9) {
                        AppMarkView(mark(starter), size: 22, colour: part(starter).text)
                            .frame(width: 34, height: 34)
                            .background(part(starter).soft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(starter.name).font(.body.weight(.medium))
                            Text(starter.hint).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("starter.\(starter.rawValue)")
            }
        }
        .padding(8)
        .frame(width: 300)
    }

    private func mark(_ starter: Starter) -> AppMark {
        switch starter {
        case .blank: return .seedBoard
        case .mindMap: return .seedMindMap
        case .flow: return .seedArrow
        case .prosCons: return .seedNote
        case .steps: return .seedBox
        }
    }

    private func part(_ starter: Starter) -> Part {
        switch starter {
        case .blank: return .boards
        case .mindMap: return .mindMap
        case .flow: return .arrows
        case .prosCons: return .notes
        case .steps: return .shapes
        }
    }
}
