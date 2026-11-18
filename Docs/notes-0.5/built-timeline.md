# Built in 0.5 — the `timeline` lane (picks 15 and 18)

Branch `wt-timeline`. Findings: `panel-thought-to-action.md` 3 and 4, `panel-thinking-flow.md` 6.
Everything below is exactly as it shows on screen. No stored field was added (the groundwork's `Item.doneDay` is used); the board format stays 5.

## Pick 15 — from a board to a timeline

### "Make a timeline of it…"
- Where: the **More** menu of an ordinary board — "Make a timeline of it…", right under "Copy the board as text" — and the Mac's **File** menu — "Make a Timeline of It…", right under "Share a Picture…". Not shown on a timeline or a "Who does what" board, nor while a starter is being changed; switched off (grey) on an empty board.
- What happens: a NEW board named "<name> timeline" is made and opens at once (a second one is "<name> timeline 2", by the rule that is there). The board it was made of is not changed. No page asks anything.
- The rule is the mirror of "As a project" (same ticks, same order), so the number of bars is always the number of tasks the project would have:
  - a main branch with ideas under it → a **phase** with its name, in the branch's colour;
  - every idea under it → a **bar** in that phase, in the map's order; a deeper idea comes right after the idea it hangs under; the bars have the branch's colour;
  - a main branch with nothing under it → a bar above the first phase;
  - a note or a free text marked To do → a bar above the first phase (after the branch bars), in the note's colour;
  - a flow shape with words → a bar (in the shape's colour; a shape without a colour gets the next of the bar colours); an arrow from one shape to another → the second bar "comes after" the first. A question with two answers gives two bars that both start when the question's bar ends;
  - a frame with lanes → one phase per lane, named "<frame>: <lane>" (or just the lane's name), with the lane's shapes as bars;
  - the middle idea is the board's subject: it gives the name, not a bar (unless it is ticked).
- The ticks decide exactly as for a project: nothing ticked → every idea and every shape; at least one idea ticked → only the ticked ideas, shapes, notes and texts. A ticked main branch becomes a bar above the first phase with its ticked ideas after it. A bar made of a ticked thing keeps the To do tick.
- With things chosen, the choice decides instead of the ticks: the chosen ideas with everything that hangs under them (each under its own branch's phase), and the chosen shapes, notes and texts.
- Days: every bar is 7 days long and starts today. Inside a phase, and among the bars above the first phase, each bar comes after the one before it (so they stand one after the other, joined with "comes after" arrows). Shapes follow their own arrows; shapes without arrows all start today. The phases start together.
- A shape that did not become a bar (not ticked, not chosen) is passed over: the bars before and after it are joined directly.
- The line at the bottom, for 6 seconds (green): "12 bars in 3 phases. Drag them to their days." — without phases "4 bars. Drag them to their days." — one bar "1 bar. Drag it to its days." When ideas, shapes, notes or texts with words stayed only on the board: "6 bars in 2 phases. 1 thing stayed on the board." — and when the ticks decided: "4 bars in 2 phases. 4 things without a tick stayed on the board." With a choice, only the chosen things are counted.
- Nothing can become a bar (for example only pictures, or only notes without a tick): no board is made, and the line says, in brick red for 6 seconds, "Nothing here can become a bar. Bars are made of ideas, shapes and things marked To do." (an empty board, should the line ever be reached: "The board is empty: there is nothing to make bars of.")

### A list pasted onto a timeline
- Where: on a timeline board, **⌘V** (Mac: also Edit ▸ Paste), **More ▸ "Paste a list as bars"** (the line that reads "Paste a list as a mind map" on other boards) and the Mac's **Board ▸ "Paste a List as Bars"** (⇧⌘V). On a "Who does what" board the line stays switched off.
- One bar per line, 7 days each, each coming after the one before. A line with indented lines under it becomes a **phase**; every line under it (also deeper ones) becomes a bar of that phase, in the phase's colour, in a chain of its own. Bullets, numbers and check boxes are stripped, as for a mind map.
- Nothing chosen: the bars go under the last row and the chain starts today. A row chosen: they go right under it; when that row is a bar or a milestone the chain goes on from it (the first new bar starts the day after it ends and comes after it, as Return does). Phases are put where they split no phase that is there: after the rows of the chosen row's phase, or at the very end.
- Afterwards the new bars are chosen, the first is brought into sight, and the line says "5 bars pasted." / "1 bar pasted." / "7 bars in 2 phases pasted." With no words on the clipboard: "Nothing to paste." One Undo step.

## Pick 18 — a timeline to plan with

### Done
- A new button **Done** (`sel.done`) in the chosen bar's or milestone's buttons, between Dates and To do; also in the buttons for several chosen rows (before To do) when at least one of them is a bar or a milestone. A phase has none.
- Pressing it marks the bar done today (the day is kept in the board: `doneDay`); the button is then full colour. Pressing again takes the mark off. With several chosen: all become done, or — when all are done — the mark comes off all. One Undo step.
- How a done bar looks: the bar is paler (36 % by day, 42 % by night), with a tick in the bar's own colour at its end (inside the bar from 22 points of width, right behind it when shorter; behind the diamond for a milestone), and its name in the names column is grey.
- A bar whose task is ticked off in PARAGON (read back on the device by the `echo` lane: `ParagonEcho`, state `.done`) is drawn done in the same way without anything being written into the board, counts as done in the line, is never late and is left alone by Catch up. Taking the Done mark off such a bar says "It is ticked off in PARAGON, so it stays done."
- A copy of a done bar (Duplicate) is not done.

### Late, and in work
- Late = the last day is before today and the bar is not done. A late bar has a red end (the last 6 points) and a red name; a late milestone has a red edge and a red name.
- The part of a bar that is not done and lies before the Today line is darker (black laid over it at 20 % by day, 30 % by night), so a bar in work is darker up to the Today line.

### The one line
- In the corner above the names column: "3 of 8 done · 1 late · ends 20 Feb". Bars and milestones are counted. "· 1 late" only when something is late (in red); "ends" is the last day of the latest bar, with the year when it is not this year ("ends 20 Feb 2027"). "3 of 8 done" in the ink colour, the rest grey; 11 points (10 on the iPhone's narrow column), on as many lines as the corner needs (at most three). Nothing for a timeline without bars.
- It is drawn by the painter, so it is also in the picture that goes to PARAGON and in the small pictures.
- For the screen tests the same words are an element of their own: `timeline.progress`.

### Catch up
- A button **Catch up** (`timeline.catchUp`) right after Today, shown only while something is late (and the board can be changed): the red of the Today line with white letters and the catch-up mark; on the iPhone the mark alone (there is no room for the words). Help: "Catch up: late bars are stretched to today, and what comes after moves along".
- What it does, in one Undo step: every late bar is stretched to end today (it is taken to be in work); a late bar that comes after another late bar cannot have begun, so it keeps its length and starts right after that one; a late milestone moves to today; everything that comes after is pushed along by the rule that is there. Done bars are not touched.
- The line, for 6 seconds: "4 bars moved. The plan now ends 27 Feb (was 20 Feb)." — when the end did not move: "4 bars moved. The plan still ends 20 Feb." — "1 bar moved. …"

### Week numbers
- On the **Weeks** scale every Monday carries its week's number, "w 49", small and grey (9.5 points) over its date; the date ("30 Nov") stands 4 points lower than before to make room. Numbered as in Sweden: weeks begin on Monday, week 1 holds the year's first Thursday (1 Jan 2027 is in week 53). Days and Months are unchanged.

### A phase carries its rows
- Dragging a phase by its name moves the heading with every row under it as one block. The block only lands where it splits no other phase: before another phase, at the very end, or among the rows above the first phase. Dragged only a little into another phase it stays; dragged past that phase's middle it jumps past the whole of it. A bar or a milestone still moves alone.

### The timeline opens as it was left
- The scale (Days, Weeks, Months), the day that stood beside the names and how far the rows were slid come back when the timeline is opened again — on the same device only (kept in the device's own settings, key `seedboard.timelineViews`, never in the board; at most 200 timelines, the oldest forgotten first). Days are kept, not screen points, so the same days come back in a window of another size.
- "Show the whole timeline" (or never moving it) means it opens whole again.
- With `-sampleData` nothing is written down; with any launch word that sets the scene (`-board`, `-pick`, …) nothing is brought back.

## Launch words for pictures
- `-makeTimeline` (with `-board <word>`): makes the timeline of that board at the start and shows it, with its line.
- `-doneBars <n>` (on a timeline): marks the first n bars done.
- `-catchUp` (on a timeline): presses Catch up at the start.
- The made-up timeline (`-board timeline -sampleData`) has two bars behind today by itself, so late, the line and Catch up show without any word. `-scale weeks` shows the week numbers.

## New identifiers
`sel.done` · `timeline.catchUp` · `timeline.progress` · `more.makeTimeline`

## Marks
- Uses the groundwork's `NewMark.done` (Done button) and `NewMark.catchUp` (Catch up button). No further mark wanted.

## Rules and tests
- Core, new: `TimelinePlan.swift` (done, late, the line, Catch up, the view that comes back), `TimelineMake.swift` (a timeline of a board, a pasted list as bars). In `Timeline.swift`: `Day.weekNumber` / `weekWord`, `Board.carryRow`, a copy is not done.
- 11 data tests (305 in all, all passing) in `Core/Tests/SeedboardCoreTests/Timeline05Tests.swift`.
- One screen test, written and compiled, NOT run: `UITests/Timeline05UITests.swift` (the line, Done, Catch up, Undo, on the made-up timeline).

## Seen running, and not
- Seen on the Mac debug build with the made-up boards, by day: the line in the corner, a done bar (pale, tick, grey name, Done full colour), a late bar (red end, red name), the darker part up to Today, the week numbers on the Weeks scale, the Catch up button (day), the timeline after Catch up by night ("5 bars moved. The plan still ends 26 Dec."), Done for two chosen rows, and "Make a timeline of it" on the made-up "Summer cabin" (it has two ticks, so: "2 bars in 1 phase. 15 things without a tick stayed on the board.").
- NOT seen: anything on iPhone or iPad (builders may not use the simulators) — in particular the corner line on the iPhone's narrow names column (three short lines of 10 points) and the Catch up button as a mark alone; a done bar by night; a pasted list on screen; dragging a phase with the pointer; the view coming back after a real restart (it is switched off with the launch words pictures use); the screen test (compiled only).

## Not built
- **⌘V on an iPad or iPhone with a keyboard** does not reach a timeline (the Edit menu's Paste there only reaches the ordinary drawing surface, `ClipCommands` in `ClipBoard.swift`, not this lane's file). More ▸ "Paste a list as bars" and Board ▸ "Paste a List as Bars" (⇧⌘V) work everywhere.
- **A done bar still goes to PARAGON as an open task** (`- [ ]`): the texts belong to the `send` lane. To decide: should a bar that is done on the board be written `- [x]`?
- The to-do rings on bars (the three marks) are the `looks` lane's; this lane only reads `todoStates`.
- No haptics were added for Done or Catch up (the `feel` lane owns the moments).

## For the join
- `App/Sources/TimelineDraw.swift`: new `var todoStates` on `TimelinePainter` (the `looks` lane may add the same line for its rings — keep one); small hunks in `draw` (one call after `drawBar`, the name's colour, the Weeks date's y, one call in the corner) and in `drawBar` (the pale fill).
- `App/Sources/TimelineView.swift`: `painter.todoStates = echo.marks(for:)`, the hidden `timeline.progress` text, Paste (Mac command and key), the launch words, `carryRow` in the row drag, `TimelineKeep.shared.opened`.
- `App/Sources/TimelineBars.swift`: Catch up in the zoom cluster, Done in the chosen bar's buttons.
- One-line hunks elsewhere: `BoardSession.paste` (a timeline pastes bars), `AppModel.load` (`makeTimelineAtLaunch()`), `BoardView` More (the paste line's words and switch, the new line) and Board menu (the paste line's words and switch), `Menus` File (the new line).
- New files: Core `TimelinePlan.swift`, `TimelineMake.swift`, `Timeline05Tests.swift`; App `TimelineProgress.swift`, `TimelineKeep.swift`, `TimelineOfIt.swift`; `UITests/Timeline05UITests.swift`.

## Seen and left (not this lane's)
- The made-up timeline's comment says "seven bars"; it has six (`Sample.swift`).
- A starter saved from a timeline with done bars keeps them done in every board made from it (`StarterShelf`): probably the marks should be cleared there.
- Before 0.5 a timeline that had been slid could come back with its days at the year 2000 after a restart: "where the owner left" (`Remember.swift`) marks it as moved but a timeline never applied the place. Read in the code, not run. `TimelineKeep` now brings the real view back, or shows the timeline whole when nothing is written down.
- With `-sampleData` the made-up timeline now shows two late bars and the Catch up button; older pictures of it (guide, tour, Apps Overview) will look different.
