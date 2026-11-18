# Built in the `shortcuts` lane (0.5) — picks 23 and 28, and the search bug (AP 6)

Branch `wt-shortcuts`. Findings: `panel-thinking-flow.md` 9, `panel-apple-platform.md` 3 and 6.
Everything below is what the code does. What was seen running and what was not is at the end.

## 1. Shortcuts actions (pick 23)

Seedboard now has **six** actions in the Shortcuts app (three before), plus "Find boards". The three new ones leave Seedboard in the back.

### Add to board (new)
- Name **"Add to board"**. Its line in the Shortcuts app: **"Add [Text] to [Board]"**, and below it **Picture** and the switch **"Open the board afterwards"** (off at first).
- Description: "Adds a thought to one of your boards without opening Seedboard. One line becomes a sticky note, a list becomes a mind map, a picture becomes a picture. With no board chosen it goes to the board you changed last."
- **Text** must be given; when it is missing Siri / Shortcuts asks **"What do you want to add?"**. **Picture** and **Board** may be left empty.
- Spoken and typed phrases: "Add to a Seedboard board", "Add a thought in Seedboard", "Add to <board> in Seedboard".
- Where it goes:
  - One line → one yellow sticky note. Several lines follow the rule for pasted words (a list → a mind map of its own; whatever the `thinking` lane makes of pasted paragraphs applies here too, because the same rule `addWords` is used).
  - **A board that is one mind map and nothing else** (every thing on it is an idea, one middle): one line becomes a **new main branch** of that map (finding TF 9).
  - A picture → a picture, at most 320 points on its long side like every picture.
  - Everything that is not a branch lands at the groundwork's `arrivalSpot`: a free column **40 points to the right of everything on the board, its top at the top of what is there**; on an empty board in the middle. Words and a picture in one go: the picture lies **under** the words, **16 points** apart. Nothing on the board is covered or moved.
- No board chosen: the thought goes to **the board changed last that can take it** (a timeline or "Who does what" board that happens to be the newest is passed over). See "To decide".
- The answer it gives: **"Added to Summer cabin."** (with a picture that could not be read: "Added to Summer cabin. The picture could not be read."). It also hands the board back as its result, so a shortcut can go on with it.
- It refuses, in these words, and changes nothing:
  - timeline: "Nothing was added. “Trip plan” is a timeline and places its things itself. Choose another board."
  - "Who does what": "Nothing was added. “Hand-over” is a “Who does what” board and places its things itself. Choose another board."
  - a board from a newer Seedboard: "Nothing was added. “…” was made by a newer Seedboard. Update the app to add to it."
  - no board at all that can take it: "Nothing was added. There is no board yet that a thought can be added to. Make a board first."
  - nothing handed over: "There was nothing to add."
  - only a picture, and it cannot be read: "Nothing was added. That could not be read as a picture."
  - the board is gone: "Nothing was added. That board is not on this device any more."
  - the board cannot be changed this very moment (it is waiting for its newest version after Handoff): "Nothing was added. “…” cannot be changed just now. Try again in a moment."
- **What he sees afterwards:** the things that were added are **chosen once** when the board is opened next (on this device), and half a second later the view moves just enough to bring the first of them into sight. If the board is the one that is open, they are chosen at once and the step is one Undo.
- **"Open the board afterwards"** on: the board opens in Seedboard after the add. This needs iOS 18.2 / macOS 15.2 or later; on an older system the switch does nothing (the thought is still added).
- Safety: the board's copy on the device is written before the action answers (the same wait as when the app is left); on iPhone and iPad iCloud's copy then gets up to 8 seconds. An open board is changed through its own session, any other board through the model's one `write`.
- Which things arrived is kept in this device's own settings (`seedboard.outsideArrivals`), never in the board and never synced. So: added on the Mac, opened on the iPhone → the things are there, but not chosen.

### Board as text (new)
- Name **"Board as text"**, line **"Get [Board] as text"**. Gives back plain text — exactly what "Copy the board as text" copies. Seedboard stays in the back.
- Phrases: "Get a Seedboard board as text", "Get <board> as text from Seedboard".

### Board as picture (new)
- Name **"Board as picture"**, line **"Get [Board] as a picture"**. Gives back a PNG file named after the board ("Summer cabin.png") — the same picture PARAGON gets (day look, on white). The board's own pictures are read from their files first, so they show although the board is not open.
- An empty board: "“…” is empty, so there is no picture of it."
- Phrases: "Get a Seedboard board as a picture", "Get <board> as a picture from Seedboard".

### Find boards (new)
- The Shortcuts app shows it by itself as "Find Boards" (it comes from the boards' new properties). Its description: "Finds your boards by name, by the day they were changed, and by whether they are pinned or were sent to PARAGON."
- Filters: **Name** (is / contains / begins with), **Changed** (is after / is before), **Pinned** (is), **Sent to PARAGON** (is); all of them or any of them. Sort by **Name** or **Changed**, and a limit. Capitals and accents do not matter in names.
- So "boards changed this week" is: Find Boards where Changed is after <a date>.

### New board (changed)
- "Start with" now offers **his own shelf**: every starter he sees on the Starters page — the built-in ones (also renamed or changed ones) and the ones he saved — in his order, each with its hint line. Before: a fixed list of the seven built-in ones.
- Left empty = a blank board (before: "Blank board" was pre-chosen). A starter that was removed meanwhile also gives a blank board.
- Description now: "Makes a new board with the starter you choose — your own starters too — and opens it. With no starter it is a blank board."
- The phrase "New <starter> in Seedboard" follows the shelf's names (Siri hears of a renamed or new starter about 2 seconds later).
- ⚠️ A shortcut he saved in 0.4 with a starter picked may show "Start with" empty once and must be picked again (the list changed its kind).

### Boards as things (iOS 18 / macOS 15 and later)
- A board in the device's search is now tied to the board Siri and Shortcuts know, so the result can also carry "Open board". On older systems nothing changes.
- A board now has four properties in Shortcuts: Name, Changed, Pinned, Sent to PARAGON.

## 2. The device's search (AP 6, the bug)
- Before: the search knew a board's name and the first 300 letters on it; no picture.
- Now: it is told **every word** — the name, the words on every thing and on every arrow — up to **20 000 letters** (searched, never shown). The line under the name is still the first 300 letters.
- The result shows the board's **small picture** (the one the home page draws, by day; 480 × 300 pixels, JPEG). An empty board has none.
- Every board is told again once after the update (the key in the device's settings was renamed to `seedboard.searchTold.2`; the old one is removed).
- The pictures are drawn only for boards that changed, 2 seconds after the last change, one at a time, and never while he types or drags (it then looks again 2 seconds later).

## 3. Handoff (pick 28)
- A board that is open offers itself on his other devices: the Mac shows Seedboard's icon at the end of the Dock, the iPad in its Dock, the iPhone in the app switcher. Taking it up opens **the same board at the same zoom and the same spot in the middle**.
- Not offered: sample boards, a starter's working copy, a board that itself still waits (below). A timeline or "Who does what" board is offered, but without zoom and place (they place themselves).
- The view travels a moment (0.6 s) after he stops moving the board, not while he moves it.
- **Faster than iCloud:** the offer carries when the board was last changed. If this device's copy is older, the board is shown but **cannot be changed**, with the line **"Waiting for the newest version from iCloud…"** at the top (a capsule in the boards' green, where the "made by a newer Seedboard" line sits; the tools are hidden as on every board that cannot be changed). When the newest version arrives the line goes and the board can be changed; after **20 seconds** at most it opens with what is here. Leaving the board ends the wait.
- A board that is not on this device yet, or was removed, gets the same answers as a link to it ("That board is not on this device yet. It opens when it arrives." / the Bring back line).

## Launch words (DEBUG builds only)
- `-addThought "<words>"` — adds the words as "Add to board" would. With `-board <word>` to the open board (chosen at once). With `-addTo <word>` to the first board whose name holds the word, which is NOT open, and opens it one second later (the arrival shows chosen). `\n` in the words is a new line. Example: `… -board Summer -addThought "Roof\n  Tiles\n  Gutter" -sampleData`.
- `-handoffWait` — shows the open board as it waits for its newest version (ends by itself after 20 s). Example: `… -board Summer -handoffWait -sampleData`.

## New identifiers
- `board.handoffWait` — the line "Waiting for the newest version from iCloud…".

## Marks wanted
None. (The tiles of the six actions in the Shortcuts app are Apple's system pictures, as before — that list takes nothing else: plus.bubble, text.alignleft, photo for the three new ones.)

## Stored fields
None added. Board format stays 5. New on the device only: `seedboard.outsideArrivals` and `seedboard.searchTold.2` in the device's settings.

## Rules and their tests
New Core file `Core/Sources/SeedboardCore/OutsideAdd.swift` (`Outside.refusal`, `boardForThought`, `add`, `isOneMap`, `addedLine`, `find`, `starters(named:)`, `searchText`; `OutsideArrivals`; `Handoff`). Nine data tests in `Core/Tests/SeedboardCoreTests/Shortcuts05Tests.swift`; all 303 rule tests pass.
No new page, so no screen test.

## Files
- New: `Core/Sources/SeedboardCore/OutsideAdd.swift`, `Core/Tests/SeedboardCoreTests/Shortcuts05Tests.swift`, `App/Sources/IntentsAdd.swift` (the three actions), `App/Sources/OutsideAdd.swift` (carrying out the add, the arrivals), `App/Sources/HandoffDesk.swift`.
- Changed: `App/Sources/Intents.swift` (the board's properties, Find boards, the starter list, three phrases), `App/Sources/Spotlight.swift`, and small hunks in `App/Sources/Menus.swift` (OutsideDoors: 3 lines), `App/Sources/BoardView.swift` (the waiting line: 4 lines; the offer: 2 lines), `App/Sources/BoardSession.swift` (**one line**: `readOnly` is also true while the board waits after Handoff — not in my lane's list, but the only way to show the board unchangeable).
- `AppModel.swift` is NOT touched.

## NOT built
- Nothing of the lane is left out. One limit: "Open the board afterwards" works only on iOS 18.2 / macOS 15.2 and later.
- Not asked for and not built: a line at the bottom saying how many things came in (the `extension` lane has "2 things came in from Share."; here the things are chosen instead).

## NOT seen running
- Seen on the Mac debug build with sample boards (pictures taken, then the app was quit): a thought added to a board that was not open and chosen when it opened; a list added to the open board as a mind map, chosen ("3 chosen"); the waiting line with the tools hidden.
- NOT seen: any action run from the Shortcuts app, Siri or Raycast (a debug build is not signed, and the real app must not be started); the answer "Added to …"; "Open the board afterwards"; a picture handed to "Add to board"; "Board as picture" as a file; "Find Boards" in the Shortcuts app (its four filters are in the built app's action list); the starter list in "New board"; Handoff between two devices; the search result with its picture; anything on iPhone or iPad (built only).
- In the built Mac app's action list: 6 actions (AddToBoardIntent, BoardAsPictureIntent, BoardAsTextIntent, NewBoardFromTextIntent, NewBoardIntent, OpenBoardIntent), 2 kinds of things (BoardEntity, StarterEntity), 6 app shortcuts.

## For "How it works" (traps the texts builder should say)
- A thought added on a device that has not yet received a newer version of that board from iCloud ends as a clash: the other version goes to "Earlier versions" and the clash line says so. Nothing is lost.
- The things are chosen only on the device where they were added.

## To decide (lead or Martin)
1. **No board chosen.** The note says "the board changed last". Built: the board changed last *that can take a thought* — so a timeline that happens to be the newest does not turn the thought away. The answer always names the board. The strict reading (refuse with the timeline line) is a two-line change in `Outside.boardForThought`.
2. **One line on a pure mind-map board becomes a main branch** (TF 9), not a sticky note beside the map. The lane's short brief only says "lands at `arrivalSpot`"; say so if a sticky note is wanted there too.

## Drive-by things seen and left
- `AppModel.duplicate` clears `sent` and `sentTodos` of the copy but not the new `sentTasks`.
- Each separate "Add to board" starts a new column to the right (the groundwork's `arrivalSpot` rule), so five thoughts added one by one march to the right instead of stacking in one column. That is the shared rule; left as it is.
- `openAppWhenRun` (used by the three older actions) is marked as outdated by Apple from iOS 26 on; it still works. Not changed.
