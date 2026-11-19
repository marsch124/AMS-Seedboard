import SwiftUI
import Vision
import CoreImage
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import SeedboardCore
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// 0.14, ideas 16 and 28.
//  16  "Lift out": a chosen picture's subject (a person, a plant, a thing) is cut out of its background by the
//      device (Vision's foreground mask) and laid beside the old picture as a new PNG picture. The old stays.
//  28  A PDF that is dropped, pasted or chosen: page 1 becomes a picture; with more pages a question is asked.
// The rules (counts, words) are in SeedboardCore (`PDFPages`, `LiftOut`).

// MARK: Lift out (16)

enum LiftResult {
    case made(name: String, pixels: CGSize)
    case noSubject
    case notHere
}

extension PictureStore {
    /// Cuts the subject out of the picture file `name` and keeps it as a new picture. Call it off the main thread.
    func liftSubject(of name: String) -> LiftResult {
        guard let image = fullImage(name) else { return .notHere }
        guard let cut = Self.subject(in: image), let taken = takePNG(cut) else { return .noSubject }
        return .made(name: taken.name, pixels: taken.pixels)
    }

    /// The picture with everything but its subject clear, cut to the subject's box; nil when no subject is found.
    static func subject(in image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        guard let found = request.results?.first, !found.allInstances.isEmpty,
              let buffer = try? found.generateMaskedImage(ofInstances: found.allInstances, from: handler, croppedToInstancesExtent: true)
        else { return nil }
        let ci = CIImage(cvPixelBuffer: buffer)
        guard ci.extent.width >= 1, ci.extent.height >= 1 else { return nil }
        return CIContext().createCGImage(ci, from: ci.extent)
    }
}

extension BoardSession {
    /// "Lift out": the chosen picture's subject becomes a new picture just to its right (one step for Undo).
    func liftOut(_ id: UUID) {
        guard !readOnly, !board.placesItself, let item = board.item(id), item.kind == .picture, let name = item.picture else { return }
        commitEdit()
        let remembered = item.frame
        AppModel.shared.say("Lifting the subject out…", seconds: 2)
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) { PictureStore.shared.liftSubject(of: name) }.value
            guard SafetyRules.maySave(asking: self, shown: AppModel.shared.session) else {
                AppModel.shared.say("The subject was not lifted out: the board was closed.", tone: .problem)
                return
            }
            switch result {
            case .notHere:
                AppModel.shared.say("That picture is not here yet.", tone: .problem)
            case .noSubject:
                AppModel.shared.say(LiftOut.noSubject, tone: .problem)
            case let .made(newName, pixels):
                while busy {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard SafetyRules.maySave(asking: self, shown: AppModel.shared.session) else { return }
                }
                let frame = board.item(id)?.frame ?? remembered
                let size = Board.pictureSize(forPixels: pixels)
                let at = LiftOut.centre(besideX: Double(frame.minX), y: Double(frame.minY), w: Double(frame.width),
                                        h: Double(frame.height), newWidth: Double(size.width))
                var made: UUID?
                change { made = $0.addPicture(name: newName, pixelSize: pixels, centre: CGPoint(x: at.x, y: at.y)) }
                if let made {
                    selectedLink = nil
                    selection = [made]
                    reveal(made)
                }
            }
        }
    }
}

// MARK: A PDF as pictures (28)

/// The question "This PDF has 6 pages", answered by a dialog on the board (`PictureHost`).
@MainActor
final class PDFAsk: ObservableObject {
    static let shared = PDFAsk()
    enum Answer { case first, all, cancel }

    /// More than 0: the question is on screen, for a PDF with this many pages.
    @Published var pages = 0
    private var done: ((Answer) -> Void)?

    func ask(pages: Int) async -> Answer {
        answer(.cancel)
        return await withCheckedContinuation { (next: CheckedContinuation<Answer, Never>) in
            self.pages = pages
            done = { next.resume(returning: $0) }
        }
    }

    func answer(_ answer: Answer) {
        guard let finish = done else { return }
        done = nil
        pages = 0
        finish(answer)
    }
}

enum PDFRender {
    /// How many pages the bytes hold; 0 when they are no PDF.
    static func pageCount(_ data: Data) -> Int { PDFDocument(data: data)?.pageCount ?? 0 }

    /// The first `count` pages, each as PNG bytes on white with its long side 2048 pixels. Call it off the main thread.
    static func pages(of data: Data, count: Int) -> [Data] {
        guard let doc = PDFDocument(data: data) else { return [] }
        var out: [Data] = []
        for n in 0..<min(count, doc.pageCount) {
            guard let page = doc.page(at: n), let png = png(of: page) else { continue }
            out.append(png)
        }
        return out
    }

    private static func png(of page: PDFPage) -> Data? {
        let box = page.bounds(for: .mediaBox)
        let px = PDFPages.pixels(width: Double(box.width), height: Double(box.height))
        let drawn = page.thumbnail(of: CGSize(width: px.width, height: px.height), for: .mediaBox)
        #if canImport(UIKit)
        guard let source = drawn.cgImage else { return nil }
        #else
        guard let source = drawn.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        #endif
        // On white, at exactly the wanted size (a thumbnail may come larger on a sharp screen).
        guard let ctx = CGContext(data: nil, width: px.width, height: px.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let whole = CGRect(x: 0, y: 0, width: px.width, height: px.height)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(whole)
        ctx.interpolationQuality = .high
        ctx.draw(source, in: whole)
        guard let flat = ctx.makeImage() else { return nil }
        let bytes = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, flat, nil)
        return CGImageDestinationFinalize(dest) ? bytes as Data : nil
    }
}

extension BoardSession {
    /// Pictures and PDFs together (`lay(pictures:)` hands them over): each PDF gives page 1, or — when it has more
    /// pages and "All pages" is answered — up to 20 pages laid in a row. Cancel leaves that PDF out.
    func layMixed(_ things: [Data], at point: CGPoint?) {
        Task { @MainActor in
            var all: [Data] = []
            var row = false
            var unread = 0
            for data in things {
                guard PDFPages.looksLikePDF(data) else { all.append(data); continue }
                let total = await Task.detached(priority: .userInitiated) { PDFRender.pageCount(data) }.value
                guard total > 0 else { unread += 1; continue }
                var every = false
                if PDFPages.question(pages: total) != nil {
                    switch await PDFAsk.shared.ask(pages: total) {
                    case .cancel: continue
                    case .first: every = false
                    case .all: every = true
                    }
                }
                let count = PDFPages.counted(total: total, all: every)
                let made = await Task.detached(priority: .userInitiated) { PDFRender.pages(of: data, count: count) }.value
                if made.isEmpty { unread += 1; continue }
                if every, made.count > 1 { row = true }
                if every, let line = PDFPages.cutLine(total: total) { AppModel.shared.say(line, seconds: 6) }
                all += made
            }
            if unread > 0 { AppModel.shared.say(unread == 1 ? "That PDF could not be read." : "\(unread) PDFs could not be read.", tone: .problem) }
            guard !all.isEmpty else { return }
            lay(pictures: all, at: point, row: row)
        }
    }
}

/// The question's dialog, on the board's drawing surface.
struct PDFAskDialog: ViewModifier {
    @ObservedObject var ask = PDFAsk.shared

    func body(content: Content) -> some View {
        content.confirmationDialog(PDFPages.question(pages: ask.pages) ?? "This PDF has pages",
                                   isPresented: Binding(get: { ask.pages > 0 }, set: { if !$0 { ask.answer(.cancel) } }),
                                   titleVisibility: .visible) {
            Button("Only page 1") { ask.answer(.first) }.accessibilityIdentifier("pdf.ask.first")
            Button("All pages") { ask.answer(.all) }.accessibilityIdentifier("pdf.ask.all")
            Button("Cancel", role: .cancel) { ask.answer(.cancel) }.accessibilityIdentifier("pdf.ask.cancel")
        }
    }
}
