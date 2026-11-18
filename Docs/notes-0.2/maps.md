# Notes for 0.2 — mind maps (picks 19, 20, 21)

Builder `maps`, branch `feat-maps`.

## 1. What's new

**Ideas in another order (pick 19)**
- Before: the order of the ideas under a branch could not be changed at all (0 ways). Dragging an idea more than 50 points anywhere tore it off as a map of its own.
- Now there are 3 ways to put an idea in another place among its sisters:
  1. Keys: ⌘↑ and ⌘↓ move the chosen idea one place up or down. Also in the Board menu on the Mac ("Move the Idea Up", "Move the Idea Down").
  2. Buttons on iPhone and iPad: "Move up" and "Move down" in the bar of a chosen idea (2 new buttons).
  3. Dragging: drag the idea up or down between two of its sisters. A thin green line shows where it will land; let go and it lands there.
- Main branches move round the middle idea on their own side. At the end of a side the branch crosses to the other side (down: to the bottom of the other side, up: to the top). A main branch can also be dragged straight into the other side's column.
- Tearing an idea off as its own map now needs a drag of about 120 points away from its family (before: 50 points in any direction). Dropping an idea on another idea still hangs it there.
- New: dropping an idea on the idea it already hangs under does nothing (before: it jumped to the last place).
- Every move is one step for Undo.

**A keyboard bar for ideas on iPhone and iPad (pick 20)**
- Before: the bar above the screen keyboard had 1 button, "Done".
- Now, while an idea is typed, it has 4: "Idea under" (the same as Tab), "Next idea" (the same as Return), "Out one level" (the same as Shift+Tab) and "Done". On the iPhone the words are short ("Under", "Next", "Out"), on the iPad they are written out.
- The keyboard stays up while you go from idea to idea.
- For boxes, notes, text and arrows the bar still has just "Done".

**"As a project" makes sense for mind maps (pick 21)**
- Before: every idea under a main branch became a task, ticked or not. The sample board "Summer cabin" gave PARAGON 13 tasks, among them "Lake", "Forest" and "Alex".
- Now the To do ticks decide: when at least one idea is ticked, only ticked ideas (and ticked boxes and notes) become tasks; all the others stay as plain lines under their heading. The same sample board now gives 2 tasks ("Permit", "Check timber prices in May") and 11 plain lines.
- When no idea is ticked, everything becomes a task as before, and the Send page says so.
- The Send page shows one line with the counts under "As a project", for example "2 ticked things become tasks, 11 stay as plain lines." or "Nothing is ticked: all 7 ideas and 5 shapes become tasks."
- New: "Send this branch". With one idea chosen, the Send page has a switch "Only the branch “Budget”" (off at first). Switched on, the note, project or tasks hold just that idea and everything under it, the name becomes the branch's words, and the picture shows just that branch. The board is not marked as sent for it.
- As always, Seedboard only adds new files to PARAGON.

## 2. How it works

**Putting ideas in another order**
- Choose an idea. On the Mac press ⌘↑ or ⌘↓ (or Board ▸ Move the Idea Up / Down). On iPhone and iPad press "Move up" or "Move down" in the bar.
- Or drag it: on the Mac just drag; on iPhone and iPad rest a finger on the idea for a moment until it lifts, then drag. Move it up or down between two of its sisters — a thin line shows where it will land — and let go.
- Drop it on another idea (a dashed ring shows round that idea) to hang it under that idea instead. Aim at the middle of a sister to hang it under her; her upper and lower edge count as the gap beside her.
- Drag it well away from its family (about 120 points to the side) and it becomes a map of its own. "Made its own map" shows with an Undo button.
- A main branch moves among the branches on its own side of the middle idea. At the top or bottom of a side, Move up / Move down carries it over to the other side.
- While you are typing in an idea on the Mac, ⌘↑ and ⌘↓ move that idea and the typing goes on. While you are typing in a box, a note or a name field they move the cursor, as everywhere on the Mac.

**The bar above the keyboard (iPhone and iPad)**
- While you type an idea: "Idea under" keeps the words and starts an idea under this one; "Next idea" keeps them and starts the next idea beside it; "Out one level" moves this idea out one level and you go on typing; "Done" keeps the words and puts the keyboard away.
- The Return key of the screen keyboard still means "Next idea".
- "Out one level" is pale for a middle idea and for a main branch: there is no level further out.

**As a project**
- Tick the ideas that are real tasks with "To do". Then Send to PARAGON ▸ As a project: the main branches become headings, your ticked ideas become tasks, the other ideas stay under their heading as plain lines.
- Tick nothing, and every idea becomes a task (as before). The line under "As a project" tells you which of the two will happen, with the counts.
- A ticked main branch becomes a task itself, with its ideas below it.

**Send this branch**
- Choose one idea, then press Send to PARAGON. Switch on "Only the branch “…”". Now only that idea and what hangs under it is sent — as a note, as a project, or its to-do boxes. The name is the idea's words (you can change it), the picture shows only that branch.
- The link in the note still opens the whole board. The board does not move to "Sent" and shows no "Last sent" line for a branch.

## 3. Spec

**Reorder — rules (SeedboardCore)**
- `Board.shiftIdea(_:down:) -> Bool` (`MindMap.swift`): swaps the idea with the next / previous sister *of its side* in the stored order (`order` is renumbered 1, 2, 3 …). Parent is a centre with `bothSides`: sides are written down first (`settleSides`); at the end of a side the branch's `side` flips and it is put last (down) or first (up) in the whole order, so it stands at the bottom / top of the other side. Elsewhere, at the end: nothing, returns false. A centre: false.
- New file `Reorder.swift`:
  - `IdeaSlot { parent, side, before }` — a place among the sisters of one side; `before == nil` = after the last.
  - `IdeaDrop`: `.springBack`, `.hang(under:)`, `.reorder(IdeaSlot)`, `.tearOff`.
  - `MindMap.tearOff = 120`, `MindMap.sisterEdge = 0.25`, `MindMap.shortestLine = 40`.
  - `Board.ideaDrop(_:at:reach:)` — the decision, in this order:
    1. The point is over another idea (`idea(at:notIn:)`, not itself, not one below it): over its own parent → `.springBack`; over a sister only when the point is in the middle half of her height (between 25 % and 75 %) → `.hang`; over any other idea → `.hang`.
    2. For the idea's own side, then (main branch of a both-sides map only) the other side: the box round all sisters of that side (the idea's own frame included on its own side), grown by `reach` on every side. Point inside → the slot is "before the first sister whose middle is below the point", else after the last. The slot it already has → `.springBack`, otherwise `.reorder(slot)`.
    3. Otherwise `.tearOff`.
  - `Board.placeIdea(_:in:) -> Bool` — puts the idea before `slot.before` (or after the last sister of `slot.side`), renumbers `order`, and gives a main branch of a both-sides map `slot.side`.
  - `Board.landingLine(for:moving:)` — the line's two ends: y = middle of the gap between the two neighbours (first place: 5 above the first sister; last place: 5 below the last, half of `gapDown` 10); length = the idea's width, at least 40; it starts at the sisters' shared edge (left edge on the right side, right edge on the left side).
  - `Board.sistersOnSide(of:)`, `place(of:) -> (at, of)`, `canShiftIdea(_:down:)`, `slot(of:)`.
- App: `reach` is `120 / scale` board points, i.e. always 120 points on screen (`BoardSession.tearOffReach`).

**Reorder — app**
- `BoardSession.shiftIdea(_:down:)` (in `BoardSession.swift`, beside `moveOut`): one `change` = one undo step; while that idea is being typed in, the move joins the typing's undo step and the typing goes on (same pattern as `moveOut`). Then `reveal`.
- `BoardSession.dropHints(for:at:)` / `dropIdea(_:at:)` (new file `MapOrder.swift`): what is shown while dragging and what happens on letting go. `.reorder` → `change { placeIdea }` (one undo step), idea stays chosen; `.hang` → `hang`; `.tearOff` → `detach` (notice "Made its own map" with Undo); `.springBack` → nothing.
- `CanvasView`: new state `landing`; while an idea is dragged the ring (`dropTarget`) or the line is set on every move. The line: `Paint.chosen` (green by day #2E8B57, by night #5FBF8A), 2.5 points wide on screen, round ends, a small dot (radius 3.5 on screen) at each end. Drawn only during an idea drag.
- Keys: ⌘↑ / ⌘↓ in `handleKey` (canvas has the keys, one idea chosen). Board menu (`IdeaOrderCommands` in `MapOrder.swift`, placed after "To Do"): "Move the Idea Up" ⌘↑, "Move the Idea Down" ⌘↓. On the Mac the two menu items are never switched off; when the key window's first responder is a text view and the board is not typing an idea (or the key window is a page/sheet), the item hands the key to the text (`moveToBeginningOfDocument` / `moveToEndOfDocument`). On iPhone/iPad (hardware keyboard) the items are switched off when no idea can move.
- Selection bar, iPhone and iPad only, for an idea that is not a centre, after "Next idea": `sel.moveUp` "Move up" (`Glyph.new(.moveUp)`), `sel.moveDown` "Move down" (`Glyph.new(.moveDown)`), mind-map colour; pale (40 %) and switched off when `canShiftIdea` is false.
- For screen tests: `board.chosenPlace` — a 1 × 1 clear text beside `board.count` that says the chosen idea's place among the sisters of its side, e.g. "1 of 2"; empty when anything else is chosen.

**Keyboard bar (iPhone, iPad)**
- `CanvasView.keyboardBar(isIdea:)` in `MapOrder.swift`, inside the field's `.keyboard` toolbar.
- Idea: `board.key.under` (mark `.ideaUnder`; `commitEdit(then: .child)`), `board.key.next` (`.nextIdea`; `commitEdit(then: .sister)`), `board.key.out` (`.outLevel`; `moveOut`; switched off and 40 % when the idea's depth is below 2), flexible space, `board.fieldDone` "Done" (unchanged). Each button: mark 17 points in the mind-map colour + words (subheadline, medium), 30 high, 8 padding across, soft mind-map background, corner 8. Words: canvas at least 520 wide → "Idea under", "Next idea", "Out one level"; narrower → "Under", "Next", "Out". VoiceOver always reads the whole name.
- Anything else: flexible space + "Done", as before.
- The keyboard stays up: on iPhone and iPad all ideas are typed in ONE field (`CanvasView.fieldIdentity(isIdea:)` returns one fixed identity for ideas), so going from idea to idea never takes the field away. Other things, and everything on the Mac, get a fresh field per thing as before (`session.editing`).
- An empty new idea + "Idea under" / "Next idea": the empty idea goes away and typing ends — the same as Tab / Return.

**As a project (SeedboardCore, new file `ProjectPlan.swift`)**
- `ParagonExport.ticksDecide(board)`: true when at least one *idea* has `todo`.
- False → the text is exactly as in 0.1.
- True →
  - a ticked centre adds `- [ ] <centre>` before everything else (it is still the Outcome);
  - an unticked main branch with ideas under it → `### <branch>`, then its ideas; with none → plain `- <branch>` before the headings;
  - a ticked main branch → `- [ ] <branch>` before the headings, its ideas indented under it;
  - every idea below: ticked → `- [ ] <words>`, unticked → `- <words>`;
  - indent (two spaces per level): a plain line stands one level below the line of the idea it hangs under; a task stands one level below the nearest *ticked* idea above it in the branch, and at the left edge when there is none. Reason: PARAGON hangs an indented task under the nearest task above it with less indent and passes over plain lines (`TaskParser.parse(text:)`), so a ticked idea under an unticked one would otherwise become a sub-task of an unrelated task;
  - `### Steps`: every shape with words in arrow order, ticked → `- [ ]`, unticked → `- `;
  - `### To do`: ticked notes and free text, as before.
- `ParagonExport.projectTally(board:)` → `ProjectTally { ticks, ideaTasks, ideaPlain, shapeTasks, shapePlain, otherTasks, anyTick }`, counted from the very lines `project()` writes.
- `ParagonExport.projectLine(board:)` (the Send page's line, `send.projectLine`, shown under the name when "As a project" is chosen; it replaces "The N to-do boxes become tasks in it." there):
  - ticks decide: "N ticked ideas become tasks" ("things" instead of "ideas" when a ticked shape, note or text is among them; "1 ticked idea becomes a task"), then ", M stay as plain lines" (", 1 stays as a plain line"; left out when 0), full stop;
  - otherwise: "Nothing is ticked: all N ideas become tasks." / "… all N ideas and M shapes become tasks." / "… the 1 idea becomes a task."; it starts "No idea is ticked:" when a note, text or shape is ticked but no idea; no line when the project would hold neither ideas nor shapes.
- The row's words: "The branches become headings. The ideas you ticked To do become tasks; with nothing ticked, all of them do. It goes to Projects."

**Send this branch**
- `Board.branchOnly(_ id:) -> Board?` (`ProjectPlan.swift`): same board `id` (the link back opens the whole board), `title` = the idea's words in one line (the board's title when it has none), `sent` = nil, `sentTodos` kept; items = the idea and everything below it; arrows only between those. An idea that was not a centre becomes one (`parent` nil, one side); the ideas right under it take the colour the branch had; then `layoutMaps()`. nil for anything that is not an idea. `Board.branchName(_:)` = the idea's words in one line.
- Send page: `send.branchOnly` — a row with the mark `.branch`, the words "Only the branch “<words>”" (a centre: "Only the map “…”"; no words: "Only this branch"; words longer than 32 letters are cut to 30 + "…") and a drawn switch 38 × 22 (PARAGON purple when on). It shows only when exactly one idea is chosen; off at first. Its accessibility value is "On" / "Off". When on, one line under it: "Just this idea and what hangs under it is sent, with a picture of it alone. The board is not marked as sent."
- When on: the counts, the project line, the name and Send all use the branch. The name follows the switch (`noteTitle(for:)` of the branch's words / of the board's title) unless the owner typed another name.
- `AppModel.send(kind:title:branch:)`: sends `branchOnly(branch)`; the picture is drawn from it and named after the branch ("Seedboard Budget yyyy-MM-dd HHmm.png"). Afterwards `markSent(nil, todos:)`: the board's `sent` is NOT set; the ticks that went with the branch are added to `sentTodos`.
- `ParagonGate` is unchanged: only new files, never a file that is there.

**Stored fields:** none added. The stored format is untouched.

**Identifiers added:** `sel.moveUp`, `sel.moveDown`, `board.chosenPlace`, `board.key.under`, `board.key.next`, `board.key.out`, `send.branchOnly`, `send.projectLine`. All existing ones kept (`board.fieldDone`, `send.*`).

## 4. For the lead

**Launch arguments (all with `-sampleData`)**
- `-board cabin -pick Budget -send` — the Send page with the branch switch (off).
- NEW `-branchOnly` — the same with the switch on: `-board cabin -pick Budget -send -branchOnly` (name reads "Budget").
- NEW `-sendAs note|project|todos` — chooses the row; `-board cabin -send -sendAs project` shows the line "2 ticked things become tasks, 11 stay as plain lines."
- NEW `-type` — starts typing in the picked thing: `-board cabin -pick Loan -type` shows the keyboard bar (iPhone/iPad; the simulator must show its screen keyboard).
- `-board cabin -pick Loan` — the idea bar with Move up (pale) and Move down (iPhone/iPad).
- The landing line only shows during a real drag; no launch argument can show it.

**Screen tests:** `UITests/MapsUITests.swift`, 3 tests, written and compiled (`build-for-testing` on the Mac), NOT run: the Send page offers the branch switch and the name follows it; no switch with nothing chosen; Move down changes the order (iPhone/iPad: `sel.moveDown`; Mac: ⌘↓) and Undo puts it back.

**Data tests:** 7 new in `Core/Tests/SeedboardCoreTests/MapsTests.swift`. One old test changed: `MindMapTests.testShiftIdeaMovesOnePlace` now uses a one-sided map (it tested the old, unused swap across both sides).

**Shared files touched (tight hunks):** `CanvasView.swift` (1 state, 1 draw line, 1 test mark, field identity, keyboard bar call, the `.idea` cases of `update` and `finish`, ⌘↑/⌘↓ in `handleKey`), `BoardSession.swift` (new `shiftIdea` beside `moveOut`), `BoardView.swift` (2 chips in `itemChips`, 1 line in the Board menu), `AppModel.swift` (`-type`, `send(… branch:)`), `SendSheet.swift`, `MindMap.swift` (`shiftIdea`), `Paragon.swift` (project lines moved into `ProjectPlan.swift`; `label`, `taskLines`, `flowOrder` no longer private). New files: `Reorder.swift`, `ProjectPlan.swift`, `MapOrder.swift`, `SendBranch.swift`.

**ICON-WANTED:** none. Used `.moveUp`, `.moveDown`, `.ideaUnder`, `.nextIdea`, `.outLevel`, `.branch`.

**Left open**
- A branch send leaves no trace on the board (by the brief: no "sent" mark). If a "Last sent branch" line is wanted, it needs a new stored field.
- The idea bar on the iPhone is now 2 buttons longer and wraps to one more row; pick 7 (one-row bar) should take "Move up" / "Move down" into account.
- "Move up" / "Move down" are not in the Mac's bar (the brief names iPhone and iPad); it is one `#if` in `SelectionBar.itemChips` to show them there too.
- When the ticks decide, unticked flow shapes are plain lines under "### Steps" (the brief's "others become plain lines under their heading").

**Only a real device can prove**
- The keyboard really stays up from idea to idea (Return, "Next idea", "Idea under"), and the shared field shows the new idea's words (empty) each time — with autocorrect and with dictation. If it misbehaves: `fieldIdentity` in `MapOrder.swift` is the one place; returning `session.editing` there gives 0.1's behaviour back.
- The keyboard bar's four buttons fit on the smallest iPhone and look right on iOS 26's glass bar, day and night.
- Dragging between sisters with a finger: the hold-then-drag, the 13-point "hang" middle of a one-line sister versus the gaps, and the 120-point tear-off feel right at 50 % and 200 % zoom.
- Mac: ⌘↑ / ⌘↓ still move the cursor while typing in a box, a note, the rename box and the Send page's name field (the menu hands the key on); and they move the idea while typing in an idea.
- iPad with a hardware keyboard: ⌘↑ / ⌘↓ move a chosen idea; while typing they are expected to move the cursor (the system's text keys come first there).
- No real Send was made. The project text with ticks was checked against PARAGON's task reader by reading its code, not by opening a sent note in PARAGON.
