import SwiftUI
import SeedboardCore
import AMSIcons

// 0.5 (the feel lane): the one line at the bottom, how messages arrive and leave, the pointer over a card,
// the press-and-hold menu's arrival, and the tick on the Send button.

// MARK: Messages arrive and leave softly

extension AnyTransition {
    /// A message arrives by sliding up 8 points and fading in (0.18 s) and leaves by fading (0.25 s).
    /// With "Reduce Motion", in pictures and in screen tests it is simply there, and gone.
    static var message: AnyTransition {
        guard Feel.moves else { return .identity }
        return .asymmetric(insertion: AnyTransition.offset(y: 8).combined(with: .opacity).animation(.easeOut(duration: 0.18)),
                           removal: AnyTransition.opacity.animation(.easeOut(duration: 0.25)))
    }
}

extension Animation {
    /// What a place that shows messages hands to `.animation(_:value:)`, so their arriving and leaving runs.
    static var message: Animation? { Feel.moves ? .easeOut(duration: 0.18) : nil }
}

// MARK: The one line at the bottom

/// The line `AppModel.say` shows for a few seconds: green for plain news, brick red for a problem, PARAGON's
/// purple (with the send mark in front) for what went to PARAGON, and at its end the one pill it may carry
/// ("Open"). It is drawn in two places, never both at once: inside an open board, above the tools
/// (BoardView), and at the window's level when no board is in sight (RootView) — so "Board removed. …" is seen.
struct FlashLine: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let flash = model.flash {
            let action = model.flashAction
            HStack(spacing: 8) {
                if model.flashTone == .paragon {
                    AppMarkView(.send, size: 15, colour: .white)
                        .accessibilityHidden(true)
                }
                Text(flash)
                    .font(Txt.label)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("board.flash")
                if let action {
                    Button {
                        action.run()
                        model.flash = nil
                    } label: {
                        Text(action.label)
                            .font(Txt.label.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22), in: Capsule())
                            .pressRoom(0, 11)
                    }
                    .buttonStyle(PressStyle(tint: .white))
                    .accessibilityIdentifier("board.flashAction")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, action == nil ? 12 : 5)
            .padding(.vertical, action == nil ? 7 : 5)
            .background(model.flashTone.fill, in: Capsule())
            .accessibilityElement(children: .contain)
            .transition(.message)
        }
    }
}

/// The line at the window's level: shown over the home page and over the iPhone's list — wherever no open
/// board is in sight to show it itself.
struct WindowFlash: View {
    @EnvironmentObject private var model: AppModel
    /// An open board is in sight: it shows the line itself, above its tools.
    let boardInSight: Bool

    var body: some View {
        ZStack {
            if !boardInSight { FlashLine() }
        }
        .padding(.horizontal, 12)
        // Clear of the list's last row (Settings and the version) on the iPhone.
        .padding(.bottom, Finger.on ? 54 : 16)
        .animation(.message, value: model.flash)
    }
}

extension AppModel {
    /// The line after a Send that went through: PARAGON's purple, 6 seconds, and "Open" when a note was made
    /// ("Only the to-do boxes" makes none).
    func sayHandedOver(_ result: SendResult) {
        var open: FlashAction?
        // "Only the to-do boxes" hands back no note (`info` is nil): no "Open".
        if FeelRules.sendOffersOpen(madeNote: result.info != nil), let info = result.info {
            open = FlashAction(label: "Open") { [weak self] in self?.openInParagon(info) }
        }
        say(result.message, tone: .paragon, seconds: FeelRules.sendLine, action: open)
    }
}

extension AppModel {
    /// For pictures, with the made-up boards only (`-sampleData`): `-emptyBoard` opens a new empty board (the
    /// invitation), `-noBoards` starts with no board at all (the iPhone's first start), and
    /// `-say good|problem|paragon` shows the line at the bottom in that colour for a minute — the purple one
    /// with its "Open" pill. With `-board …` the line shows inside that board, without it at the window's level.
    func feelLaunch() {
        guard LaunchOptions.sampleData else { return }
        if LaunchOptions.arguments.contains("-noBoards") {
            for board in boards { remove(board.id) }
            flash = nil
        }
        if LaunchOptions.arguments.contains("-emptyBoard") { add(Board(title: "New board")) }
        switch LaunchOptions.value(for: "-say") {
        case "good": say("Board removed. It is kept for 30 days in the Removed folder.", seconds: 60)
        case "problem": say("Nothing to paste.", tone: .problem, seconds: 60)
        case "paragon": say("“Summer cabin” is in PARAGON under Projects.", tone: .paragon, seconds: 60, action: FlashAction(label: "Open") {})
        default: break
        }
    }
}

// MARK: The Send button's tick

/// What the Send button of the Send page shows: "Send", "Sending…", and for a moment after the hand-over
/// went through a white hand-drawn tick (the button keeps its width, so nothing jumps).
struct SendLabel: View {
    let busy: Bool
    let done: Bool

    var body: some View {
        ZStack {
            Text(busy ? "Sending…" : "Send").opacity(done ? 0 : 1)
            if done {
                ControlMarkView(.check, size: 18, colour: .white)
                    .transition(Feel.moves ? .scale(scale: 0.6).combined(with: .opacity) : .identity)
                    .accessibilityLabel("Sent")
                    .accessibilityIdentifier("send.done")
            }
        }
        .animation(Feel.moves ? .easeOut(duration: 0.12) : nil, value: done)
    }
}

// MARK: The pointer over a card

/// A home card notices the pointer (the Mac, an iPad's trackpad): its plate turns the edge green and deepens
/// the shadow in 0.12 s (HomeView's `CardPlate` draws both); on the iPad it also takes Apple's own lift.
struct CardPointer: ViewModifier {
    @Binding var over: Bool
    let outline: RoundedRectangle

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .contentShape(.hoverEffect, outline)
            .hoverEffect(.lift)
            #endif
            .onHover { over = $0 || PressStyle.forced == "over" }
            .onAppear { if PressStyle.forced == "over" { over = true } }
            .animation(Feel.moves ? .easeOut(duration: 0.12) : nil, value: over)
    }
}

// MARK: The press-and-hold menu arrives

/// The plate of the press-and-hold menu fades in and grows from 96 % in 0.12 s (it leaves by fading, 0.10 s:
/// `BoardMenu.close`).
struct GrowIn: ViewModifier {
    @State private var here = !Feel.moves

    func body(content: Content) -> some View {
        content
            .scaleEffect(here ? 1 : 0.96)
            .opacity(here ? 1 : 0)
            .onAppear {
                guard !here else { return }
                withAnimation(.easeOut(duration: 0.12)) { here = true }
            }
    }
}

// MARK: The Send button in the top bar

/// A button of the top bar that stands by itself, off the bar's shared glass. On the glass a full-colour
/// button is washed paler (Send's purple came out #A387EC on the iPad by night instead of #7F62C6, white on
/// it 2.9 : 1); off the glass it is drawn in exactly its own colour.
struct OffGlassItem<Content: View>: ToolbarContent {
    @ViewBuilder let content: () -> Content

    var body: some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarItem(placement: .primaryAction, content: content).sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .primaryAction, content: content)
        }
    }
}

// MARK: Plates that belong together

extension View {
    /// The shadow of the bar beside a chosen thing (black 10 %, radius 5, 2 down): the small Undo and zoom
    /// boxes wear it too, so the three plates at the bottom look alike.
    func plateShadow() -> some View { shadow(color: .black.opacity(0.10), radius: 5, y: 2) }
}
