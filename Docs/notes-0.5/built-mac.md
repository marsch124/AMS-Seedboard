# Built in the `mac` lane — pick 29, the Mac's own habits (`panel-apple-platform.md` 9)

All of it is the Mac only. iPhone and iPad change in one place only: on the iPad the board's name carries the same small menu (see 5).

## 1. Help menu (the bug)
- The Help menu no longer shows the system's "AMS Seedboard Help" (which said help is not available). It now holds two lines:
  - **How Seedboard Works** — ⌘?
  - **What's New**
- The system's search field stays at the top of the Help menu and finds menu lines by itself.
- Either line opens the guide in **a small window of its own** (460 × 640 points at first, top right of the screen; it can be made bigger, smallest 360 × 320), so it can stay open beside the board. The window's top bar says "How it works" or "What's new" (the page's own title).
- At the top of the window two plates switch between the pages: **How it works** and **What's new** (the page that shows is full green with white words, the other a soft green plate). The pages are exactly the ones in Settings ▸ Help.
- **Escape closes the window**, like every page of the app. The window has no line of its own in the Window menu (the Help menu is its home).

## 2. Dock menu
Press the Seedboard icon in the Dock long (or right-click it):
- **New Board** — brings the boards window to the front (opens it again if it was closed) and shows the starter choice, exactly like File ▸ New Board.
- a line, then **the pinned boards** (at most 10, the one changed last first),
- a line, then **the five boards changed last** that are not pinned (a board sent to PARAGON counts like any other).
- A board's line opens that board (like a link to it; a board removed meanwhile shows the usual "Bring back" line). Before the boards are loaded the menu has only New Board.

## 3. A photo, a scan or a sketch from the iPhone or iPad (Continuity Camera)
- **File ▸ Import from iPhone or iPad** ▸ for each iPhone or iPad near the Mac: **Take Photo**, **Scan Documents**, **Add Sketch** (the system's own words and steps). The system named this line "<<Import From Device - unlocalized>>" in Seedboard; it is now called "Import from iPhone or iPad".
- The same line is in the **right-click menu of empty board**, right after "Picture…": **Import from iPhone or iPad** with the same submenu. When no iPhone or iPad is near, the line is there but pale.
- Where it lands: asked for in the right-click menu → at the spot that was right-clicked, when it arrives within **2 minutes** and the same board is still open; otherwise (and from the File menu) at a free place near the middle of the view, like the Picture tool.
- A scan: **each page becomes a picture** (at most 12 pages, white ground, long side 2048 pixels — the size pictures are kept at).
- After it lands the boards window comes to the front and the board has the keys again.
- Not on a board that cannot be changed, and not on a timeline or a "Who does what" board (they hold no pictures): there the line is missing and nothing is taken.
- If what came back is not a picture: the brick-red line **"That could not be read as a picture."**

## 4. Services: New Seedboard Board from Selection
- Mark words in any app (Safari, Mail, Notes …), right-click ▸ **Services ▸ New Seedboard Board from Selection** (also in the app's menu ▸ Services).
- Seedboard comes to the front with a **new board** made the same way as the Shortcuts action: **a list becomes a mind map**, anything else **one sticky note**; the board's name is the first line.
- No words at all: no board is made; the system says **"There were no words to make a board from."**
- Trap for Martin: a new Service shows only after Seedboard was started once and the Mac re-read its services (sometimes only after logging out and in). If it is missing it can be switched on in System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Services. It is set to show without being switched on first.
- `project.yml` (and the generated `App/Config/Info.plist`): `NSServices` only.

## 5. The board's name in the top bar
- **A click on the board's name** (in the window's top bar) opens **"Name of the board"** — the same question as More ▸ Rename… (field, Cancel, Save; an empty name is refused as before). Not on a board that cannot be changed.
- **A right-click on the name** opens its small menu:
  - **Rename…** (pale on a board that cannot be changed)
  - **Pin to the top** (or **Unpin** when it is pinned)
  - **Make a copy**
  - **Save as a starter…** (not on a board that cannot be changed)
  - On a starter being changed only Rename… is there.
- The name stays the system's own title in its usual place: nothing in the top bar moved. (Tried and dropped: the system's own title menu and renaming in the top bar do not answer a click on the Mac; a name drawn by the app instead moved Undo, Redo, More and Send to PARAGON to the left.)
- A click starts the question, so a double-click on the name no longer makes the window bigger (a double-click on the empty top bar still does).
- macOS 14: the name stays plain text as in 0.4 (the Mac runs 26, so Martin gets the new behaviour).
- **iPad:** the name is the system's own title menu with the same lines (Rename…, Pin to the top / Unpin, Make a copy, Save as a starter…). **iPhone:** unchanged. The More menu is unchanged everywhere.

## 6. Space on ONE chosen picture = Quick Look
- With exactly one picture chosen, a short press of **Space** (no drag) shows the picture **at full size** in the Mac's own Quick Look window — the whole stored picture, also when it is cropped on the board.
- The window is named after the picture's caption (its first line, at most 60 letters), else **"Picture 2"** etc. by its place in reading order (rows from the top, each row from the left). Two pictures never share a name ("Cabin", "Cabin 2").
- The **arrow keys step through all the board's pictures** in that reading order. Space or Escape closes it; the board then has the keys again.
- Everything Space did before is unchanged: held with a drag it slides the board; with anything else chosen a short press starts typing. With two or more chosen, nothing chosen, or while typing, no Quick Look.
- A picture not yet on this Mac: the brick-red line **"This picture is not on this Mac yet."**
- The copies Quick Look shows are made in the Mac's temporary folder, named by caption (never by the stored picture's name), and removed when it closes.

## Launch words (for pictures)
- `-guide` — opens the guide window on "How it works"; `-whatsNew` — on "What's new".
- `-lookPicture` — with `-board <word>`: chooses the board's first picture and shows it in Quick Look (e.g. `-board Balcony -lookPicture -sampleData`).
- DEBUG only, self-checks that print to the error stream: `-macCheck` (menus, Dock menu, the camera line, a handed-over picture, the Service) and `-titleCheck` (a click and a right-click on the name).

## Identifiers
`guide.window`, `guide.tab.how`, `guide.tab.news`, `menu.camera` (the line in the right-click menu), `dock.new`, `dock.board.<title>`, `title.name` (the name in the top bar, Mac), `title.rename`, `title.pin`, `title.copy`, `title.starter`.

## Tests
- Rule tests: `Core/Tests/SeedboardCoreTests/Mac05Tests.swift`, 5 tests — Space shows a picture only with exactly one picture chosen and no drag; the Dock menu lists pinned (max 10) then five recent; the board's pictures in reading order with plain names; a photo lands at the right-click spot for two minutes on the same board; the Service makes a board from words and none from no words. All 299 rule tests pass.
- Screen test: `UITests/MacGuideUITests.swift` (guide window opens, its two plates, Escape closes it) — compiles; NOT run (the lead runs screen tests after the join).
- Rules in Core: `Core/Sources/SeedboardCore/MacHabits.swift` (`MenuRules.spaceShowsPicture`, `MacHabits.dockBoards`, `lookPictures`, `cameraSpot`, `serviceBoard`).

## Stored data, marks
- No stored field added; nothing new in the board. No marks wanted (the Mac's menus have no marks).

## Seen running / NOT seen
- Seen in the Mac debug build with sample boards: the Help menu's two lines; the guide window and its pages; the File menu line with each nearby device and Take Photo / Scan Documents / Add Sketch; the line in the right-click menu of empty board (lit, with the same submenu); the Dock menu's lines (asked from the app, not opened from the Dock); a picture handed over the way the iPhone hands it over lands on the board (2 → 3 pictures, at the right-click spot); the Service makes "Winter cabin" from a short list; a click on the name brings "Name of the board" with the name filled in; a right-click shows Rename… / Pin to the top / Make a copy / Save as a starter…; Quick Look of the first picture ("Picture 1", with the arrows). Clicks were made inside the app (the pointer on the screen was not used).
- NOT seen: a real photo or scan taken on an iPhone; the Service started from another app's right-click menu (it was called directly); the Dock's own long press; the iPad's title menu (no simulator); a real hand on the trackpad on the name or Space.

## Drive-by (seen, left alone)
- In the self-check the File menu's Rename…, Send to PARAGON…, Share a Picture…, Save as a Starter… and Remove Board… were pale while a board was open (probably because the check runs before the board has the keys; not looked into).

## Files where the join may clash
New: `App/Sources/MacHabits.swift`, `App/Sources/MacTitle.swift`, Core `MacHabits.swift`, `Mac05Tests.swift`, `UITests/MacGuideUITests.swift`. Small hunks: `SeedboardApp.swift` (the delegate adaptor, `MacCommands()`, `GuideScene()`, `.modifier(MacRoot())`), `Menus.swift` (`BoardKeys`: `.modifier(MacTaker…)`; `SpaceHand`: the Quick Look case before "start typing"), `BoardView.swift` (`.navigationTitle(…)` → `.modifier(BoardTitle…)`), `BoardMenu.swift` (the Mac's popUp line), `project.yml` + `App/Config/Info.plist` (`NSServices`). Note for the join: the app now has an `NSApplicationDelegate` (`MacDelegate`); a lane that needs another delegate method should add it there.
