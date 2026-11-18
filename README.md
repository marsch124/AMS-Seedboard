# AMS Seedboard

A place to start a thought, grow it, and hand it to PARAGON. For iPhone, iPad and Mac.

What it makes: boards. Each board is an endless sheet where you can draw a mind map,
lay out a flow with shapes and arrows, and stick notes anywhere. When the board is ready,
one button sends it to PARAGON as a note, as a project, or as to-dos for the Inbox.

- A list of your boards: Pinned, Recent, and Sent to PARAGON. New board starts blank, or as a mind map, a flow, pros and cons, or a plan in steps.
- Mind maps: type an idea, Return for the next one, Tab for one under it. Fold, colour the branches, drag an idea onto another to move it. Escape while typing cancels; Return keeps the words.
- Shapes (box, round box, diamond, oval) with arrows that follow when you move a shape. A plus beside a shape makes the next one, already joined.
- Sticky notes in six colours, free text, and frames that carry what lies inside them.
- Paste a list and it becomes a mind map (⇧⌘V with a keyboard, or More).
- iPhone and iPad: a Done button above the keyboard, and Choose more to pick several things.
- Mark any box as To do. It goes to PARAGON as a task (take the tick off and tick it again to send it again).
- Send to PARAGON: the board's picture and outline as a note, branches and ideas as a project, or only the to-do boxes into the Inbox. Seedboard only adds; it never changes a note you already have.
- Every note carries a link that opens the board again in Seedboard.
- Boards live on the device and in iCloud, on all your devices. Safety copies once a day (14 days). A removed board leaves every device and is kept 30 days in a Removed folder. A board from a newer Seedboard is shown, not changed, never written over.
- Undo and Redo (120 steps), zoom 20 % to 300 % (the whole-board view never goes below 50 %), day and night colours.
- Settings has How it works and What's new (on the Mac its own window, ⌘,).
- Not in 0.1: Apple Pencil drawing, sequence diagrams, pictures on boards, shared editing.

Build:

    xcodegen generate
    swift test --package-path Core

Then open `AMSSeedboard.xcodeproj` and run the AMSSeedboard scheme. Release to TestFlight with `Tools/release.sh <build number> both` (or `ios` / `mac`).

Apple facts:

- Bundle id `com.schabbauer.AMSSeedboard`; App Store Connect app id `6836228189`.
- iCloud: `iCloud.com.schabbauer.AMSSeedboard` (the boards) and `iCloud.com.schabbauer.AMSPara` (PARAGON's notes, add-only).
- PARAGON's shared waiting list: group `group.com.schabbauer.amspara` (iPhone and iPad), `D24ENP83QQ.group.com.schabbauer.amspara` (Mac).

Where things are:

- `Core/` has the rules (Swift package SeedboardCore, no screens).
- `App/Sources/` has the screens. `Guide.swift` holds the in-app How it works and What's new.
- `Docs/SPEC.md` is the full written specification.
