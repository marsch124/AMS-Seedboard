import SwiftUI
import SeedboardCore
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The board as a picture (always the day look, on white), for PARAGON and for sharing.
@MainActor
enum BoardPicture {
    /// `fromFiles` (Share): the pictures on the board are read from their stored files for this one drawing
    /// and are not kept in memory afterwards (BoardPaper.swift).
    static func png(of board: Board, fromFiles: Bool = false) -> Data? {
        var fitted = board
        Lettering.fit(&fitted, facts: MapFacts(board))
        let facts = MapFacts(fitted)
        guard let all = fitted.bounds else { return nil }
        let box = all.insetBy(dx: -40, dy: -40)
        let paint = Paint(night: false)
        let view = Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var sheet = ctx
            sheet.translateBy(x: -box.minX, y: -box.minY)
            var painter = BoardPainter(board: fitted, facts: facts, paint: paint)
            painter.handles = false
            painter.todoStates = TodoMark.marks(for: fitted)
            painter.ground = .white
            painter.draw(&sheet)
        }
        .frame(width: box.width, height: box.height)
        .environment(\.colorScheme, .light)

        if fromFiles { PaperPictures.begin() }
        defer { if fromFiles { PaperPictures.end() } }
        let renderer = ImageRenderer(content: view)
        // Twice the size for sharp words; a very large board is kept at its plain size, and never more than
        // about 100 million pixels (0.14).
        renderer.scale = CGFloat(PictureLimit.boardScale(width: Double(box.width), height: Double(box.height)).scale)
        #if os(macOS)
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        return renderer.uiImage?.pngData()
        #endif
    }
}

extension BoardPicture {
    /// 0.14: true when the picture of this board is cut to fit the size limit (the share page says "Shown smaller").
    static func isShownSmaller(_ board: Board) -> Bool {
        guard let all = board.bounds else { return false }
        let box = all.insetBy(dx: -40, dy: -40)
        return PictureLimit.boardScale(width: Double(box.width), height: Double(box.height)).smaller
    }
}

/// The picture, made only when it is really shared.
struct BoardPNG: Transferable {
    let board: Board

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            await MainActor.run { BoardPicture.png(of: item.board) } ?? Data()
        }
        .suggestedFileName { $0.board.title + ".png" }
    }
}
