import SwiftUI
import SeedboardCore
#if os(iOS)
import UIKit
import ObjectiveC
#endif

// 0.5: a long press on the app's icon (iPhone and iPad) shows New board, New mind map, New board from the
// clipboard and the first two pinned boards. Each line is a link the app follows like any other
// (`AppModel.open(url:)`): `seedboard://new/<starter id>`, `seedboard://new/clipboard`, `seedboard://board/<id>`.
// The rules — which lines, which links, what a link makes — are in SeedboardCore (QuickStart.swift).

extension AppModel {
    /// `seedboard://new/<starter id>` makes a fresh board from that starter and opens it; `seedboard://new/clipboard`
    /// makes one from the words on the clipboard. True: the link was one of these (and is being followed).
    /// A link that arrives while the app is still starting waits until the boards are read.
    func openNew(url: URL) -> Bool {
        guard let ask = NewLink.ask(from: url) else { return false }
        Task { @MainActor in
            await whenLoaded()
            // The starters are read again first, so the owner's own version of a starter is the one that is used
            // (the link may be the very thing that started the app).
            await loadStarters()
            let words = ask == .clipboard ? clipboardText() : nil
            let made = NewLink.board(for: ask, shelf: shelf, clipboard: words)
            add(made.board)
            if let line = made.line { say(line) }
        }
        return true
    }
}

#if os(iOS)
extension QuickAction.Mark {
    /// The hand-drawn mark as a small template picture in the app's pictures (Assets.xcassets): the icon's
    /// menu can only show a picture that is part of the app. Each is the library's drawing, 30 points in a
    /// 35-point square: `add` = the plus, `mindMap`, `paste`, `board` = the board with the sprout.
    var picture: String {
        switch self {
        case .add: return "QuickAdd"
        case .mindMap: return "QuickMindMap"
        case .paste: return "QuickPaste"
        case .board: return "QuickBoard"
        }
    }
}

/// The menu of the app's icon: what it shows, and following the line that was pressed.
@MainActor
enum IconMenu {
    static let type = "com.schabbauer.AMSSeedboard.line"
    private static let linkKey = "link"
    private static var last: (link: String, when: Date)?

    /// Tells the device the lines of the menu. Called when the boards are read and whenever the app is left,
    /// so the two pinned boards are the ones pinned now. With made-up boards (`-sampleData`: pictures and
    /// tests) only the three ways to begin are shown, never a made-up board.
    static func refresh() {
        let model = AppModel.shared
        guard model.loaded else { return }
        let lines = QuickActions.list(pinned: LaunchOptions.sampleData ? [] : model.pinned)
        UIApplication.shared.shortcutItems = lines.map { line in
            UIApplicationShortcutItem(type: type, localizedTitle: line.title, localizedSubtitle: line.subtitle,
                                      icon: UIApplicationShortcutIcon(templateImageName: line.mark.picture),
                                      userInfo: [linkKey: line.link as NSString])
        }
    }

    /// Follows the line that was pressed. The same press is never followed twice (a cold start may tell of it
    /// in two places).
    @discardableResult
    static func follow(_ item: UIApplicationShortcutItem) -> Bool {
        guard let link = item.userInfo?[linkKey] as? String, let url = URL(string: link) else { return false }
        if let last, last.link == link, Date().timeIntervalSince(last.when) < 2 { return true }
        last = (link, Date())
        AppModel.shared.open(url: url)
        return true
    }
}

/// The app's delegate (iPhone and iPad), only for the icon's menu: SwiftUI has no way of its own to hear of it.
final class SeedAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let centre = NotificationCenter.default
        // Leaving the app: the menu learns which boards are pinned now.
        centre.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { IconMenu.refresh() }
        }
        // A window that was kept from before this version has no `SeedSceneDelegate` (the device remembers a
        // window's set-up): its own delegate is taught to pass the pressed line on.
        centre.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { note in
            MainActor.assumeIsolated { SeedSceneDelegate.teach((note.object as? UIScene)?.delegate) }
        }
        Task { @MainActor in
            await AppModel.shared.whenLoaded()
            IconMenu.refresh()
        }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // The app was started by a line of the icon's menu.
        if let item = options.shortcutItem { IconMenu.follow(item) }
        let set = UISceneConfiguration(name: connectingSceneSession.configuration.name, sessionRole: connectingSceneSession.role)
        set.delegateClass = SeedSceneDelegate.self
        return set
    }
}

/// The window's delegate, only for the icon's menu.
final class SeedSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem { IconMenu.follow(item) }
    }

    /// A line of the icon's menu was pressed while the app was already running.
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(IconMenu.follow(shortcutItem))
    }

    /// A window's delegate that does not hear of a pressed line (see `SeedAppDelegate`) is given the one method
    /// that does. Nothing is replaced: a delegate that already answers is left alone.
    @MainActor
    static func teach(_ delegate: UISceneDelegate?) {
        let pressed = #selector(UIWindowSceneDelegate.windowScene(_:performActionFor:completionHandler:))
        guard let delegate = delegate as? NSObject, !delegate.responds(to: pressed) else { return }
        let body: @convention(block) (AnyObject, UIWindowScene, UIApplicationShortcutItem, @escaping (Bool) -> Void) -> Void = { _, _, item, done in
            MainActor.assumeIsolated { done(IconMenu.follow(item)) }
        }
        class_addMethod(type(of: delegate), pressed, imp_implementationWithBlock(body), "v@:@@@?")
    }
}
#endif
