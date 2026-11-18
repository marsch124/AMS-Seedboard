import SwiftUI
import SeedboardCore
import AMSIcons
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 24: the page of Share › Seedboard — what came, where it goes, Cancel and Send.
// Built into the share page's own target (AMSSeedboardShare) and into the app, where it can be looked at with
// made-up boards (`-sharePage`, debug builds) and is found by its screen test. It needs nothing of the app's
// own code: its colours are here, its marks come from the shared icon library.

/// One shared picture as the page shows it.
struct ShareInPicture: Identifiable {
    /// The picture's identity: its waiting file is `<id>.jpg`, and so is the arrival.
    let id: UUID
    let thumb: CGImage?
}

/// What the page shows and what was picked on it.
@MainActor
final class ShareInModel: ObservableObject {
    /// What was shared is still being read.
    @Published var loading = true
    /// Shared words.
    @Published var text = ""
    /// The name the sending app gives (a page's title).
    @Published var title = ""
    @Published var address: String?
    @Published var pictures: [ShareInPicture] = []
    /// Pictures that came but cannot wait in this home (the keychain).
    @Published var picturesLeftOut = 0
    /// Plain words about what could not be taken, one line each.
    @Published var problems: [String] = []
    /// The boards the app told of.
    @Published var boards: [ShareBoard] = []
    /// Where it goes: `Arrival.newBoard`, or a board's identity.
    @Published var target = Arrival.newBoard
    /// False when no place to leave things could be reached.
    @Published var hasBox = true

    /// One press of Send.
    let share = UUID()
    var onSend: ([Arrival]) -> Void = { _ in }
    var onCancel: () -> Void = {}

    /// What Send would write now.
    var arrivals: [Arrival] {
        Arrivals.made(share: share, board: target, text: text, title: title, address: address, pictures: pictures.map(\.id))
    }

    var canSend: Bool { !loading && hasBox && !arrivals.isEmpty }

    func send() {
        guard canSend else { return }
        onSend(arrivals)
    }
}

/// The page's colours: Seedboard's green for its words and its main button, and the boards' colour dots.
enum ShareInLook {
    private typealias RGB = (Double, Double, Double)

    private static func rgb(_ v: Int) -> RGB {
        (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    private static func dynamic(_ day: Int, _ night: Int, alpha: (Double, Double) = (1, 1)) -> Color {
        let d = rgb(day), n = rgb(night)
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { look in
            let dark = look.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = dark ? n : d
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: dark ? alpha.1 : alpha.0)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let c = dark ? n : d
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: dark ? alpha.1 : alpha.0)
        })
        #endif
    }

    /// Words and marks: the boards' green, lighter by night.
    static let green = dynamic(0x2E8B57, 0x5FBF8A)
    /// A full-colour button or row with white on top: the same green day and night.
    static let fill = Color(red: 0x2E / 255, green: 0x8B / 255, blue: 0x57 / 255)
    /// Behind the chosen board.
    static let chosen = dynamic(0x2E8B57, 0x5FBF8A, alpha: (0.14, 0.20))
    /// What could not be taken: the app's brick red.
    static let problem = dynamic(0xB4492B, 0xF0A183)
    /// The plate behind "what came".
    static let plate = dynamic(0xF3F5F7, 0x2B2D31)

    private static let dots: [String: (Int, Int)] = [
        "pink": (0xC0399F, 0xE58AD0), "orange": (0xE07B1A, 0xF2A45C), "teal": (0x1E9C8E, 0x5CCBBE),
        "blue": (0x3572D6, 0x7FAEF5), "purple": (0x8E55D9, 0xB99AF0), "green": (0x2E8B57, 0x5FBF8A),
        "yellow": (0xC99A0A, 0xF0C850), "red": (0xD5485C, 0xF08A98), "grey": (0x7B8794, 0xA9B4C4),
    ]

    /// A board's colour dot, by the colour's name in the board.
    static func dot(_ name: String) -> Color {
        let pair = dots[name] ?? dots["green"]!
        return dynamic(pair.0, pair.1)
    }
}

/// A row or button of the page answers a press by going a little paler.
private struct ShareInPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// The full-colour main button. Never grey: one that cannot be pressed yet is the same green, only paler.
private struct ShareInFilled: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(ShareInLook.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
            .contentShape(Rectangle())
    }
}

struct ShareInPage: View {
    @ObservedObject var model: ShareInModel

    static let later = "It is on the board the next time you open Seedboard."
    static let noPictures = "Pictures cannot be shared to Seedboard yet. Words and links can."
    static let noBox = "Seedboard cannot take things from other apps on this device yet. Open Seedboard once, then share again."

    private var pinned: [ShareBoard] { model.boards.filter(\.pinned) }
    private var recent: [ShareBoard] { model.boards.filter { !$0.pinned } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AppMarkView(.seedSprout, size: 22, colour: ShareInLook.green)
                Text("Send to Seedboard")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ShareInLook.green)
            }

            what

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    newBoard
                    if !pinned.isEmpty {
                        heading("Pinned")
                        ForEach(pinned) { row($0) }
                    }
                    if !recent.isEmpty {
                        heading("Recent")
                        ForEach(recent) { row($0) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shareIn.boards")

            ForEach(lines, id: \.self) { words in
                Text(words)
                    .font(.subheadline)
                    .foregroundStyle(ShareInLook.problem)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("shareIn.problem")
            }

            Text(ShareInPage.later)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("shareIn.later")

            HStack {
                Spacer()
                Button("Cancel") { model.onCancel() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("shareIn.cancel")
                Button("Send") { model.send() }
                    .buttonStyle(ShareInFilled())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSend)
                    .accessibilityIdentifier("shareIn.send")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .tint(ShareInLook.green)
    }

    /// What could not be taken, in plain words.
    private var lines: [String] {
        var out: [String] = []
        if !model.hasBox { out.append(ShareInPage.noBox) }
        if model.picturesLeftOut > 0 { out.append(ShareInPage.noPictures) }
        return out + model.problems
    }

    // MARK: What came

    private var what: some View {
        let arrivals = model.arrivals
        return VStack(alignment: .leading, spacing: 4) {
            if model.loading {
                HStack(spacing: 8) {
                    ProgressView()
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                    Text("Getting what you shared…").foregroundStyle(.secondary)
                }
            } else {
                Text(Arrivals.whatCame(arrivals))
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier("shareIn.what")
                if let words = preview(arrivals) {
                    Text(words)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let address = arrivals.first(where: { $0.kind == .link })?.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if !model.pictures.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(model.pictures) { thumb($0) }
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShareInLook.plate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// The first words of what came: the link's title, else the shared words.
    private func preview(_ arrivals: [Arrival]) -> String? {
        let words = arrivals.first { $0.kind != .picture && !$0.words.isEmpty }?.words ?? ""
        let line = words.split(whereSeparator: \.isNewline).prefix(2).joined(separator: " · ")
        return line.isEmpty ? nil : line
    }

    private func thumb(_ picture: ShareInPicture) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.secondary.opacity(0.12))
            if let image = picture.thumb {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        // A fine edge, so a white picture keeps its shape on the plate.
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
        .accessibilityIdentifier("shareIn.picture")
    }

    // MARK: Where it goes

    private func heading(_ words: String) -> some View {
        Text(words)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(ShareInLook.green)
            .padding(.top, 6)
            .padding(.leading, 8)
    }

    /// "New board": full colour, the first row, and the one that is picked when the page opens.
    private var newBoard: some View {
        let on = model.target == Arrival.newBoard
        return Button { model.target = Arrival.newBoard } label: {
            HStack(spacing: 9) {
                ControlMarkView(on ? .ticked : .circle, size: 20, colour: .white)
                ControlMarkView(.add, size: 16, colour: .white)
                Text("New board").font(.body.weight(.semibold)).foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(ShareInLook.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(ShareInPress())
        .focusEffectDisabled()
        .accessibilityIdentifier("shareIn.newBoard")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row(_ board: ShareBoard) -> some View {
        let on = model.target == board.id.uuidString
        return Button { model.target = board.id.uuidString } label: {
            HStack(spacing: 9) {
                ControlMarkView(on ? .ticked : .circle, size: 20, colour: on ? ShareInLook.green : .secondary)
                Circle().fill(ShareInLook.dot(board.colour)).frame(width: 10, height: 10)
                Text(board.name).font(.body).foregroundStyle(.primary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(on ? ShareInLook.chosen : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(ShareInPress())
        .focusEffectDisabled()
        .accessibilityIdentifier("shareIn.board.\(board.name)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
