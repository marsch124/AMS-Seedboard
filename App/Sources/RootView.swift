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
    #if os(macOS)
    /// 0.19: the Mac's board list can be hidden (View ▸ Hide Sidebar), kept per Mac (Mac19.swift).
    @ObservedObject private var sidebar = SidebarHabit.shared
    @State private var columns: NavigationSplitViewVisibility = SidebarHabit.shared.hidden ? .detailOnly : .all
    #else
    @State private var columns: NavigationSplitViewVisibility = .all
    #endif
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
        // 0.9: the boards that were put away.
        .sheet(isPresented: $model.showPutAway) {
            PutAwayPage { id in
                model.open(id)
                compactColumn = .detail
            }
            .environmentObject(model)
        }
        #if !os(macOS)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(model)
        }
        #endif
        #if os(macOS)
        .onChange(of: sidebar.hidden) { _, hidden in columns = hidden ? .detailOnly : .all }
        .onChange(of: columns) { _, new in sidebar.hidden = (new == .detailOnly) }
        #endif
        .boards14Host()   // 0.14: Join with… page, outline file chooser
        .orangeHost()     // 0.16: purple milestones → orange, asked once
        .onChange(of: model.openID) { _, new in
            compactColumn = new == nil ? .sidebar : .detail
        }
        // 0.5: the one line at the bottom, at the window's level while no open board is in sight to show it
        // itself (the home page, the iPhone's list) — so "Board removed. …" is seen (FeelLooks.swift).
        .overlay(alignment: .bottom) {
            WindowFlash(boardInSight: model.session != nil && !(sizeClass == .compact && compactColumn == .sidebar))
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
    @Environment(\.colorScheme) private var scheme
    @State private var renaming: Board?
    @State private var newName = ""
    @State private var removing: Board?
    /// 0.5: "5 of 13 done", read from PARAGON (EchoKeeper.swift).
    @ObservedObject private var echo = EchoKeeper.shared
    /// The iPhone's list has search and "+" at the bottom, under the thumb (`ThumbRow`).
    private var thumbRow: Bool { phone && ThumbRow.onThisDevice }
    @State private var searching = false
    /// 0.17: iPhone and iPad show the parts on coloured cards; the Mac keeps plain headings.
    private var cards: Bool {
        #if os(macOS)
        false
        #else
        true
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            // 0.17, iPad: the big green heading over "New board".
            if cards && !thumbRow { ListTitle().padding(.horizontal, 8).padding(.top, 2) }
            // On the iPhone search and "+" sit at the bottom instead (`ThumbRow`).
            if !thumbRow {
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
                StarterPicker(pick: { starter in
                    showStarters = false
                    open(model.newBoard(from: starter))
                }, close: { showStarters = false })
                .presentationCompactAdaptation(.popover)
            }
            .sheet(isPresented: $showStarterSheet) {
                StarterPicker(wide: true, pick: { starter in
                    showStarterSheet = false
                    open(model.newBoard(from: starter))
                }, close: { showStarterSheet = false })
                .presentationDetents(StarterPicker.sheetDetents)
            }

            SearchField(text: $search)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // 0.17: the big green heading and its count line (iPhone and iPad).
                    if cards && thumbRow { ListTitle() }
                    // The way back to the home page (on the iPhone the list itself is the home).
                    if !phone { homeRow }
                    // 0.13: "Still thinking about these?" — on the iPhone's list; the Mac and iPad show it on the home page.
                    if phone { NudgeRows(search: search, open: open) }
                    let firstSeeds = FeelRules.showsFirstSeeds(loaded: model.loaded, boards: model.boards.count, phone: phone)
                    // 0.17: the starters on the iPhone's list (the iPad and Mac have them on the home page).
                    if thumbRow && !firstSeeds && model.loaded && BoardSearch.words(search).isEmpty {
                        ListCard(title: "Starters", key: "starters", count: model.shelf.strip.count) {
                            ListStarters(open: open)
                        }
                    }
                    section("Pinned", key: "pinned", BoardSearch.find(search, in: model.pinned))
                    section("Recent", key: "recent", BoardSearch.find(search, in: model.recent))
                    section("Sent to PARAGON", key: "sent", BoardSearch.find(search, in: model.sent), part: .paragon)
                    // 0.9: a search also finds boards that were put away; they are marked.
                    if !BoardSearch.words(search).isEmpty {
                        section("Put away", key: "putAway", BoardSearch.find(search, in: model.putAwayBoards))
                    } else {
                        PutAwayRow()
                    }
                    if firstSeeds {
                        // 0.5: the iPhone's first start shows the starters themselves (EmptyBoard.swift).
                        FirstSeeds(open: open)
                    } else if model.loaded && model.boards.isEmpty {
                        Text(thumbRow ? "No boards yet. Press + below." : "No boards yet. Press New board.")
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

            if thumbRow { ThumbRow(search: $search, typing: $searching, open: open) }
            #if os(macOS)
            Divider()
            HStack {
                SettingsLink { settingsLabel }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("boards.settings")
                Spacer()
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("boards.version")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            #endif
        }
        .navigationTitle("Seedboard")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // 0.17: the big green heading is in the list itself; the bar holds only the gear, far right.
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            ToolbarItem(placement: .topBarTrailing) { ListGear { showSettings = true } }
        }
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

    /// "Home": closes the open board and shows the home page beside the list (Mac and iPad).
    private var homeRow: some View {
        let chosen = model.openID == nil
        return Button { model.open(nil) } label: {
            HStack(spacing: 8) {
                AppMarkView(.seedHome, size: 15, colour: Part.boards.text)
                    .frame(width: 9, alignment: .center)
                Text("Home")
                    .font(.body.weight(chosen ? .bold : .regular))
                    .foregroundStyle(chosen ? Part.boards.text : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chosen ? Look.chosenRow : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .padding(.top, 4)
        .help("The home page: starters and all your boards")
        .accessibilityIdentifier("boards.home")
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
    private func section(_ title: String, key: String, _ boards: [Board], part: Part = .boards) -> some View {
        if !boards.isEmpty {
            ListCard(title: title, key: key, count: boards.count, part: part,
                     forceOpen: !BoardSearch.words(search).isEmpty, plain: !cards) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(boards) { board in
                        row(board)
                    }
                }
                .padding(.horizontal, cards ? 2 : 0)
            }
        }
    }

    private func row(_ board: Board) -> some View {
        let chosen = model.openID == board.id
        // 0.5: the dot follows day and night, like the card beside it.
        let paint = Paint(scheme)
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
                    Text((phone ? "\(board.changedWords())\(echo.doneTail(board)) · " : "") + board.listLine(doneThings: echo.doneThings(board)) + FoundMarks.words(board, search: search))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                    DueWords(board: board)
                }
                Spacer(minLength: 0)
                if phone { RowPicture(board: board) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chosen ? Look.chosenRow : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("boards.row.\(board.title)")
        // Mac and iPad: a board dragged from the list onto the open board leaves a door to it there (DoorPage.swift).
        .modifier(DoorDrag(board: board, on: !phone))
        .modifier(BoardQuickLook(board: board))   // 0.19: Mac, hover 0.6 s
        // A tiny dot at the row's end: this board's newest change, or one of its pictures, is on this device, not in iCloud yet.
        .overlay(alignment: .trailing) {
            if model.waitsForCloud(board) {
                Circle()
                    .fill(Part.notes.text)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("Not in iCloud yet")
                    .accessibilityIdentifier("notInCloudDot")
            }
        }
        .contextMenu {
            Button("Rename…") {
                newName = board.title
                renaming = board
            }
            Button(board.pinned ? "Unpin" : "Pin to the top") { model.togglePin(board.id) }
            Button("Make a copy") { model.duplicate(board.id) }
            Boards14CardLines(board: board)   // 0.14: Join with…, Lock / Unlock
            if board.canBeChanged && !board.isPutAway { Button("Put away") { model.putAway(board.id) } }
            if board.canBeChanged {
                Button("Save as a starter…") { model.ask(.save(model.boardForStarter(board.id) ?? board)) }
            }
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
