import SwiftUI

/// Settings: Help, PARAGON, Your boards, About. One Done button closes the page; on the Mac Escape does too.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let info = Bundle.main.infoDictionary
        let number = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(number) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("How it works") { GuidePage() }
                        .accessibilityIdentifier("settings.howItWorks")
                    NavigationLink("What's new") { WhatsNewPage() }
                        .accessibilityIdentifier("settings.whatsNew")
                } header: { PartHeader("Help", .boards) }

                Section {
                    Text(model.paragonLine)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.paragonLine")
                    Button("Check again") { model.checkParagon() }
                        .buttonStyle(FilledButton(.paragon))
                        .accessibilityIdentifier("settings.checkParagon")
                } header: { PartHeader("PARAGON", .paragon) }

                Section {
                    Text(model.safetyLine)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.safetyLine")
                    if !model.notInCloud.isEmpty {
                        Text(model.notInCloud.count == 1
                             ? "1 board is not in iCloud yet. It is safe on this device."
                             : "\(model.notInCloud.count) boards are not in iCloud yet. They are safe on this device.")
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.notInCloud")
                    }
                    if let warning = model.saveWarning {
                        Text(warning)
                            .font(Txt.label)
                            .foregroundStyle(Part.notes.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.saveWarning")
                    }
                    // Removed and earlier versions, Export all boards, Import boards (BringBackBars.swift).
                    KeptSettingsRows()
                    #if os(macOS)
                    Button("Show the boards folder") { model.showBoardsFolder() }
                        .foregroundStyle(Part.boards.text)
                        .accessibilityIdentifier("settings.showFolder")
                    #endif
                } header: { PartHeader("Your boards", .boards) }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.version")
                } header: { PartHeader("About", .frames) }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(FilledButton(.boards))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        #if os(macOS)
        .frame(width: 520, height: 460)
        #endif
    }
}

struct GuidePage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Guide.guide) { part in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(part.title)
                            .font(Txt.cardTitle)
                            .foregroundStyle(Part.boards.text)
                        ForEach(part.text, id: \.self) { line in
                            Text(line).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("How it works")
        .accessibilityIdentifier("guide.page")
    }
}

struct WhatsNewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Guide.news) { release in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Version \(release.version)")
                            .font(Txt.cardTitle)
                            .foregroundStyle(Part.boards.text)
                        Text(release.date)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(release.items, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Circle().fill(Part.boards.text).frame(width: 5, height: 5)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
                                Text(item).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("What's new")
        .accessibilityIdentifier("whatsNew.page")
    }
}
