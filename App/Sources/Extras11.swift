import SwiftUI
import AVFoundation
import SeedboardCore
#if os(macOS)
import AppKit
#endif

// 0.11, lane "extras": the soft tick sound (41) and the Mac's "Open Recent" (43). The rules are in SeedboardCore, Extras11.swift.

/// A soft two-note "pling" when a to-do box or a tick-list line is ticked. Made in code, no sound files. It follows the
/// silent switch and never stops music that is playing (the "ambient" kind of sound).
enum TickSound {
    static let defaultsKey = "tickSound"
    /// On at first on the iPhone and iPad, off on the Mac; then as switched in Settings (remembered per device).
    static var isOn: Bool {
        #if os(macOS)
        let fallback = false
        #else
        let fallback = true
        #endif
        return UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? fallback
    }

    private static var players: [AVAudioPlayer] = []
    private static let data = wav()

    @MainActor static func play() {
        // Not while the app runs screen tests or pictures.
        guard isOn, !LaunchOptions.sampleData, !LaunchOptions.arguments.contains("-uiTesting") else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        guard let p = try? AVAudioPlayer(data: data) else { return }
        p.volume = 0.5
        players.removeAll { !$0.isPlaying }
        players.append(p)
        p.play()
    }

    /// Two bell notes: (start seconds, frequency, length seconds).
    private static let notes: [(Double, Double, Double)] = [(0, 1318.5, 0.32), (0.07, 1975.5, 0.30)]

    /// A 16-bit mono WAV file in memory.
    static func wav() -> Data {
        let rate = 44_100.0
        let total = (notes.map { $0.0 + $0.2 }.max() ?? 0.4) + 0.02
        let count = Int(total * rate)
        var samples = [Double](repeating: 0, count: count)
        for (start, freq, length) in notes {
            let s0 = Int(start * rate), n = Int(length * rate)
            for i in 0..<n where s0 + i < count {
                let t = Double(i) / rate
                let attack = min(1, t / 0.004)
                let env = attack * exp(-t * 9 / length)
                samples[s0 + i] += (sin(2 * .pi * freq * t) + 0.25 * sin(2 * .pi * freq * 2 * t)) * env * 0.32
            }
        }
        var pcm = Data(capacity: count * 2)
        for s in samples {
            var v = Int16(max(-1, min(1, s)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &v) { pcm.append(contentsOf: $0) }
        }
        func u32(_ x: UInt32) -> Data { withUnsafeBytes(of: x.littleEndian) { Data($0) } }
        func u16(_ x: UInt16) -> Data { withUnsafeBytes(of: x.littleEndian) { Data($0) } }
        var d = Data("RIFF".utf8)
        d += u32(UInt32(36 + pcm.count)); d += Data("WAVE".utf8)
        d += Data("fmt ".utf8); d += u32(16); d += u16(1); d += u16(1)
        d += u32(UInt32(rate)); d += u32(UInt32(rate) * 2); d += u16(2); d += u16(16)
        d += Data("data".utf8); d += u32(UInt32(pcm.count)); d += pcm
        return d
    }
}

/// 0.11, pick 33: "Main branches only" / "Open all" on the middle of a mind map.
extension BoardSession {
    func toggleMainBranches(_ centre: UUID) {
        guard !readOnly, !board.placesItself, board.canFoldToMainBranches(centre) else { return }
        commitEdit()
        change { $0.toggleMainBranchesOnly(centre) }
    }
}

extension BarActions {
    /// The word of the button: pressed once the map shows its main branches only, pressed again it opens all.
    func mainBranchesAction(_ centre: Item) -> BarAction? {
        guard session.board.canFoldToMainBranches(centre.id) else { return nil }
        let only = session.board.showsMainBranchesOnly(centre.id)
        return act("mainBranches", only ? "Open all" : "Main branches only", .control(.chevron), show: .wideWord, on: only, drop: 3) {
            session.toggleMainBranches(centre.id)
        }
    }
}

/// Settings ▸ Sounds: the "Tick sound" switch.
struct SoundsSection: View {
    @AppStorage(TickSound.defaultsKey) private var on = TickSound.isOn

    var body: some View {
        Section {
            Toggle("Tick sound", isOn: $on)
                .tint(Part.boards.text)
                .accessibilityIdentifier("settings.tickSound")
        } header: { PartHeader("Sounds", .boards) }
        footer: {
            Text("A soft tick when you tick a to-do box or a line of a tick list. It follows the silent switch and never stops your music.")
        }
    }
}

#if os(macOS)
/// The Mac's list of the boards opened last (File ▸ Open Recent and the Dock menu): the ids are kept in this device's
/// settings (`Remembered.recent`, never synced).
@MainActor
enum RecentDesk {
    static func boards() -> [Board] {
        RecentBoards.shown(Remember.shared.recent, among: AppModel.shared.boards)
    }
}

/// File ▸ Open Recent: the last five boards opened, newest first.
struct OpenRecentMenu: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var remember = Remember.shared

    var body: some View {
        let list = model.loaded ? RecentBoards.shown(remember.recent, among: model.boards) : []
        Menu("Open Recent") {
            ForEach(list, id: \.id) { board in
                Button(board.title.isEmpty ? "Untitled" : board.title) {
                    if let url = URL(string: ParagonExport.boardLink(board.id)) { model.open(url: url) }
                }
            }
        }
        .disabled(list.isEmpty)
    }
}
#endif
