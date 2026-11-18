import SwiftUI
import UniformTypeIdentifiers
import SeedboardCore
import AMSIcons

// What picks 4 and 5 add outside their own page: the lines over the main window (a clash, a link to a
// removed board), the page as a sheet over the main window, and the rows in Settings › Your boards.

/// Put on the root view once. Shows the lines at the top and, when asked, the page
/// "Removed and earlier versions" as a sheet over the main window (also on the Mac).
struct BringBackHost: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            // The lines take their own room at the top, so they never lie over a button.
            .safeAreaInset(edge: .top, spacing: 0) { KeptBars() }
            .sheet(item: $model.keptPage) { ask in
                VStack(spacing: 0) {
                    #if os(macOS)
                    // A sheet on the Mac has no title bar: the page's name is said here.
                    Text("Removed and earlier versions")
                        .font(Txt.cardTitle)
                        .foregroundStyle(Part.kept.text)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    #endif
                    NavigationStack {
                        KeptPage(focus: ask.board, closeAll: { model.keptPage = nil })
                    }
                }
                .environmentObject(model)
                #if os(macOS)
                .frame(width: 520, height: 540)
                #endif
            }
    }
}

/// One line each: "Another device changed “Title”. …" with Show, and "This board was removed on …" with Bring back.
private struct KeptBars: View {
    @EnvironmentObject private var model: AppModel
    @State private var linkProblem: String?
    @State private var working = false

    var body: some View {
        VStack(spacing: 4) {
            if let clash = model.clash {
                // The board's name as it is now, when it is in the list.
                let title = model.boards.first { $0.id == clash.id }?.title ?? clash.title
                bar(KeptRules.clashLine(title), name: "clash", button: "Show", action: {
                    model.keptPage = KeptPageAsk(board: clash.id)
                    model.clash = nil
                }, close: { model.clash = nil })
            }
            if let link = model.removedLink {
                let over = KeptRules.daysLeft(since: link.removed, now: Date()) == 0
                let words = linkProblem ?? (BoardLink.removedLine(link.removed) + (over ? " Its 30 days are over: it cannot be brought back." : ""))
                bar(words, name: "removedLink", button: over || linkProblem != nil ? nil : "Bring back", action: {
                    bringBack(link.id)
                }, close: {
                    model.removedLink = nil
                    linkProblem = nil
                })
            }
        }
        .padding(.horizontal, model.clash != nil || model.removedLink != nil ? 8 : 0)
        .padding(.vertical, model.clash != nil || model.removedLink != nil ? 4 : 0)
        .onChange(of: model.removedLink) { _, _ in linkProblem = nil }
    }

    private func bringBack(_ id: UUID) {
        guard !working else { return }
        working = true
        Task {
            if let board = await model.bringBack(removed: id) {
                model.open(board.id)
                model.say("“\(board.title)” is back.")
            } else {
                linkProblem = "No copy of this board is left to bring back."
            }
            working = false
        }
    }

    private func bar(_ words: String, name: String, button: String?, action: @escaping () -> Void,
                     close: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(words)
                .font(Txt.label)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("\(name).words")
            if let button {
                Button(button, action: action)
                    .font(Txt.label.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.22), in: Capsule())
                    .buttonStyle(PressStyle(wash: nil))
                    .fixedSize()
                    .accessibilityIdentifier("\(name).button")
            }
            Button(action: close) {
                ControlMarkView(.close, size: 15, colour: .white)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(wash: Color.white.opacity(0.18), corner: 13))
            .accessibilityLabel("Close")
            .accessibilityIdentifier("\(name).close")
        }
        .padding(.leading, 12)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(Part.kept.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(name).notice")
    }
}

// MARK: - Settings › Your boards

/// The rows picks 4 and 5 add to Settings › Your boards: the way to "Removed and earlier versions",
/// "Export all boards" with the line that says when the last export was made, and "Import boards…".
struct KeptSettingsRows: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    /// When the last export was made on THIS device (seconds since 1970; 0 = never).
    @AppStorage("lastExport") private var lastExport: Double = 0

    @State private var working = false
    @State private var file: ZipDocument?
    @State private var fileName = ""
    @State private var showExporter = false
    @State private var exportProblem: String?
    /// 0.5: what the export packed, and which pictures it could not ("… are not on this device yet").
    @State private var exportSummary: String?
    @State private var showImporter = false
    @State private var importLine: String?

    var body: some View {
        NavigationLink {
            KeptPage(focus: nil, closeAll: { dismiss() })
        } label: {
            HStack(spacing: 7) {
                GlyphView(glyph: .new(.bringBack), size: 18, colour: Part.kept.text)
                Text("Removed and earlier versions")
            }
        }
        .accessibilityIdentifier("settings.kept")

        VStack(alignment: .leading, spacing: 4) {
            Button {
                export()
            } label: {
                HStack(spacing: 6) {
                    GlyphView(glyph: .new(.export), size: 15, colour: .white)
                    Text(working ? "Making the file…" : "Export all boards")
                }
            }
            .buttonStyle(FilledButton(.boards))
            .disabled(working || model.boards.isEmpty)
            .accessibilityIdentifier("settings.export")
            .fileExporter(isPresented: $showExporter, document: file, contentType: .zip, defaultFilename: fileName) { result in
                if case .success = result {
                    lastExport = Date().timeIntervalSince1970
                    exportProblem = nil
                }
                file = nil
            }
            Text(exportProblem ?? exportSummary ?? ExportRules.lastExportLine(lastExport > 0 ? Date(timeIntervalSince1970: lastExport) : nil, now: Date()))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.lastExport")
        }

        VStack(alignment: .leading, spacing: 4) {
            Button("Import boards…") { showImporter = true }
                .buttonStyle(.borderless)
                .foregroundStyle(Part.boards.text)
                .accessibilityIdentifier("settings.import")
                // The `.seedboard` files from an export (unpack the zip in Files or the Finder first).
                .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
                    if case let .success(files) = result { Task { importLine = await model.importBoards(files) } }
                }
            if let importLine {
                Text(importLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.importLine")
            }
        }
    }

    private func export() {
        guard !working else { return }
        working = true
        Task {
            if let made = await model.exportAllBoards() {
                file = ZipDocument(data: made.data)
                fileName = made.name
                exportSummary = made.summary
                exportProblem = nil
                showExporter = true
            } else {
                exportProblem = "The file could not be made. Nothing was changed."
            }
            working = false
        }
    }
}

/// The finished zip, handed to the system's save place (Files on iPhone and iPad, a save panel on the Mac).
struct ZipDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
