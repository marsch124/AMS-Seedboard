# Built in 0.5 — the door lane (pick 13, `panel-thinking-flow.md` 5)

Branch `wt-door`. Everything below is built, the rules are proven by data tests, both platforms build.
What was SEEN running (Mac debug build, example boards): the door card by day and by night, the removed door,
the page "Door to a board…", "‹ name" in the top bar, the bar of a chosen door, "Move to a new board…" (the
question, the result and its line with Undo). What was NOT seen is listed at the end.
Pictures (throwaway): `/private/tmp/claude-501/-Users-martinschabbauer-Obsidian-Claude-Code/17034763-8459-4a3b-a9bb-13fd5828f01e/scratchpad/door/`
— `door-open.png`, `door-night.png`, `door-removed.png`, `door-page.png`, `move-ask.png`, `move-now.png`.

## What a door is

A door is a new thing on an ordinary board (kind `door`, board format 5, no new stored field: the groundwork's
`Item.door` holds the board it leads to, `Item.text` holds that board's name).

**On the board it is a small card, 190 × 56 points, one size (no size knobs, no plus-handles):**
- left: the other board's small picture (64 × 40, the same small picture as on the home page), as that board is now;
- then that board's colour dot (8 points) and its name in bold 13-point letters, two lines at most, "…" when longer;
- at the right edge a small arrow head "›" in the other board's colour;
- the card's edge (1.6 points, corner 10) wears the other board's colour; white plate by day with the faint
  shadow of a shape, dark plate by night.
- The name, the dot and the small picture always show the board as it is NOW (renamed, recoloured, changed).
- The frame round a chosen door follows the card (corner 10 + 3).

**A door whose board is not in the list** is a quiet card: dashed grey edge, the door mark at the left, the name
the door remembers in grey, and under it one line:
- `This board was removed` (brick red) — when the board lies in the Removed folder;
- `Not on this device yet` (grey) — when it is nowhere on this device (iCloud has not brought it).

**Counting:** a board's count line says `1 door` / `2 doors` after the pictures ("1 note · 2 doors").
The search finds a board by the name of a board it has a door to.

## Opening, and going back

- **Two presses** on a door (click twice on the Mac), or **Return** with the door chosen, or **Open** in its bar
  or menu: that board opens.
- The top bar then shows, at the left, **`‹ <name of the board he came from>`** in the boards green. Pressing it
  goes back. On the Mac and with a keyboard: **⌘[**. Tooltip: `Back to “<name>” (⌘[)`. Identifier `board.back`.
- The way back is a trail: A → B → C by doors gives "‹ B" on C, then "‹ A" on B. Opening a board in any other way
  (the list, the home page, a link, a new board) ends the trail, and "‹ name" goes away. It is not stored: a
  fresh start of the app has no way back.
- A door to a **removed** board: two presses show the line that already exists at the top of the window —
  "This board was removed on 18 Nov 2026." with **Bring back** (after 30 days: "… Its 30 days are over: it cannot
  be brought back."). The door's own bar and menu also have **Bring back**: the board joins the list again
  (it is not opened), the line at the bottom says `“<name>” is back.`, and the door shows the board again.
  When no copy is left: `No copy of this board is left to bring back.` (red).
- A door to a board that has **not arrived**: `That board is not on this device yet. It opens when it arrives.`
  (the existing line); when iCloud brings the board it opens, and "‹ name" is there.
- A door to the board it lies on (it can get there by Paste): `This door leads to the board you are on.`
- A door has no words to type: Space, a letter key and "Words" do nothing on it. It carries no To do tick and
  no colour of its own. It can be moved, copied, cut, pasted (also into another board), duplicated, lined up,
  removed. Duplicating or copying a board keeps its doors.

## Making a door — three ways

**1. Menu of empty board → `Door to a board…`** (right-click on the Mac; press and hold on iPhone and iPad; the
line stands after "Picture…"). It opens the page **Door to a board**:
- heading `Door to a board` (large, centred, boards green), under it `Press the board the door leads to.`;
- a full-colour green button `New board` (with words in the search field: `New board “<words>”`);
- a search field `Search boards` (finds by name and by the words on a board, like the list's);
- the other boards — pinned first, then the one changed last first; the open board itself is never offered —
  each row: colour dot, name, "Changed 2 hours ago · 5 shapes · 5 notes", its small picture at the right;
- `No other board yet. Press New board.` when there is none, `No board has these words` when the search finds none;
- `Cancel` at the bottom right (Escape on the Mac).
- Pressing a board puts the door at the spot where the menu was opened, chosen, and closes the page.
- `New board` makes a new empty board (named with the search words, else "New board"; a name another board has
  gets " 2", " 3" …), adds it to the list WITHOUT opening it, and puts the door to it on the board. A board still
  called "New board" takes the name of its first idea, as always — and the door follows.
- Size: 380 × 480 on the Mac (the search field has the keys at once); on iPhone and iPad a page from the bottom,
  half height, can be pulled up.

**2. Drag a board from the list onto the open board (Mac and iPad).** A row of the boards list can be dragged
(the small thing that travels shows the dot and the name); let go over the open board, a door to that board lies
there, chosen. Dropped on a timeline or a "Who does what" board nothing happens. Dropped on its own board:
`A board cannot have a door to itself.` (red). What travels is the board's link as words, so dragged into another
app it is that link. Off on the iPhone (list and board are never on screen together).

**3. `Move to a new board…`** — in the menu of a chosen thing, of several chosen things, and of a door
(before "Remove"). It asks **Name of the new board** (a field "Name", filled in with the words of the one chosen
thing — an idea, a frame's name, a note — or "Part of <this board>"; the line under it says
`5 things move there. A door to it is left in their place.` / `1 thing moves there. A door to it is left in its place.`;
**Cancel**, **Save**). On Save:
- the chosen things move to a new board of that name: an idea with everything under it (folded or not), a frame
  with what lies in it, a map with all its ideas. They keep their places, their colours, their To do ticks and
  what is known about their tasks in PARAGON (a task already sent is not sent again from the new board);
- a branch moved without the idea it hung under is the middle of a map of its own there, its ideas keep the
  branch's colour; the old map closes up;
- arrows among the moved things go along; an arrow between a moved thing and one that stays now starts or ends
  at the door;
- ONE door is left in the middle of the room the things took, chosen (when a map that lost a branch closes up
  and now lies there, the door stands a little lower — its own height and 12 points at a time — so it covers nothing);
- the new board joins the list (its own colour) and is NOT opened;
- the line with Undo shows for 6 seconds: `Moved to the new board “<name>”`.
- One Undo step on this board: the things are back and the door is gone. The new board stays in the list as a
  copy (it is not removed by Undo — nothing is ever thrown away by itself).
- The new board is written to the device BEFORE the things leave this one.

**No door on boards that place themselves:** a timeline and a "Who does what" board have no menu of empty board,
take no dropped board, no pasted door and no "Move to a new board…" (`A door cannot be put on this board.` if
it is ever tried).

## The bar and the menu of a chosen door

- Bar: `Open` · (`Bring back`, only when its board was removed) · `Duplicate` · (iPhone and iPad: Choose more) · Remove.
- Menu: `Open`, (`Bring back`), Copy, Cut, Duplicate, `Arrow from here`, `Move to a new board…`, Remove.
- The menu's heading says "Door".

## Arrows

An arrow can start or end at a door (the arrow tool, "Arrow from here", dragging an arrow's end onto it).
Other arrows go round a door as they go round a shape.

## PARAGON and the board's words

- **As a note:** a section `## Doors` after "Notes" (before "Tasks"), one line per door:
  `- [Kitchen plan](seedboard://board/<id>)` — the link opens that board in Seedboard. Square brackets in a
  board's name become round ones inside the link.
- **As a project:** the same `## Doors` section after the Notes, before "## Log".
- An arrow to or from a door names the board in "Flow" ("- Ask Alex → Kitchen plan").
- A door is never a task (no tick, not in the Inbox tasks).
- **Copy the board as text:** a part `Doors:` with `- <name>` per door, after "Shapes:".
- The picture for PARAGON shows the door card as on the board.
- The names in these texts are the boards' names of the moment: when a board with doors is open, each door's
  remembered name is brought up to date quietly (no Undo step, saved like any change).

## For the lead: files

New: `Core/Sources/SeedboardCore/Door.swift` (rules), `Core/Tests/SeedboardCoreTests/Door05Tests.swift`
(12 tests), `App/Sources/Doors.swift` (`DoorLook`, `DoorDesk`, the session's and the model's side, the bar and
menu lines), `App/Sources/DoorDraw.swift` (the card), `App/Sources/DoorPage.swift` (`DoorHost`, `DoorPage`,
`DoorDrag`), `UITests/DoorUITests.swift` (one screen test, compiled, NOT run).

Small hunks in existing files (each marked with a comment that names doors):
- `CanvasDraw.swift`: `drawItem` — `.door` has its own case (`drawDoor`), taken out of the box case; the comment in `Lettering.fit`.
- `CanvasView.swift`: two presses (`tap`) and Return (`handleKey`) ask `session.goThroughDoor` before `beginEdit`.
- `BoardSession.swift`: new `quietly(_:)` (a change that is no Undo step) after `change`; `beginEdit` refuses a door; `toggleTodo` leaves doors out.
- `BarActions.swift`: `itemBar` case `.door`; `thingMenu` — the door's own menu (one line), `moveOutLines()` before Remove in both lists; `emptyMenu` — `doorMenuLines(at:)` after "Picture…".
- `BoardView.swift`: one line `.modifier(DoorHost(session: session))`.
- `RootView.swift`: one line `.modifier(DoorDrag(board: board, on: !phone))` on the list's row.
- `ClipBoard.swift`: the drop of words asks `session.dropDoor` first (one line).
- `ChosenFrame.swift`: `ChosenOutline.path` case `.door`.
- Core: `BoardEdit.swift` `countLine` (+ doors); `Arrows.swift` (a door is something arrows go round);
  `Paragon.swift` — ONE added line in `note` and ONE in `project`: `section("Doors", doorBullets(board), into: &out)`;
  `Outline.swift` `outlineText` — the "Doors:" part before the `return`.

If the `send` lane rewrote `note` / `project` / `outlineText`: keep the two `section("Doors", …)` lines and the
"Doors:" part; `Door05Tests.testADoorIsALineWithALinkInParagonsNoteAndProjectAndANameInTheBoardsWords` says
exactly what must come out.

**No stored field added. The format is not raised.** Device only (never in a board): the way back, which doors'
boards are removed, the small pictures.

## Identifiers

`menu.door` (Door to a board…), `menu.moveOut` (Move to a new board…), `menu.open` / `sel.open` (Open),
`menu.bringBack` / `sel.bringBack`, `board.back`, `door.page`, `door.heading`, `door.new`, `door.search`,
`door.searchClear`, `door.list`, `door.row.<board name>`, `door.noMatch`, `door.cancel`, `door.moveName`.

## Launch words (Mac debug build, `-sampleData` last)

- `-doorPage` — opens "Door to a board…" on the open board (`-doorSearch <word>` fills its search field).
- `-door <word>` — lays a door to the board whose name holds the word; `-door removed` — to a removed example
  board ("Old garden plan"); `-door away` — to a board that is nowhere ("Garden plan").
- `-doorBack <word>` — as if he had come through a door from that board ("‹ name" shows).
- `-moveOut` — asks for the new board's name for what `-pick` / `-pickAll` chose; `-moveOutNow` — moves it at once.
- `-night` must stand right before `-sampleData` (after `-door <word>`): the Mac reads launch words in pairs, and
  `-night -door Arrow` leaves "Arrow" over, which it takes for a file to open — then no window comes up.
- Examples: `-board cabin -door Arrow -doorBack Lanes -sampleData` · `-board cabin -doorPage -sampleData` ·
  `-board cabin -door removed -sampleData` · `-board cabin -pick Build -moveOutNow -sampleData`.

## Marks wanted

- `NewMark.door` is used for: the lines "Open", "Door to a board…", "Move to a new board…", and the mark on a
  door whose board is not here. Its stand-in (`seedFrame`, four corners) is drawn there now; the icons builder's
  `seedDoor` takes its place with the swap in `NewMarks.swift` — nothing else to change (the card draws
  `NewMark.door.standIn.path`).
- No other mark is wanted. The "‹" of the back button is the library's chevron turned round; the "›" on the card
  is drawn as two strokes.

## Not built, and why

- **No line in the View menu for "Back".** ⌘[ hangs on the "‹ name" button itself, so it works on the Mac and
  with a keyboard, but it is not listed in a menu. A menu line would be a hunk in `Menus.swift` (many lanes are
  in there) — say so if it is wanted.
- **Undo of "Move to a new board…" does not remove the new board** (see above; on purpose).
- **A pasted board link** (⌘V of `seedboard://board/…` as words) still becomes a sticky note; only a DROPPED
  one becomes a door.
- **A door cannot be resized** (one size, on purpose: a card).
- **The small picture on the home page / in the iPhone list of a board that has doors** shows the door's card,
  but the tiny picture inside the door can be empty there until that board is changed the next time (the small
  pictures are drawn once per version of a board). On the open board it is always there.

## Not seen running

- Everything on **iPhone and iPad** (the simulators are not mine to use): the page as a sheet from the bottom,
  press-and-hold → "Door to a board…", "‹ name" beside the system's own back arrow in the iPhone's top bar
  (it may be tight with a long name — it is cut at 170 points), the drag of a row on the iPad.
- **The drag from the list on the Mac** (it needs a hand on the mouse): the drop side is the board's existing
  drop of words plus one rule (tested); that a row lifts when dragged is not seen.
- The menus themselves (right-click), two presses and Return on a door and ⌘[ (no hand on the mouse or the
  keys here: going through and back is proven by the trail's data test and seen only as "‹ name" by launch word),
  the removed door and the page by night, Bring back on a really removed board (the example boards' one is made
  up), and a door to a board that arrives late from iCloud.
- The screen test `DoorUITests` is compiled, not run (the lead runs the screen tests after the join).

## Drive-by things seen and left

- `AppModel.send` with one branch and "Only the to-do boxes": the board that is saved with the ticks
  (`store.save(marked)`) is the branch-only copy under the whole board's identity, until `markSent` writes the
  whole board again a moment later. Not mine (`send` lane / lead) — worth a look.
- `AppModel.remove` and `AppModel.duplicate` do not clear `sentTasks` on the copy (`duplicate` clears `sent` and
  `sentTodos` only). Send lane.
