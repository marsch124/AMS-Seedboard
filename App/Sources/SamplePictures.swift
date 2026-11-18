import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SeedboardCore

// A made-up board with two pictures, for screen pictures and tests: `-sampleData -board balcony`.
// The pictures are simple calm landscapes drawn in code at launch (no photos) and written only to the temporary
// sample folder (PictureStore: in sample mode nothing else is touched). The names are fixed, so the board is the same every run.

extension Sample {
    static func balcony(now: Date = Date()) -> Board {
        let before = "sample-balcony-before.jpg", after = "sample-balcony-after.jpg"
        if let data = landscape(sky: (0.80, 0.86, 0.90), hills: [(0.62, 0.66, 0.62), (0.52, 0.58, 0.54)], sun: nil) {
            _ = PictureStore.shared.take(data, as: before)
        }
        if let data = landscape(sky: (0.98, 0.88, 0.70), hills: [(0.55, 0.72, 0.50), (0.36, 0.58, 0.40)], sun: (0.84, 0.30)) {
            _ = PictureStore.shared.take(data, as: after)
        }
        var board = Board(title: "Balcony makeover", created: now.addingTimeInterval(-86_400 * 2), changed: now.addingTimeInterval(-7_200), colour: "teal")
        let one = board.addPicture(name: before, pixelSize: CGSize(width: 1200, height: 800), centre: CGPoint(x: 0, y: 0))
        let two = board.addPicture(name: after, pixelSize: CGSize(width: 1200, height: 800), centre: CGPoint(x: 460, y: 0))
        let herbs = board.add(.note, centre: CGPoint(x: 0, y: 250), text: "Herbs along\nthe railing", colour: "green")
        let planters = board.add(.note, centre: CGPoint(x: 460, y: 250), text: "Order planters\nand a small table", colour: "yellow")
        _ = herbs
        _ = planters
        if let one, let two { board.link(from: one, to: two, text: "becomes") }
        board.changed = now.addingTimeInterval(-7_200)
        return board
    }

    /// A simple landscape as PNG bytes: sky, an optional sun, two soft hills.
    private static func landscape(sky: (Double, Double, Double), hills: [(Double, Double, Double)], sun: (Double, Double)?) -> Data? {
        let w = 1200, h = 800
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: sky.0, green: sky.1, blue: sky.2, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        if let sun {
            ctx.setFillColor(CGColor(red: 1, green: 0.96, blue: 0.80, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: sun.0 * Double(w) - 70, y: sun.1 * Double(h) - 70, width: 140, height: 140))
        }
        for (n, hill) in hills.enumerated() {
            ctx.setFillColor(CGColor(red: hill.0, green: hill.1, blue: hill.2, alpha: 1))
            let base = 330.0 - Double(n) * 120
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: base))
            path.addCurve(to: CGPoint(x: Double(w), y: base - 40), control1: CGPoint(x: 330, y: base + 190 - Double(n) * 40), control2: CGPoint(x: 800, y: base - 150))
            path.addLine(to: CGPoint(x: Double(w), y: 0))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        }
        guard let image = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}
