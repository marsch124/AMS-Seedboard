import SwiftUI
import SeedboardCore
#if os(iOS)
import UIKit
#endif

// 0.19, the pencil and pictures lane: the names of Apple's own symbols the lane uses, the one switch for
// the Camera tile, and the small device-only memories (the hold tip).

/// Apple's own symbols (SF Symbols) used by 0.19's pencil and picture picks. One place, so a name can be swapped.
enum Marks19 {
    /// The Camera tile in the tool row (iPhone and iPad).
    static let camera = "camera"
    /// The picture menu line "Round" (when the picture is a rectangle) and "Square" (when it is round).
    static let round = "circle"
    static let square = "square"
    /// The picture menu line "Print Frame".
    static let printFrame = "photo.artframe"
}

/// Pick 41: the direct Camera tile next to the Picture tile. false: the tile is gone and the camera is only
/// behind holding the Picture tile, as before 0.19.
enum CameraTile19 {
    static let shown = true
}

/// Pick 38 and 39: small things kept on this device only (never in a board, never in iCloud).
enum Pencil19 {
    private static let tipKey = "ink.holdTip"
    /// The tip shows in the Draw plate until a shape has snapped once, or the plate has opened three times.
    private static let tipTimes = 3

    static var showHoldTip: Bool {
        guard !LaunchOptions.sampleData else { return true }
        let n = UserDefaults.standard.integer(forKey: tipKey)
        return n >= 0 && n < tipTimes
    }

    /// The plate showed the tip once more.
    static func tipSeen() {
        guard !LaunchOptions.sampleData else { return }
        let n = UserDefaults.standard.integer(forKey: tipKey)
        if n >= 0 { UserDefaults.standard.set(n + 1, forKey: tipKey) }
    }

    /// A line was just made neat: the tip has done its work.
    static func noteSnap() {
        guard !LaunchOptions.sampleData else { return }
        UserDefaults.standard.set(-1, forKey: tipKey)
    }
}

/// Pick 41: the Camera tile. iPhone and iPad with a camera only; it opens the same camera as "Take a photo" in the
/// plate that opens when the Picture tile is held (PictureWays.swift), and the photo lands on the board like any picture.
struct CameraTool: View {
    @ObservedObject var session: BoardSession
    @Environment(\.toolSide) private var side

    var body: some View {
        #if os(iOS)
        if CameraTile19.shown && UIImagePickerController.isSourceTypeAvailable(.camera) {
            CameraTile(session: session, side: side)
        }
        #endif
    }
}

#if os(iOS)
private struct CameraTile: View {
    @ObservedObject var session: BoardSession
    let side: CGFloat
    @State private var open = false

    var body: some View {
        Button {
            guard !session.readOnly, !session.board.placesItself else {
                AppModel.shared.say("A picture cannot be put on this board.", tone: .problem)
                return
            }
            session.commitEdit()
            open = true
        } label: {
            GlyphView(glyph: .symbol(Marks19.camera), size: ToolSize.mark(side), colour: Part.pictures.text)
                .frame(width: side, height: side)
                .background(Part.pictures.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .pressRoom(3, 3)
        }
        .buttonStyle(PressStyle(tint: Part.pictures.text))
        .accessibilityLabel("Camera")
        .accessibilityIdentifier("tool.camera")
        .fullScreenCover(isPresented: $open, onDismiss: { session.takeKeys() }) {
            CameraPage { photo in
                open = false
                if let photo { session.lay(pictures: [photo]) }
            }
            .ignoresSafeArea()
            .background(Color.black)
        }
    }
}
#endif

extension BoardSession {
    /// Pick 40: the picture is cut round, or a rectangle again. One step for Undo.
    func setRound(_ id: UUID, _ round: Bool) {
        guard !readOnly else { return }
        commitEdit()
        change { _ = $0.setPictureRound(id, round) }
    }

    /// Pick 42: the picture in a print frame, or without. One step for Undo.
    func setPrintFrame(_ id: UUID, _ on: Bool) {
        guard !readOnly else { return }
        commitEdit()
        change { _ = $0.setPrintFrame(id, on) }
    }
}
