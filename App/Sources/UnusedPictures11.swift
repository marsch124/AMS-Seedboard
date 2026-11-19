import SwiftUI
import ImageIO
import SeedboardCore

// 0.11: Settings › Your boards › "Pictures nobody uses: 3 (12 MB)", with Show and Remove now.
// The safety rule is the weekly tidy's: a picture named by any open board, removed board, earlier version,
// safety copy or starter is never counted and never removed; in any doubt (something unreadable, still in
// iCloud, a board waiting for iCloud) nothing is counted and nothing goes. Rules: `PictureKeeping.unusedNow`.

struct UnusedPictures: Equatable {
    var names: [String]
    var bytes: Int
}

extension PictureStore {
    /// What nobody uses right now, read fresh from the files. nil: cannot tell now (any doubt).
    @MainActor
    func unusedPictures() async -> UnusedPictures? {
        let model = AppModel.shared
        // Like the weekly pass: not while a board still waits for iCloud, and not while iCloud's folder is unknown.
        guard model.notInCloud.isEmpty, !(cloudOn && cloud == nil) else { return nil }
        var named = Set(model.boards.flatMap { $0.pictureNames })
        for entry in model.shelf.entries.values { named.formUnion(entry.board?.pictureNames ?? []) }
        let folders = [local] + [cloud].compactMap { $0 }
        let found: UnusedPictures?? = await model.store.kept { places in
            Self.scanUnused(pictures: folders, places: places, named: named)
        }
        return found ?? nil
    }

    /// Takes away what `unusedPictures()` finds NOW (never a list shown earlier). Returns how many went; nil when
    /// nothing could be decided.
    @MainActor
    func removeUnusedPictures() async -> Int? {
        guard let now = await unusedPictures() else { return nil }
        let folders = [local] + [cloud].compactMap { $0 }
        return await Task.detached(priority: .utility) {
            let fm = FileManager.default
            var gone = Set<String>()
            for folder in folders {
                for name in now.names {
                    let file = folder.appendingPathComponent(name)
                    guard fm.fileExists(atPath: file.path) else { continue }
                    var problem: NSError?
                    NSFileCoordinator().coordinate(writingItemAt: file, options: .forDeleting, error: &problem) { url in
                        if (try? fm.removeItem(at: url)) != nil { gone.insert(name) }
                    }
                }
            }
            return gone.count
        }.value
    }

    static func scanUnused(pictures folders: [URL], places: KeptPlaces, named inUse: Set<String>, now: Date = Date()) -> UnusedPictures? {
        let fm = FileManager.default
        var seen = Set<String>()
        var files: [(name: String, date: Date?, bytes: Int)] = []
        var complete = true
        for folder in folders {
            guard let list = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
                complete = false
                continue
            }
            for url in list {
                let name = url.lastPathComponent
                if PictureKeeping.stillInCloud(name) { complete = false; continue }
                if name.hasPrefix(".") || seen.contains(name) { continue }
                seen.insert(name)
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                files.append((name, values?.contentModificationDate, values?.fileSize ?? 0))
            }
        }
        guard complete else { return nil }
        let (blobs, readAll) = keptBlobs(folders: folders, places: places)
        guard readAll else { return nil }
        var named = inUse
        for file in files {
            guard let key = file.name.data(using: .utf8) else { named.insert(file.name); continue }
            if blobs.contains(where: { $0.range(of: key) != nil }) { named.insert(file.name) }
        }
        let found = PictureKeeping.unusedNow(files: files, named: named, now: now)
        return UnusedPictures(names: found.names, bytes: found.bytes)
    }

    /// A small copy of one picture file, for the "Show" page. nil when it is not here.
    func smallPicture(_ name: String) -> CGImage? {
        for folder in [local] + [cloud].compactMap({ $0 }) {
            let url = folder.appendingPathComponent(name)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { continue }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                            kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceThumbnailMaxPixelSize: 360]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) { return image }
        }
        return nil
    }
}

/// The rows in Settings › Your boards: the line, Show and Remove now.
struct UnusedPicturesRows: View {
    @State private var found: UnusedPictures?
    @State private var looking = true
    @State private var asking = false
    @State private var told: String?

    private var count: Int { found?.names.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(looking ? "Looking at the pictures…"
                 : found.map { PictureKeeping.unusedLine(count: $0.names.count, bytes: $0.bytes) }
                    ?? "Pictures nobody uses: cannot tell right now")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.unusedLine")
            if count > 0, !looking, let found {
                HStack(spacing: 14) {
                    NavigationLink("Show") { UnusedPicturesPage(names: found.names) }
                        .foregroundStyle(Part.boards.text)
                        .accessibilityIdentifier("settings.unusedShow")
                    Button("Remove now") { asking = true }
                        .buttonStyle(FilledButton(.boards))
                        .accessibilityIdentifier("settings.unusedRemove")
                }
            }
            if let told {
                Text(told)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.unusedTold")
            }
        }
        .task { await look() }
        .confirmationDialog(PictureKeeping.removeQuestion(count: count), isPresented: $asking, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task {
                    looking = true
                    let gone = await PictureStore.shared.removeUnusedPictures()
                    told = gone.map { $0 == 1 ? "1 picture removed." : "\($0) pictures removed." } ?? "Nothing was removed: Seedboard could not be sure."
                    await look()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func look() async {
        looking = true
        found = await PictureStore.shared.unusedPictures()
        looking = false
    }
}

/// "Show": the pictures nobody uses, small. Nothing here changes anything.
struct UnusedPicturesPage: View {
    let names: [String]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(names, id: \.self) { name in UnusedThumb(name: name) }
            }
            .padding(12)
        }
        .navigationTitle("Pictures nobody uses")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("unused.page")
    }
}

private struct UnusedThumb: View {
    let name: String
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task { image = await Task.detached { PictureStore.shared.smallPicture(name) }.value }
    }
}
