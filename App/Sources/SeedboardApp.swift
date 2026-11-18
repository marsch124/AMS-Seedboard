import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Launch arguments, for pictures and tests: `-sampleData`, `-board <id>`, `-settings`.
enum LaunchOptions {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var sampleData: Bool { arguments.contains("-sampleData") }
    static var settings: Bool { arguments.contains("-settings") }

    static func value(for flag: String) -> String? {
        guard let at = arguments.firstIndex(of: flag), at + 1 < arguments.count else { return nil }
        return arguments[at + 1]
    }
}

@main
struct SeedboardApp: App {
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        #if os(macOS)
        WindowGroup("AMS Seedboard", id: "main") {
            root.frame(minWidth: 640, minHeight: 480)
        }
        .defaultSize(width: 1100, height: 760)
        // One window: no "New Window" in the File menu (`SeedMenus` fills File, Edit, View and Insert).
        .commands {
            SeedMenus(model: model)
            BoardCommands()
        }

        Settings {
            SettingsView().environmentObject(model)
        }
        #else
        WindowGroup { root }
            // With a keyboard on the iPad (or iPhone): ⌘Z, ⇧⌘Z, ⌘N, ⌘D, ⌘+, ⌘-, ⌘0, ⌘1 and the rest of
            // the menus work, and show when ⌘ is held.
            .commands {
                SeedMenus(model: model)
                BoardCommands()
            }
        #endif
    }

    private var root: some View {
        RootView()
            .environmentObject(model)
            .tint(Theme.text(.boards))
            // For pictures: `-night` shows the app by night whatever the device is set to.
            .preferredColorScheme(LaunchOptions.arguments.contains("-night") ? .dark : nil)
            .onOpenURL { model.open(url: $0) }
            // File ▸ New Board's starter choice, a board found in Spotlight, and remembering where the owner left.
            .modifier(OutsideDoors(model: model))
            // Leaving the app keeps what is being typed and writes everything at once.
            .onChange(of: phase) { _, new in
                if new != .active { model.leaving() }
            }
    }
}
