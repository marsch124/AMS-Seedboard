import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import SeedboardCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// 0.5, pick 24: Share › Seedboard, on the iPhone, the iPad and the Mac — words, a link and pictures from any
// app's Share button.
//
// It never touches a board. It leaves one line per shared thing in the waiting place (`ArrivalBox`) and, in the
// folder home, a shrunken copy of every picture beside it. The app lays them on the board the next time it is
// in front; a share page may not open its app.

#if os(iOS)
final class ShareViewController: UIViewController {
    private var reader: ShareInReader?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let reader = ShareInReader(context: extensionContext)
        self.reader = reader
        let host = UIHostingController(rootView: ShareInPage(model: reader.model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        reader.load()
    }
}
#else
final class ShareViewController: NSViewController {
    private var reader: ShareInReader?

    override func loadView() {
        let reader = ShareInReader(context: extensionContext)
        self.reader = reader
        let host = NSHostingView(rootView: ShareInPage(model: reader.model).frame(width: 420, height: 480))
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 480)
        view = host
        preferredContentSize = host.frame.size
        reader.load()
    }
}
#endif

/// Reads what was shared, keeps the pictures, and writes the lines when Send is pressed.
@MainActor
final class ShareInReader {
    let model = ShareInModel()
    private weak var context: NSExtensionContext?
    private let box: ArrivalBox?
    /// True once the lines are written: a second press on Send writes nothing more.
    private var sent = false

    init(context: NSExtensionContext?) {
        self.context = context
        box = ArrivalBox.forSharing()
        model.hasBox = box != nil
        model.boards = box?.boards() ?? []
        model.onSend = { [weak self] arrivals in self?.send(arrivals) }
        model.onCancel = { [weak self] in self?.cancel() }
    }

    // MARK: Reading what was shared

    func load() {
        let items = (context?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let name = items.first?.attributedContentText?.string ?? items.first?.attributedTitle?.string ?? ""
        let group = DispatchGroup()
        let pictureBox = box?.takesPictures == true ? box : nil
        var pictures = 0
        var tooMany = 0
        for (index, provider) in providers.enumerated() {
            let image = provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            let file = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            if image || file {
                // A picture, or a file that may be one (the Mac's Finder hands pictures over as files).
                guard let pictureBox else {
                    model.picturesLeftOut += 1
                    continue
                }
                guard pictures < Arrival.mostPictures else {
                    tooMany += 1
                    continue
                }
                pictures += 1
                group.enter()
                let id = UUID()
                if image {
                    // The file is only there while this block runs: it is shrunk and kept inside it.
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
                        let thumb = url.flatMap { ShareInReader.keep($0, id: id, in: pictureBox) }
                        DispatchQueue.main.async { self?.took(thumb, id: id, at: index); group.leave() }
                    }
                } else {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                        let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                        let reading = url?.startAccessingSecurityScopedResource() ?? false
                        let isPicture = url.flatMap { UTType(filenameExtension: $0.pathExtension) }?.conforms(to: .image) == true
                        let thumb = isPicture ? url.flatMap { ShareInReader.keep($0, id: id, in: pictureBox) } : nil
                        if reading { url?.stopAccessingSecurityScopedResource() }
                        DispatchQueue.main.async { self?.took(thumb, id: id, at: index); group.leave() }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                    let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    DispatchQueue.main.async {
                        if let url { self?.model.address = url.absoluteString }
                        group.leave()
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                    let words = (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                    DispatchQueue.main.async {
                        if let words { self?.model.text = words }
                        group.leave()
                    }
                }
            }
        }
        let leftOut = tooMany
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let model = self.model
            model.pictures = self.kept.sorted { $0.at < $1.at }.map(\.picture)
            // The sending app's own words name a link; with nothing else shared they are the words themselves.
            if model.address != nil {
                model.title = name
            } else if model.text.isEmpty, model.pictures.isEmpty, model.picturesLeftOut == 0, self.unread == 0 {
                model.text = name
            }
            if self.unread > 0 {
                model.problems.append(self.unread == 1 ? "1 thing could not be read as a picture. Seedboard takes words, links and pictures."
                                                       : "\(self.unread) things could not be read as pictures. Seedboard takes words, links and pictures.")
            }
            // 0.14: very long words are cut when they are laid on the board; the page says so.
            if Arrivals.wasCut(model.text) { model.problems.append(Arrivals.cutLine) }
            if leftOut > 0 {
                model.problems.append("Seedboard takes \(Arrival.mostPictures) pictures at a time. \(leftOut) more \(leftOut == 1 ? "was" : "were") left out.")
            }
            model.loading = false
        }
    }

    /// The pictures that were kept, with their place in what was shared; and how many could not be kept.
    private var kept: [(at: Int, picture: ShareInPicture)] = []
    private var unread = 0

    /// One picture was looked at. `.some(thumb)` = kept (its small picture may be missing); nil = it could not be kept.
    private func took(_ thumb: CGImage??, id: UUID, at index: Int) {
        if let thumb { kept.append((index, ShareInPicture(id: id, thumb: thumb))) } else { unread += 1 }
    }

    // MARK: Keeping a picture

    private nonisolated static let lock = NSLock()

    /// Shrinks a shared picture (long side 2048 at most, on white, JPEG) into the waiting folder as `<id>.jpg`,
    /// without ever opening it at full size: a share page is given little memory. One at a time.
    /// Gives back a small picture for the page (`.some(nil)` when only that could not be made); nil when the
    /// picture could not be kept.
    private nonisolated static func keep(_ url: URL, id: UUID, in box: ArrivalBox) -> CGImage?? {
        lock.lock()
        defer { lock.unlock() }
        guard let target = box.pictureFile(PictureKeeping.freshName(id)),
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 2048]
        guard let shrunk = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let flat = onWhite(shrunk),
              let out = CGImageDestinationCreateWithURL(target as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(out, flat, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(out) else {
            try? FileManager.default.removeItem(at: target)
            return nil
        }
        return .some(small(target))
    }

    /// A see-through picture is laid on white (a JPEG has no see-through parts); any other is passed on as it is.
    private nonisolated static func onWhite(_ image: CGImage) -> CGImage? {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: break
        }
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let whole = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(whole)
        ctx.draw(image, in: whole)
        return ctx.makeImage()
    }

    /// The small picture the page shows, read from the kept file.
    private nonisolated static func small(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 132]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: Send and Cancel

    private func send(_ arrivals: [Arrival]) {
        guard !sent, let box else { return }
        if box.add(arrivals) {
            sent = true
            context?.completeRequest(returningItems: nil)
        } else {
            model.problems.append("That could not be kept for Seedboard. Press Send again.")
        }
    }

    private func cancel() {
        // The pictures kept for this share are taken away again — never after Send: the lines name them.
        if !sent, let box {
            for picture in model.pictures {
                if let file = box.pictureFile(PictureKeeping.freshName(picture.id)) { try? FileManager.default.removeItem(at: file) }
            }
        }
        context?.cancelRequest(withError: NSError(domain: "AMSSeedboardShare", code: NSUserCancelledError))
    }
}
