import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 22: "Share…" (More, File, and "Share this…" in the menu of a thing). A small plate asks
// WHAT (Whole board · What is chosen · Each frame a page) and AS what (Picture · PDF · Words); the
// full-colour Share button makes it and opens the system's own share choice. Cancel, or Escape on the Mac,
// leaves everything as it is. The rules (what can be shared, the pages, the words) are in Core (SharePages.swift);
// the PDF and Print… are in BoardPaper.swift.

/// Asks for the Share plate from anywhere: More, the File menu, the menu of a thing.
@MainActor
final class ShareDesk: ObservableObject {
    static let shared = ShareDesk()

    /// The board whose Share plate is open (nil: none).
    @Published var board: UUID?
    /// What the plate shows chosen when it opens.
    private(set) var first = ShareWhat.whole

    func ask(_ session: BoardSession, what: ShareWhat = .whole) {
        session.commitEdit()
        guard !session.board.isEmpty else {
            AppModel.shared.say("There is nothing to share yet.")
            return
        }
        first = what
        board = session.board.id
    }
}

/// On the open board (`BoardView`): shows the Share plate when it is asked for.
struct ShareHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = ShareDesk.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { desk.board == session.board.id }, set: { if !$0 { desk.board = nil } }),
                   onDismiss: { session.takeKeys() }) {
                SharePlate(session: session, first: desk.first)
            }
            .onAppear { ShareLaunch.run(session) }
            .onDisappear { if desk.board == session.board.id { desk.board = nil } }
    }
}

/// The lines in More: "Share…" on every device, "Print…" on iPhone and iPad (the Mac has File ▸ Print…, ⌘P).
struct ShareLines: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        Button("Share…") { ShareDesk.shared.ask(session) }
            .accessibilityIdentifier("board.share")
        #if !os(macOS)
        Button("Print…") { BoardPrint.ask(session) }
            .accessibilityIdentifier("board.print")
        #endif
    }
}

/// File ▸ Print… with ⌘P (the Mac's menu bar, and an iPad with a keyboard).
struct PrintLine: View {
    let session: BoardSession?

    var body: some View {
        Button("Print…") { if let session { BoardPrint.ask(session) } }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(session?.board.isEmpty ?? true)
    }
}

@MainActor
enum ShareLine {
    /// The menu of a thing or of several (right-click, press and hold) with "Share this…" in it: it opens
    /// the Share plate at "What is chosen". It stands before "Remove", after a thin line.
    static func added(to actions: [BarAction], session: BoardSession) -> [BarAction] {
        guard !session.board.shareChoices(chosen: session.selection).filter({ $0 == .chosen }).isEmpty else { return actions }
        let line = BarAction(id: "menu.share", word: "Share this…", glyph: .new(.share),
                             kind: .press { ShareDesk.shared.ask(session, what: .chosen) }, gap: true)
        var all = actions
        if let last = all.last, case .remove = last.tone {
            all.insert(line, at: all.count - 1)
        } else {
            all.append(line)
        }
        return all
    }
}

// MARK: The plate

struct SharePlate: View {
    @ObservedObject var session: BoardSession
    let first: ShareWhat
    @Environment(\.dismiss) private var dismiss

    @State private var what = ShareWhat.whole
    @State private var form = ShareForm.picture
    @State private var busy = false
    @State private var problem: String?
    @State private var anchor = ShareAnchor.Holder()

    /// The form he shared in last, on this device ("picture", "pdf" or "words").
    private static let formKey = "share.form"

    private var choices: [ShareWhat] { session.board.shareChoices(chosen: session.selection) }

    var body: some View {
        #if os(macOS)
        page.frame(width: 400)
        #else
        ScrollView {
            page
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(440), .large])
        .modifier(FittedShare())
        #endif
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                GlyphView(glyph: .new(.share), size: 22, colour: Part.boards.text)
                Text("Share")
                    .font(Txt.big)
                    .foregroundStyle(Part.boards.text)
            }

            PartHeader("What", .boards)
            HStack(spacing: 6) {
                ForEach(choices, id: \.self) { one in
                    tile(one.word, Self.mark(of: one), on: what == one, id: "share.what.\(one.rawValue)") { what = one }
                }
                // Three places in the row, so a tile is as wide whether two or three are offered.
                ForEach(0..<max(0, 3 - choices.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity).frame(height: 1) }
            }

            PartHeader("As", .boards)
            HStack(spacing: 6) {
                ForEach(ShareForm.allCases, id: \.self) { one in
                    tile(one.word, Self.mark(of: one), on: form == one, id: "share.as.\(one.rawValue)") { form = one }
                }
            }

            Text(SharePlan.line(what, form, pages: session.board.shareFrames.count, chosen: session.selection.count))
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("share.line")
            if what == .frames, let line = SharePlan.leftOutLine(session.board.shareLeftOut) {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("share.leftOut")
            }
            if let problem {
                Text(problem)
                    .font(Txt.label)
                    .foregroundStyle(Part.kept.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("share.problem")
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("share.cancel")
                Button(busy ? "Making…" : "Share") { share() }
                    .buttonStyle(FilledButton(.boards))
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy)
                    .background(ShareAnchor(holder: anchor))
                    .accessibilityIdentifier("share.share")
            }
            .padding(.top, 4)
        }
        .padding(16)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("share.plate")
        .onAppear {
            what = choices.contains(first) ? first : .whole
            // The form he used last on this device; pictures and screen tests always start at Picture.
            if !LaunchOptions.sampleData, let word = UserDefaults.standard.string(forKey: Self.formKey), let last = ShareForm(rawValue: word) { form = last }
            // For pictures: `-shareWhat chosen|frames` and `-shareAs pdf|words` choose the tiles.
            if let word = LaunchOptions.value(for: "-shareWhat"), let wanted = ShareWhat(rawValue: word), choices.contains(wanted) { what = wanted }
            if let word = LaunchOptions.value(for: "-shareAs"), let wanted = ShareForm(rawValue: word) { form = wanted }
        }
        .onChange(of: what) { _, _ in problem = nil }
        .onChange(of: form) { _, _ in problem = nil }
    }

    private static func mark(of what: ShareWhat) -> Glyph {
        switch what {
        case .whole: return .app(.seedBoard)
        case .chosen: return .app(.seedSelectAll)
        case .frames: return .app(.seedFrame)
        }
    }

    private static func mark(of form: ShareForm) -> Glyph {
        switch form {
        case .picture: return .new(.picture)
        case .pdf: return .new(.pdf)
        case .words: return .new(.words)
        }
    }

    private func tile(_ word: String, _ glyph: Glyph, on: Bool, id: String, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            VStack(spacing: 3) {
                GlyphView(glyph: glyph, size: 20, colour: on ? Part.boards.text : .secondary)
                Text(word)
                    .font(Txt.label.weight(on ? .semibold : .regular))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: Finger.on ? 62 : 54)
            .background(on ? Part.boards.soft : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? Part.boards.text : Color.primary.opacity(0.12), lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(corner: 10))
        .accessibilityLabel(word)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private func share() {
        busy = true
        problem = nil
        let what = what, form = form
        Task { @MainActor in
            // One turn of the screen first, so "Making…" shows while a big board is drawn.
            try? await Task.sleep(nanoseconds: 40_000_000)
            let files = await ShareMaker.files(of: session.board, what: what, form: form, chosen: session.selection)
            busy = false
            guard !files.isEmpty else {
                problem = ShareMaker.problem(form)
                return
            }
            if !LaunchOptions.sampleData { UserDefaults.standard.set(form.rawValue, forKey: Self.formKey) }
            // The system's own share choice, at the Share button. Shared: the plate goes. Left: the plate stays.
            let shown = ShareShow.show(files, at: anchor) { done in
                if done { dismiss() }
            }
            if !shown { problem = "The share choice could not be opened." }
        }
    }
}

#if !os(macOS)
/// On the iPad a page is a card in the middle of the screen: it is made just as tall as what is in it.
private struct FittedShare: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.form.fitted(horizontal: false, vertical: true))
        } else {
            content
        }
    }
}
#endif

// MARK: Making what is shared

@MainActor
enum ShareMaker {
    /// Where the shared files are made: a folder of the device's own throw-away place.
    static var folder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Share", isDirectory: true)
    }

    /// Makes the files that are shared: one picture (one per frame for "Each frame a page"), one PDF, or one
    /// text file. Empty when it could not be made. `into`: another folder (for pictures of the launch words).
    static func files(of board: Board, what: ShareWhat, form: ShareForm, chosen: Set<UUID>, into place: URL? = nil) async -> [URL] {
        let folder = place ?? Self.folder
        let manager = FileManager.default
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        if place == nil { sweep(folder) }
        let part = what == .chosen ? "part" : ""
        var used: Set<String> = []
        func write(_ data: Data, _ name: String) -> URL? {
            // Two frames of one name: the second file says " 2".
            var free = name, n = 2
            while used.contains(free.lowercased()) {
                free = (name as NSString).deletingPathExtension + " \(n)." + (name as NSString).pathExtension
                n += 1
            }
            used.insert(free.lowercased())
            let file = folder.appendingPathComponent(free)
            return (try? data.write(to: file, options: .atomic)) != nil ? file : nil
        }

        switch form {
        case .picture:
            var made: [URL] = []
            for page in board.sharePages(what, chosen: chosen) {
                guard let png = BoardPicture.png(of: page.board, fromFiles: true),
                      let file = write(png, SharePlan.fileName(board.title, part: what == .frames ? page.heading : part, form: .picture)) else { return [] }
                made.append(file)
            }
            return made
        case .pdf:
            guard let pdf = await BoardPicture.pdf(of: board.sharePages(what, chosen: chosen), title: board.title),
                  let file = write(pdf, SharePlan.fileName(board.title, part: part, form: .pdf)) else { return [] }
            return [file]
        case .words:
            let words = board.shareWords(what, chosen: chosen)
            guard !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let data = (words + "\n").data(using: .utf8),
                  let file = write(data, SharePlan.fileName(board.title, part: part, form: .words)) else { return [] }
            return [file]
        }
    }

    /// What the plate says when nothing could be made.
    static func problem(_ form: ShareForm) -> String {
        switch form {
        case .picture: return "The picture could not be made."
        case .pdf: return "The PDF could not be made."
        case .words: return "There are no words to share here."
        }
    }

    /// What was shared more than an hour ago is thrown away.
    private static func sweep(_ folder: URL) {
        let manager = FileManager.default
        let old = Date().addingTimeInterval(-3600)
        for file in (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            let changed = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if changed < old { try? manager.removeItem(at: file) }
        }
    }
}

// MARK: The system's share choice

/// A place on the plate the system's share choice hangs on (the Share button).
struct ShareAnchor {
    final class Holder {
        #if os(macOS)
        weak var view: NSView?
        #else
        weak var view: UIView?
        #endif
    }

    let holder: Holder
}

#if os(macOS)
extension ShareAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        holder.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { holder.view = view }
}
#else
extension ShareAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        holder.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) { holder.view = view }
}
#endif

@MainActor
enum ShareShow {
    #if os(macOS)
    /// Tells when a way to share was picked (true) or the choice was left (false).
    private final class Watch: NSObject, NSSharingServicePickerDelegate {
        let done: (Bool) -> Void
        init(_ done: @escaping (Bool) -> Void) { self.done = done }

        func sharingServicePicker(_ picker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            let picked = service != nil
            DispatchQueue.main.async { self.done(picked) }
        }
    }

    /// The picker does not keep its watcher: the last one is kept here.
    private static var watch: Watch?
    #else
    /// The page that lies on top (a sheet over the board, when one is open).
    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return nil }
        while let over = top.presentedViewController, !over.isBeingDismissed { top = over }
        return top
    }
    #endif

    /// Opens the system's share choice for these files at the anchor. `done(true)`: something was shared.
    /// False when the choice could not be opened.
    static func show(_ files: [URL], at anchor: ShareAnchor.Holder, done: @escaping (Bool) -> Void) -> Bool {
        #if os(macOS)
        let picker = NSSharingServicePicker(items: files)
        let watcher = Watch(done)
        watch = watcher
        picker.delegate = watcher
        if let view = anchor.view, view.window != nil {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            return true
        }
        guard let view = (NSApp.keyWindow ?? NSApp.mainWindow)?.contentView else { return false }
        picker.show(relativeTo: CGRect(x: view.bounds.midX - 1, y: view.bounds.midY - 1, width: 2, height: 2), of: view, preferredEdge: .minY)
        return true
        #else
        guard let top = topController() else { return false }
        let page = UIActivityViewController(activityItems: files, applicationActivities: nil)
        page.completionWithItemsHandler = { _, completed, _, _ in done(completed) }
        if let view = anchor.view, view.window != nil {
            page.popoverPresentationController?.sourceView = view
            page.popoverPresentationController?.sourceRect = view.bounds
        } else {
            page.popoverPresentationController?.sourceView = top.view
            page.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
        }
        top.present(page, animated: true)
        return true
        #endif
    }
}

// MARK: Launch words (pictures and checks)

@MainActor
enum ShareLaunch {
    private static var used = false

    /// `-share` opens the Share plate a moment after the board is shown (`-shareWhat chosen|frames` and
    /// `-shareAs picture|pdf|words` choose its tiles; `-pick <word>` chooses a thing first). `-print` opens Print….
    /// Debug builds only: `-shareTo <folder>` makes the files of `-shareWhat` and `-shareAs` in that folder,
    /// without the share choice (to look at a PDF).
    static func run(_ session: BoardSession) {
        guard !used else { return }
        let words = LaunchOptions.arguments
        let plate = words.contains("-share"), paper = words.contains("-print")
        var folder: String?
        #if DEBUG
        folder = LaunchOptions.value(for: "-shareTo")
        #endif
        guard plate || paper || folder != nil else { return }
        used = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let choices = session.board.shareChoices(chosen: session.selection)
            let what = LaunchOptions.value(for: "-shareWhat").flatMap { ShareWhat(rawValue: $0) }.flatMap { choices.contains($0) ? $0 : nil } ?? .whole
            if let folder {
                let form = LaunchOptions.value(for: "-shareAs").flatMap { ShareForm(rawValue: $0) } ?? .pdf
                Task { @MainActor in
                let made = await ShareMaker.files(of: session.board, what: what, form: form, chosen: session.selection,
                                            into: URL(fileURLWithPath: folder, isDirectory: true))
                // Beside the files: what was made, and how many pictures came straight from their stored files.
                let note = "made: " + made.map(\.lastPathComponent).joined(separator: ", ") + "\npictures read from their stored files: \(PaperPictures.read)\n"
                try? note.write(to: URL(fileURLWithPath: folder, isDirectory: true).appendingPathComponent("made.txt"), atomically: true, encoding: .utf8)
                AppModel.shared.say(made.isEmpty ? ShareMaker.problem(form) : "Made: " + made.map(\.lastPathComponent).joined(separator: ", "),
                                    tone: made.isEmpty ? .problem : .good, seconds: 30)
                }
            } else if plate {
                ShareDesk.shared.ask(session, what: what)
            } else {
                BoardPrint.ask(session)
            }
        }
    }
}
