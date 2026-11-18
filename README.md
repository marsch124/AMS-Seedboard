# AMS Seedboard

A place to start a thought, grow it, and hand it to PARAGON. For iPhone, iPad and Mac.

What it makes: boards. Each board is an endless sheet where you can draw a mind map,
lay out a flow with shapes and arrows, and stick notes anywhere. A Timeline board is a plan
over time, with a bar for each thing to do. When the board is ready, one button sends it to
PARAGON as a note, as a project, or as to-dos for the Inbox.

What is in 0.2:

- A home page (Mac and iPad) under the heading "Plant a seed": seven ways to start as cards with a small drawing, and your boards as cards with their picture and "Changed 2 days ago". The list at the side has Pinned, Recent and Sent to PARAGON, and a search that finds boards by their name and by the words on them.
- New board starts blank, or as a mind map, a flow, pros and cons, a plan in steps, or a timeline.
- Seedboard opens where you left: the last board, at the same zoom and spot (each device remembers its own).
- Mind maps: type an idea, Return for the next one, Tab for one under it. Fold, colour the branches, drag an idea onto another to hang it there, or between two sisters to put it in another place (also ⌘↑ and ⌘↓, or Move up and Move down). On the iPhone and iPad a bar above the keyboard has Idea under, Next idea, Out one level and Done.
- Eight shapes (Box, Round box, Oval, Diamond, Person, Document, Slanted box, Store) on one plate. A plus beside a shape, or Tab, makes the next one, already joined. The first two arrows out of a diamond say Yes and No.
- Arrows with soft corners that go round a shape in their way, stand apart on a shared side, and can be One way, Both ways, No ends, or Dashed. Drag an end to another side or another shape.
- Things fall in line while you drag (pink guide lines, a soft dot grid). Line up, Even gaps and Same size for several chosen things.
- Sticky notes in six colours, free text, and frames. A frame carries every thing whose middle is inside it, and can be split into 2 to 5 named lanes, as rows or columns.
- Timeline board: bars on days in rows, Days, Weeks and Months, a red Today line, "Comes after" arrows that push later bars along, milestones and phases.
- Paste a list and it becomes a mind map (⇧⌘V with a keyboard, or More).
- iPhone and iPad: two fingers slide and zoom at once, finger-size press areas (44 points), Choose more to pick several things; trackpad and mouse on the iPad work as on the Mac.
- Mac (and iPad with a keyboard): File, Edit, View, Insert and Board menus. ⌘0 is Actual size, ⌘1 shows the whole board. Hold Space and drag to slide the board.
- Mark any box as To do. It goes to PARAGON as a task (take the tick off and tick it again to send it again).
- Send to PARAGON: the board's picture and outline as a note, branches and ideas as a project (the To do ticks decide which ideas become tasks), or only the to-do boxes into the Inbox. One branch can be sent by itself. A timeline goes over as a project with each bar's last day as the due date and its first day in words. Seedboard only adds; it never changes a note you already have.
- Every note carries a link that opens the board again in Seedboard.
- From outside: three actions for Shortcuts, Siri, the Action button and Raycast (New board from text, New board, Open board), and the device's search (Spotlight) finds boards.
- Boards live on the device and in iCloud, on all your devices. Safety copies once a day (14 days). A removed board leaves every device and is kept 30 days; Settings has "Removed and earlier versions" with Bring back and Open as a copy. When two devices change the same board, the newer change stays, the other is kept, and a line says so.
- Export all boards as one packed file (each board as a Seedboard file and as a text outline); Import boards adds them as new boards.
- A board from a newer Seedboard is shown, not changed, never written over. Boards changed by 0.2 are stored in format 2: Seedboard 0.1 shows them but cannot change them.
- Undo and Redo (120 steps), zoom 20 % to 300 %, day and night colours.
- Settings has How it works and What's new (on the Mac its own window, ⌘,).
- Also in 0.2: Apple Pencil drawing (a Draw tool, a rubber, three thicknesses, ten colours), the "Who does what" board (a sequence diagram: people in a row, messages in order), the bar beside the chosen thing (one row on the iPhone), a right-click / press-and-hold menu on every thing, copy, cut and paste (also between boards, and dragged-in text), and a Home row in the boards list.
- Not in 0.2: find in a board, notes on ideas, pictures on boards, shared editing.

Build:

    xcodegen generate
    swift test --package-path Core

Then open `AMSSeedboard.xcodeproj` and run the AMSSeedboard scheme. Release to TestFlight with `Tools/release.sh <build number> both` (or `ios` / `mac`).

Apple facts:

- Bundle id `com.schabbauer.AMSSeedboard`; App Store Connect app id `6836228189`.
- iCloud: `iCloud.com.schabbauer.AMSSeedboard` (the boards) and `iCloud.com.schabbauer.AMSPara` (PARAGON's notes, add-only).
- PARAGON's shared waiting list: group `group.com.schabbauer.amspara` (iPhone and iPad), `D24ENP83QQ.group.com.schabbauer.amspara` (Mac).

Where things are:

- `Core/` has the rules (Swift package SeedboardCore, no screens; 222 data tests).
- `App/Sources/` has the screens. `Guide.swift` holds the in-app How it works and What's new.
- `UITests/` has the screen tests, one file for each new screen.
- `Docs/SPEC.md` is the full written specification. `Docs/PANEL-0.2.md` is the expert panel's list before 0.2; `Docs/notes-0.2/` holds each builder's notes.
