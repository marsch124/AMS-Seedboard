import SwiftUI
import Vision
import SeedboardCore

// "Make typed" (0.9, pick 36): a chosen sketch's handwriting becomes typed words. The sketch's lines are drawn
// black on white into an image, Vision reads the image (accurate, with language correction, English, Swedish and
// German) off the main thread, and the sketch becomes a Text thing at the same place (`Board.makeTyped`) — one step
// for Undo brings the sketch back. Nothing read: a short line, nothing changes. The rules are in SeedboardCore
// (InkPencil09.swift); the reading itself needs a real device or Mac to judge.

/// A picture on its way to Vision (an image is read, never changed).
private struct Page: @unchecked Sendable {
    let image: CGImage
}

enum InkWords {
    /// The sketch's ordinary lines in black on white, with room round them. nil: nothing to draw.
    @MainActor
    static func image(of item: Item) -> CGImage? {
        let lines = item.paintedStrokes.filter { !$0.isHighlighter }
        guard !lines.isEmpty, item.w > 0, item.h > 0 else { return nil }
        let room: CGFloat = 16
        let size = CGSize(width: CGFloat(item.w) + room * 2, height: CGFloat(item.h) + room * 2)
        let view = Canvas { ctx, _ in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var sheet = ctx
            sheet.translateBy(x: room, y: room)
            for stroke in lines {
                InkDraw.stroke(stroke.path(), pressure: stroke.pressure, base: max(stroke.thickness.points, 3), colour: .black, in: sheet)
            }
        }
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = CGFloat(InkText.imageScale(for: size))
        return renderer.cgImage
    }

    /// The lines of words Vision finds, top to bottom. Empty: none.
    static func read(_ image: CGImage) async -> [String] {
        let page = Page(image: image)
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let wanted = ["en-US", "sv-SE", "de-DE"]
            if let known = try? request.supportedRecognitionLanguages() {
                let have = wanted.filter { known.contains($0) }
                if !have.isEmpty { request.recognitionLanguages = have }
            }
            let handler = VNImageRequestHandler(cgImage: page.image, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }
            let found = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            return found.compactMap { $0.topCandidates(1).first?.string }
        }.value
    }
}

extension BoardSession {
    /// "Make typed": the chosen sketch becomes Text.
    func makeTyped(_ id: UUID) {
        guard !readOnly, !board.placesItself, let item = board.item(id), item.kind == .drawing else { return }
        commitEdit()
        guard let image = InkWords.image(of: item) else {
            AppModel.shared.say(InkText.noWords, tone: .problem, seconds: 4)
            return
        }
        Task { @MainActor in
            let words = InkText.clean(await InkWords.read(image))
            // The sketch may have been changed or removed while it was being read.
            guard !readOnly, let now = board.item(id), now.kind == .drawing, now.strokes == item.strokes else { return }
            guard !words.isEmpty else {
                AppModel.shared.say(InkText.noWords, tone: .problem, seconds: 4)
                return
            }
            change { _ = $0.makeTyped(id, words: words) }
            selectedLink = nil
            selection = [id]
        }
    }

    /// "Read this" (0.11, pick 31): like "Make typed", but the words come up as a sticky note beside the sketch and
    /// the sketch stays. One step for Undo takes the note away again.
    func readThis(_ id: UUID) {
        guard !readOnly, !board.placesItself, let item = board.item(id), item.kind == .drawing else { return }
        commitEdit()
        guard let image = InkWords.image(of: item) else {
            AppModel.shared.say(InkText.noWords, tone: .problem, seconds: 4)
            return
        }
        Task { @MainActor in
            let words = InkText.clean(await InkWords.read(image))
            guard !readOnly, let now = board.item(id), now.kind == .drawing, now.strokes == item.strokes else { return }
            guard !words.isEmpty else {
                AppModel.shared.say(InkText.noWords, tone: .problem, seconds: 4)
                return
            }
            var made: UUID?
            change { made = $0.addReadNote(besideDrawing: id, words: words) }
            if let made {
                selectedLink = nil
                selection = [made]
            }
        }
    }
}
