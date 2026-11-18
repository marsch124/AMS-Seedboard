# AMS Seedboard

A personal thinking tool for iPhone, iPad and Mac.

- A sidebar lists your boards: pinned, recent, and those sent to PARAGON.
- Each board is an endless canvas. You can zoom and move around freely.
- Mind maps: type an idea, press Tab for a child idea, Return for the next one.
- Flowchart shapes (box, rounded box, diamond, round) joined by arrows that follow when you move a shape.
- Sticky notes in six colours, free text, and frames to group things.
- Paste a list and it becomes a mind map.
- A green "Send to PARAGON" button hands a board to your notes app: as a note, as a project, or as to-dos.
- Boards live in iCloud on all your devices, with safety copies and a "Removed" folder that keeps boards 30 days.
- On the iPhone you look at boards and jot an idea.

The rules live in `Core/` (Swift package SeedboardCore, tested with `swift test --package-path Core`).
The screens live in `App/Sources/`. Run `xcodegen generate` to make the Xcode project.
Release to TestFlight with `Tools/release.sh <build number> [ios|mac|both]`.
