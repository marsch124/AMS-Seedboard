import SwiftUI
import SeedboardCore
#if os(iOS)
import UIKit
import VisionKit
#endif

// 0.5, iPhone and iPad: the camera on the Picture tool. A press on the Picture tile opens Photos as before;
// HOLDING the tile (0.4 s, like the Box tile) opens a small plate "Add a picture" with three ways:
// Photos · Take a photo · Scan a page. A photo or a scan lands on the board like a picture from Photos
// (`BoardSession.lay`). The Mac has no plate: its pictures from the iPhone come through the menus.
// The words and the "12 pages at most" rule are in SeedboardCore (QuickStart.swift).

/// On the Picture tile (PictureViews.swift). Does nothing on the Mac.
struct PictureWaysHold: ViewModifier {
    @ObservedObject var session: BoardSession

    func body(content: Content) -> some View {
        #if os(iOS)
        content.modifier(PictureWaysOnTile(session: session))
        #else
        content
        #endif
    }
}

/// The press that opened the plate is not a press on the tile as well (a held button still fires when the
/// finger lifts): the tile's own action asks here first.
@MainActor
enum PictureHold {
    #if os(iOS)
    fileprivate static var held = false
    #endif

    /// True: this press opened the plate — do not open Photos too.
    static func swallow() -> Bool {
        #if os(iOS)
        if held {
            held = false
            return true
        }
        #endif
        return false
    }
}

#if os(iOS)
extension PictureWay {
    var glyph: Glyph {
        switch self {
        case .photos: return .new(.picture)
        case .camera: return .new(.camera)
        case .scan: return .new(.scan)
        }
    }
}

private struct PictureWaysOnTile: ViewModifier {
    @ObservedObject var session: BoardSession
    /// For pictures: `-plate picture` opens the plate at once.
    @State private var shown = LaunchOptions.value(for: "-plate") == "picture"
    /// The way picked from the plate: it starts when the plate has gone.
    @State private var picked: PictureWay?
    /// The camera or the scanner over the whole screen.
    @State private var page: PictureWay?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in open(held: true) })
            .accessibilityAction(named: "More ways to add a picture") { open(held: false) }
            .overlay(alignment: .bottomTrailing) {
                Button { open(held: false) } label: {
                    CornerMark()
                        .fill(Part.pictures.text)
                        .frame(width: 7, height: 7)
                        .padding(3)
                        .frame(width: 18, height: 18, alignment: .bottomTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(wash: nil))
                // On the iPhone the corner is too small for a finger: it only shows that there is more (hold the tile).
                .allowsHitTesting(UIDevice.current.userInterfaceIdiom != .phone)
                .accessibilityLabel("More ways to add a picture")
                .accessibilityIdentifier("tool.pictureWays")
            }
            .modifier(PlatePresenter(shown: $shown, edge: PlateEdge.overTile, height: 150, closed: { start() }) {
                PicturePlate(pick: { way in
                    picked = way
                    shown = false
                }, cancel: { shown = false })
            })
            .fullScreenCover(item: $page, onDismiss: { session.takeKeys() }) { way in
                Group {
                    if way == .scan {
                        ScanPage { pages, line in
                            page = nil
                            session.lay(pictures: pages)
                            if let line { AppModel.shared.say(line, tone: pages.isEmpty ? .problem : .good, seconds: 6) }
                        }
                    } else {
                        CameraPage { photo in
                            page = nil
                            if let photo { session.lay(pictures: [photo]) }
                        }
                    }
                }
                .ignoresSafeArea()
                .background(Color.black)
            }
    }

    private func open(held: Bool) {
        guard !shown, page == nil else { return }
        guard !session.readOnly, !session.board.placesItself else {
            AppModel.shared.say("A picture cannot be put on this board.", tone: .problem)
            return
        }
        session.commitEdit()
        PictureHold.held = held
        shown = true
    }

    /// The plate has gone: the way that was picked begins (none: Cancel).
    private func start() {
        PictureHold.held = false
        guard let way = picked else {
            session.takeKeys()
            return
        }
        picked = nil
        switch way {
        case .photos:
            PictureDesk.shared.ask.send(nil)
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return noCamera() }
            page = .camera
        case .scan:
            guard VNDocumentCameraViewController.isSupported else { return noCamera() }
            page = .scan
        }
    }

    private func noCamera() {
        AppModel.shared.say(PictureWay.noCamera, tone: .problem)
        session.takeKeys()
    }
}

/// The plate "Add a picture": three tiles in a row, the mark with its name under it.
struct PicturePlate: View {
    let pick: (PictureWay) -> Void
    let cancel: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlateHeading(title: "Add a picture", glyph: .new(.picture), part: .pictures, cancel: cancel)
            HStack(spacing: 6) {
                ForEach(PictureWay.allCases) { way in
                    Button { pick(way) } label: {
                        VStack(spacing: 2) {
                            GlyphView(glyph: way.glyph, size: 26, colour: Part.pictures.text)
                            Text(way.word)
                                .font(Txt.pill)
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Part.pictures.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle(wash: nil))
                    .accessibilityLabel(way.word)
                    .accessibilityIdentifier("plate.picture." + way.rawValue)
                }
            }
        }
        .padding(12)
        // A fixed width in a pop-up (the iPad); the whole width of the sheet on the iPhone.
        .frame(width: sizeClass == .compact ? nil : 320)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plate.picture")
    }
}

/// The device's camera, for one photo. `done(nil)`: Cancel.
struct CameraPage: UIViewControllerRepresentable {
    let done: (Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = UIImagePickerController()
        camera.sourceType = .camera
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ camera: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (Data?) -> Void
        init(done: @escaping (Data?) -> Void) { self.done = done }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // The photo with the way it was held (upright on the board); `PictureStore.take` scales and keeps it.
            done((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

/// The device's page scanner: it finds the paper, straightens it and gives one picture per page.
/// `done(pages, line)`: the pages that land (12 at most) and a line to say, if any. Cancel: no pages, no line.
private struct ScanPage: UIViewControllerRepresentable {
    let done: ([Data], String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([Data], String?) -> Void
        init(done: @escaping ([Data], String?) -> Void) { self.done = done }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let plan = PictureWay.pages(scanned: scan.pageCount)
            var pages: [Data] = []
            for n in 0..<plan.land {
                if let page = scan.imageOfPage(at: n).jpegData(compressionQuality: 0.9) { pages.append(page) }
            }
            done(pages, plan.line)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { done([], nil) }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            done([], "The scan did not work. Nothing was put on the board.")
        }
    }
}
#endif
