import SwiftUI
import SeedboardCore
import AMSIcons

// The thumb row (0.5, pick 31): on the iPhone the two things done most, Search and New board, sit at the
// BOTTOM of the boards list, under the thumb, instead of at the far top. Mac and iPad stay as they are.
// Phase 1: only behind the launch word `-thumbRow`, so the owner can compare two pictures first.

extension LaunchOptions {
    /// For pictures: `-thumbRow` shows the iPhone's list with search and "+" at the bottom.
    static var thumbRow: Bool { arguments.contains("-thumbRow") }
}

/// Search and a round full-colour "+" in one row at the bottom of the iPhone's list.
struct ThumbRow: View {
    @EnvironmentObject private var model: AppModel
    @Binding var search: String
    let open: (UUID) -> Void

    @State private var showStarters = false

    /// The height of the search field and the width of the round "+": a full finger.
    static let height: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                ThumbSearchField(text: $search)
                Button { showStarters = true } label: {
                    ControlMarkView(.add, size: 22, colour: .white)
                        .frame(width: ThumbRow.height, height: ThumbRow.height)
                }
                .buttonStyle(RoundFilledButton(.boards))
                .accessibilityLabel("New board")
                .accessibilityIdentifier("boards.new")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("boards.thumbRow")
        // On the iPhone the choices come up from the bottom, as they do from "New board" today.
        .sheet(isPresented: $showStarters) {
            StarterPicker(wide: true, pick: { starter in
                showStarters = false
                open(model.newBoard(from: starter))
            }, close: { showStarters = false })
            .presentationDetents(StarterPicker.sheetDetents)
        }
    }
}

/// The search field of the thumb row: the list's own search field, a finger tall and round at its ends.
struct ThumbSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 7) {
            GlyphView(glyph: .new(.search), size: 18, colour: Part.boards.text)
            TextField("Search boards", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                #endif
                .accessibilityLabel("Search boards")
                .accessibilityIdentifier("boards.search")
            if !text.isEmpty {
                Button { text = "" } label: {
                    ControlMarkView(.closeCircle, size: 19, colour: Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Clear the search")
                .accessibilityIdentifier("boards.searchClear")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: ThumbRow.height)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

/// A round main button in its part's full colour (never grey, never see-through when pressed).
struct RoundFilledButton: ButtonStyle {
    let part: Part
    init(_ part: Part) { self.part = part }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(part.fill, in: Circle())
            .brightness(configuration.isPressed ? -0.12 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Circle())
    }
}
