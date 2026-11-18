import SwiftUI
import SeedboardCore
import AMSIcons
#if os(macOS)
import AppKit
#endif

/// The window: the boards on the left, the open board beside them.
/// On the iPhone the list comes first and a board opens over it.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var showSettings = false
    /// The words in the search field over the list. For pictures: `-search <word>` fills it in.
    @State private var search = LaunchOptions.value(for: "-search") ?? ""
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            BoardList(showSettings: $showSettings, search: $search, phone: sizeClass == .compact) { id in
                model.open(id)
                compactColumn = .detail
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 226, max: 320)
        } detail: {
            if let session = model.session {
                BoardView(session: session)
                    .id(session.board.id)
            } else {
                // No board is open: the home page (on the iPhone the list itself is the home).
                HomeView(search: search) { id in
                    model.open(id)
                    compactColumn = .detail
                }
            }
        }
        #if !os(macOS)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(model)
        }
        #endif
        .onChange(of: model.openID) { _, new in
            compactColumn = new == nil ? .sidebar : .detail
        }
        .onAppear {
            guard LaunchOptions.settings else { return }
            #if os(macOS)
            // The Mac has its own Settings window (⌘,).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            #else
            showSettings = true
            #endif
        }
    }
}

/// The boards: Pinned, Recent, Sent to PARAGON.
struct BoardList: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showSettings: Bool
    @Binding var search: String
    /// The narrow layout (iPhone): the list is the home, so every row shows its small picture.
    var phone = false
    let open: (UUID) -> Void

    @State private var showStarters = false
    @State private var showStarterSheet = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var renaming: Board?
    @State private var newName = ""
    @State private var removing: Board?

    var body: some View {
        VStack(spacing: 0) {
            Button {
                // On the iPhone the choices come up from the bottom; a small pop-up there comes out empty.
                if sizeClass == .compact { showStarterSheet = true } else { showStarters = true }
            } label: {
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
            .sheet(isPresented: $showStarterSheet) {
                StarterPicker(wide: true) { starter in
                    showStarterSheet = false
                    open(model.newBoard(starter))
                }
                .presentationDetents(StarterPicker.sheetDetents)
            }

            SearchField(text: $search)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    section("Pinned", BoardSearch.find(search, in: model.pinned))
                    section("Recent", BoardSearch.find(search, in: model.recent))
                    section("Sent to PARAGON", BoardSearch.find(search, in: model.sent), part: .paragon)
                    if model.loaded && model.boards.isEmpty {
                        Text("No boards yet. Press New board.")
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .padding(10)
                    } else if model.loaded && BoardSearch.find(search, in: model.boards).isEmpty {
                        Text("No board has these words")
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .accessibilityIdentifier("boards.noMatch")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .accessibilityIdentifier("boards.list")

            Divider()
            HStack {
                #if os(macOS)
                SettingsLink { settingsLabel }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("boards.settings")
                #else
                Button { showSettings = true } label: { settingsLabel }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("boards.settings")
                #endif
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

    private var settingsLabel: some View {
        HStack(spacing: 5) {
            ControlMarkView(.settings, size: 17, colour: Part.boards.text)
            Text("Settings").font(Txt.label)
        }
        .contentShape(Rectangle())
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
                    .fill(paint.line(board.colour))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 0) {
                    Text(board.title)
                        .font(.body.weight(chosen ? .bold : .regular))
                        .foregroundStyle(chosen ? Part.boards.text : Color.primary)
                        .lineLimit(1)
                    Text(phone ? "\(board.changedWords()) · \(board.countLine)" : board.countLine)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if phone { RowPicture(board: board) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chosen ? Look.chosenRow : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
