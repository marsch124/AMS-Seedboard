import SwiftUI
import SeedboardCore
import ImageIO
import PDFKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 22: a board on paper. The PDF is drawn by the same painter as the board itself (`BoardPainter`),
// as lines and real letters: sharp at any size, and the words can be found and marked. White ground, the day
// look, the board's name and the date small at the top. Print… prints that PDF, one page, fitted.

/// While a board is drawn to be shared or printed (always on the main thread).
enum PaperPictures {
    /// A page for paper is being drawn: the painters leave the soft shadows out, so every shape stays a drawn
    /// line (a shadow would arrive in the PDF as a small picture made of dots).
    static var onPaper = false

    private static var open = 0
    private static var found: [String: CGImage] = [:]
    /// 0.11: the pictures of the page being drawn were read beforehand, off the main thread: nothing is read here.
    private static var preloaded = false
    /// How many pictures the last drawing read from their stored files (for the check behind `-shareTo`).
    private(set) static var read = 0

    /// From here until `end()` the pictures on a board are read from their stored files.
    static func begin() {
        if open == 0 { read = 0 }
        open += 1
    }

    static func end() {
        open = max(0, open - 1)
        if open == 0 { found = [:]; preloaded = false }
    }

    /// 0.11: the stored files of these pictures, read and unpacked off the main thread (one page's worth).
    nonisolated static func readFiles(_ names: [String]) -> [String: CGImage] {
        var out: [String: CGImage] = [:]
        for name in names {
            guard let bytes = PictureStore.shared.fileBytes(name),
                  let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { continue }
            out[name] = image
        }
        return out
    }

    /// Hands over the pictures of the page about to be drawn; the last page's are let go (`[:]` clears).
    static func use(_ images: [String: CGImage]) {
        preloaded = true
        found = images
        read += images.count
    }

    /// A picture straight from its stored file, unpacked only while it is drawn and never put into the app's
    /// memory store — so a board with many photos can be shared or printed without running out of memory.
    /// nil: nothing is being shared, or the file is not on this device (the painter then asks the store).
    static func image(_ name: String) -> CGImage? {
        guard open > 0 else { return nil }
        if let image = found[name] { return image }
        if preloaded { return nil }
        guard let bytes = PictureStore.shared.fileBytes(name),
              let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        found[name] = image
        read += 1
        return image
    }
}

extension BoardPicture {
    /// The paper of this device's region, upright (A4; Letter in the United States, Canada and Mexico).
    static var paper: CGSize { SharePlan.paper(region: Locale.current.region?.identifier) }

    /// The pages as one PDF. Each page lies upright or on its side by its own shape (a timeline always on its side).
    @MainActor
    static func pdf(of pages: [SharePage], title: String, now: Date = Date()) async -> Data? {
        let sheets = pages.compactMap { PaperSheet($0) }
        guard !sheets.isEmpty else { return nil }
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        let about = [kCGPDFContextTitle: SharePlan.nameLine(title), kCGPDFContextCreator: "AMS Seedboard"] as CFDictionary
        var first = CGRect(origin: .zero, size: paper)
        guard let pdf = CGContext(consumer: consumer, mediaBox: &first, about) else { return nil }

        PaperPictures.begin()
        PaperPictures.onPaper = true
        defer {
            PaperPictures.onPaper = false
            PaperPictures.end()
        }
        for (n, sheet) in sheets.enumerated() {
            // 0.11: only the pictures of THIS page are open; they are read off the main thread first, and the
            // screen gets a turn between the pages.
            let names = Array(Set(sheet.board.items.compactMap(\.picture)))
            let images = await Task.detached(priority: .userInitiated) { PaperPictures.readFiles(names) }.value
            PaperPictures.use(images)
            let fit = sheet.fit(on: paper)
            var box = CGRect(origin: .zero, size: fit.paper)
            let info = [kCGPDFContextMediaBox: Data(bytes: &box, count: MemoryLayout<CGRect>.size)] as CFDictionary
            pdf.beginPDFPage(info)
            // 0.14: a very large page is drawn in strips, one after the other, so its memory is not used all at once.
            let strips = PageStrips.strips(paperHeight: Double(fit.paper.height), scale: fit.scale, items: sheet.board.items.count)
            for strip in strips {
                let part = PaperPage(sheet: sheet, fit: fit, name: SharePlan.nameLine(title),
                                     date: SharePlan.dateLine(now, page: n + 1, of: sheets.count),
                                     strip: strips.count > 1 ? CGRect(x: 0, y: strip.y, width: fit.paper.width, height: strip.height) : nil)
                let renderer = ImageRenderer(content: part)
                // What cannot be a drawn line (a photo's edge, a see-through layer) is at least print-sharp.
                renderer.render(rasterizationScale: 4) { _, draw in
                    pdf.saveGState()
                    // PDF counts up from the bottom of the paper.
                    pdf.translateBy(x: 0, y: fit.paper.height - CGFloat(strip.y) - CGFloat(strip.height))
                    draw(pdf)
                    pdf.restoreGState()
                }
                if strips.count > 1 { await Task.yield() }
            }
            pdf.endPDFPage()
            PaperPictures.use([:])
            await Task.yield()
        }
        pdf.closePDF()
        return data.length > 0 ? data as Data : nil
    }

    /// True when the board's one printed page lies on its side.
    static func printsOnItsSide(_ board: Board) -> Bool {
        PaperSheet(SharePage(board: board))?.fit(on: paper).landscape ?? false
    }
}

/// One page's board, its words fitted, with the box that is drawn.
private struct PaperSheet {
    let heading: String
    let board: Board
    let facts: MapFacts
    let box: CGRect

    init?(_ page: SharePage) {
        var fitted = page.board
        Lettering.fit(&fitted, facts: MapFacts(fitted))
        guard let all = fitted.bounds else { return nil }
        heading = page.heading
        board = fitted
        facts = MapFacts(fitted)
        box = all.insetBy(dx: -CGFloat(SharePlan.air), dy: -CGFloat(SharePlan.air))
    }

    func fit(on paper: CGSize) -> PageFit {
        SharePlan.fit(content: box.size, paper: paper, alwaysLandscape: board.isTimeline, hasHeading: !heading.isEmpty)
    }
}

/// One page: white, the small line at the top (name left, date right), a frame's name as the heading, the board.
private struct PaperPage: View {
    let sheet: PaperSheet
    let fit: PageFit
    let name: String
    let date: String
    /// 0.14: only this band of the page (from the page's top) is drawn; nil = the whole page.
    var strip: CGRect?

    var body: some View {
        Canvas { ctx, _ in
            var ctx = ctx
            let size = fit.paper
            if let strip {
                ctx.translateBy(x: 0, y: -strip.minY)
            }
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            let edge = CGFloat(SharePlan.edge)
            let grey = Color(red: 0.42, green: 0.45, blue: 0.50)
            let top = edge + CGFloat(SharePlan.head) / 2 - 3
            ctx.draw(Text(name).font(.system(size: 9, weight: .semibold)).foregroundColor(grey), at: CGPoint(x: edge, y: top), anchor: .leading)
            ctx.draw(Text(date).font(.system(size: 9)).foregroundColor(grey), at: CGPoint(x: size.width - edge, y: top), anchor: .trailing)
            if !sheet.heading.isEmpty {
                let words = sheet.heading.count > 80 ? String(sheet.heading.prefix(79)) + "…" : sheet.heading
                ctx.draw(Text(words).font(.system(size: 15, weight: .semibold)).foregroundColor(Paint(night: false).ink),
                         at: CGPoint(x: edge, y: edge + CGFloat(SharePlan.head) + CGFloat(SharePlan.heading) / 2 - 2), anchor: .leading)
            }
            var page = ctx
            page.translateBy(x: fit.origin.x, y: fit.origin.y)
            page.scaleBy(x: CGFloat(fit.scale), y: CGFloat(fit.scale))
            page.translateBy(x: -sheet.box.minX, y: -sheet.box.minY)
            var painter = BoardPainter(board: sheet.board, facts: sheet.facts, paint: Paint(night: false))
            painter.handles = false
            painter.ground = .white
            painter.draw(&page)
        }
        .frame(width: fit.paper.width, height: strip?.height ?? fit.paper.height)
        .environment(\.colorScheme, .light)
    }
}

// MARK: Print…

/// File ▸ Print… (⌘P) on the Mac, "Print…" in More on iPhone and iPad (AirPrint): the whole board as its PDF,
/// one page, fitted — on its side by itself when the board is wider than tall.
@MainActor
enum BoardPrint {
    /// 0.11: the pages are made one at a time with the screen free in between, and the line "Making the pages…" shows.
    private static var making = false

    static func ask(_ session: BoardSession) {
        session.commitEdit()
        let board = session.board
        guard !board.isEmpty else {
            AppModel.shared.say("There is nothing to print yet.")
            return
        }
        guard !making else { return }
        making = true
        AppModel.shared.say("Making the pages…", seconds: 60)
        Task { @MainActor in
            // One turn of the screen first, so the line shows.
            try? await Task.sleep(nanoseconds: 40_000_000)
            defer { making = false }
            guard let pdf = await BoardPicture.pdf(of: board.sharePages(.whole), title: board.title) else {
                AppModel.shared.say("The page could not be made.", tone: .problem)
                return
            }
            AppModel.shared.flash = nil
            if !show(pdf, title: SharePlan.nameLine(board.title), onItsSide: BoardPicture.printsOnItsSide(board)) {
                AppModel.shared.say("Printing is not possible here.", tone: .problem)
            }
        }
    }

    private static func show(_ pdf: Data, title: String, onItsSide: Bool) -> Bool {
        #if os(macOS)
        guard let paper = PDFDocument(data: pdf), let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let info = NSPrintInfo.shared.copy() as? NSPrintInfo else { return false }
        info.orientation = onItsSide ? .landscape : .portrait
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = true
        guard let job = paper.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true) else { return false }
        job.jobTitle = title
        // The system's own print page, on the board's window.
        job.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        return true
        #else
        guard UIPrintInteractionController.isPrintingAvailable else { return false }
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = title
        info.orientation = onItsSide ? .landscape : .portrait
        let page = UIPrintInteractionController.shared
        page.printInfo = info
        page.printingItem = pdf
        if UIDevice.current.userInterfaceIdiom == .pad, let view = ShareShow.topController()?.view {
            // Under the More button, at the top right.
            let spot = CGRect(x: view.bounds.maxX - 150, y: view.safeAreaInsets.top + 24, width: 2, height: 2)
            page.present(from: spot, in: view, animated: true)
        } else {
            page.present(animated: true)
        }
        return true
        #endif
    }
}
