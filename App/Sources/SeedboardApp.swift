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
    @StateObject private var model = AppModel()

    var body: some Scene {
        #if os(macOS)
        WindowGroup("AMS Seedboard", id: "main") {
            root.frame(minWidth: 640, minHeight: 480)
        }
        .defaultSize(width: 1100, height: 760)
        // One window: no "New Window" in the File menu.
        .commands {
            CommandGroup(replacing: .newItem) {}
            BoardCommands()
        }

        Settings {
            SettingsView().environmentObject(model)
        }
        #else
        WindowGroup { root }
        #endif
    }

    private var root: some View {
        RootView()
            .environmentObject(model)
            .tint(Theme.text(.boards))
            .onOpenURL { model.open(url: $0) }
    }
}
