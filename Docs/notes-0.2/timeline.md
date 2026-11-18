# Timeline board (pick 1) — builder notes

## 1. What's new

**Timeline board — a new kind of board.**
Before: every board was a free sheet (mind maps, shapes, arrows, notes); 5 ways to start a board; nothing knew about dates.
Now: a 6th starter, **Timeline** ("Bars on days, with what comes after what"), opens a board of its own kind — a simple plan over time:

- The names stand in a column pinned at the left, the dates in a band pinned at the top; both stay in place while the days slide sideways and the rows slide up and down.
- Every row has one coloured bar from its first to its last day. A bar is always whole days and never shorter than 1 day.
- 3 scales instead of a zoom in percent: **Days** (a day is 28 points wide), **Weeks** (a week is 56), **Months** (a month is about 72). The zoom buttons step through them; "Show the whole timeline" picks the closest scale at which everything fits.
- A red **Today** line with the word Today, and a **Today** button that brings it into view.
- **Comes after**: a thin right-angled arrow from the end of one bar to the start of the next. Moving or stretching a bar pushes every bar that comes after it, so none starts before its forerunner ends — and a line says how many moved ("2 bars after it moved along."). A bar cannot be dragged to before the end of the bar it comes after.
- **Milestone**: one day, drawn as a purple diamond. **Phase**: a heading row; the rows under it (down to the next phase) get a soft band in its colour, and the phase shows one thin bar from its first to its last day.
- 4 tools with their word under them: Bar, Milestone, Phase, Comes after.
- The bar for a chosen bar: its dates in words, Name, Colour (the 9 colours of the app), Dates, To do, Copy, Remove.
- A **Dates** page with Starts and Ends, Cancel and Save.
- Return on a chosen bar makes the next bar in the row below, starting the day after, already joined.
- **Send to PARAGON** understands a timeline: as a project the phases are headings and the bars are tasks in date order with their start and due day; as a note the bars are listed with their dates. The picture that goes along shows the timeline.
- The made-up sample boards got a 8th board, "Build timeline" (2 phases, 7 bars, 1 milestone, 5 arrows, placed round today).

**The stored format is now 2** (before: 1). A timeline written by 0.2 opens in 0.1 as a board that can be looked at and not changed — 0.1's own rule. Boards made in 0.1 open as before and stay ordinary boards.

## 2. How it works (guide text)

**Timeline**

A timeline is a plan over time: one row for each thing to do, a bar from its first day to its last. Start one with **New board ▸ Timeline**; it opens with a small example that begins today.

- **Add a row** — press **Bar** at the bottom (or the key B). The bar appears under the chosen row, starting today, and you type its name straight away. **Milestone** (M) is a single day, shown as a diamond. **Phase** (P) is a heading: the rows under it belong to it and get its soft colour.
- **Move a bar** — drag its middle sideways to another day. Drag it up or down to put it in another row. While you drag, its dates show above it.
- **Make it longer or shorter** — choose the bar, then drag the round grip at one of its ends. A bar is never shorter than one day.
- **Comes after** — choose a bar and pull the small dot behind its end onto the bar that comes after it. Or press **Comes after** (A), then the bar that comes first, then the one after it. An arrow joins them. From then on, when you move or lengthen the first bar, the ones after it are pushed along; a line at the bottom says how many moved. A bar cannot start before the bar it comes after has ended. To take an arrow away, press it and press Remove.
- **The next bar** — choose a bar and press **Return**: a new bar appears in the row below, starting the day after, already joined, and you type its name.
- **Rename** — press a name or a bar twice, or choose it and just type. On the iPhone, choose it and press **Name**. Return ends the typing, Escape cancels it.
- **Reorder the rows** — drag a name in the left column up or down.
- **Dates** — choose a bar and press **Dates**: set Starts and Ends, then Save. Changing Starts moves the whole bar (its length stays); changing Ends makes it longer or shorter. Cancel, or Escape on the Mac, leaves it as it was.
- **Colour, To do, Copy, Remove** — in the bar that shows for the chosen row. To do marks the row with the purple tick; it goes to PARAGON as a task. Copy puts a copy in the row below. Delete on the keyboard removes.
- **Zoom** — the two zoom buttons step between **Days**, **Weeks** and **Months** (also a pinch, or ⌘+ and ⌘−). The frame button shows the whole timeline (⌘0). **Today** (T) brings the red Today line into view.
- **Slide** — drag an empty place or the dates; on the Mac scroll with two fingers.
- **Keys on the Mac** — ↑ ↓ choose the row above or below; ← → move the chosen bar a day (with Shift a week); Return = next bar; Space = rename; Delete = remove; Escape = choose nothing; ⌘A = all rows; ⌘D = copy.

**Sending a timeline to PARAGON**

- **As a project** — each phase becomes a heading, each bar a task. The tasks stand in date order. A task carries the bar's last day as its date in PARAGON and its first day in words: "Foundation (starts 8 Dec)". A milestone is a task on its day. The project's own due date is the last day on the timeline. What comes after what is listed under Notes.
- **As a note** — the picture of the timeline, then every row with its dates ("Permit: 1 Dec – 5 Dec 2026 · 5 days"), then what comes after what.
- **Only the to-do boxes** — as on every board: the rows marked To do go to the Inbox.

## 3. Spec

### Stored (format 2)
- `Board.currentFormat` = **2**. `Board.canBeChanged` is unchanged (`format <= currentFormat`): an app that knows 1 shows a format-2 board read-only; this app shows a format-3 board read-only. A file without `format` still reads as 1. New boards of every kind are written with 2 (as before with 1: a new board takes the current format). A board loaded with format 1 keeps 1.
- Board: new optional `kind` (String). `"timeline"` = a timeline; missing = an ordinary board. Own coding key line `case kind`.
- ItemKind: new `bar`, `milestone`, `phase` (own `case` line). Words: Bar, Milestone, Phase.
- Item: new optionals `start`, `end` (ISO days `"2026-12-01"`), `row` (Int, 0 at the top). Own coding key line `case start, end, row`. All three are left out of the file when nil, so a 0.1 board is written back without them. A milestone keeps only `start`. A phase has neither. `x`, `y`, `w`, `h` of timeline items are not used: place and length on screen always come from the days and the row.
- "Comes after" is an ordinary `Link` (`from` = the forerunner, `to` = the follower).
- Not stored: the scale and the place of the view (they are chosen fresh when the board opens: the whole timeline).

### Rules (Core `Timeline.swift`, tests in `TimelineTests.swift`, 19 tests)
- `Day`: a calendar day as a whole number (days since 1 Jan 1970), from/to ISO text, weekday (Monday = 0; weeks start on Monday), week start, month start, "1 Dec", "1 Dec 2026". No clock and no time zone in it.
- `TimeScale`: days 28 pt/day, weeks 8 pt/day, months 2.4 pt/day. New bar length: 3 / 7 / 30 days. Air either side: 3 / 7 / 21 days. `fitting(days:width:)` = the closest scale at which the days fit.
- `TimelineGeometry`: `x(of: day)`, `day(atX:)`, `days(forDrag:)` (rounds to the nearest whole day), `y(ofRow:)`, `row(atY:)`, `bar(from:to:row:)` (1 pt in from each day edge, at least 4 pt wide), `diamond(on:row:)` (middle of the day, side = bar height − 2), `todayX` (middle of today), `ticks` (days: every day's number, Mondays strong; weeks: every Monday "1 Dec"; months: every 1st "Dec"), `heads` (the small words above: month + year over days, the year over weeks and months), `arrow(from:to:)`.
- Arrow: out 8 pt from the end of the forerunner, down (or up) to the follower's row, in to its start. When the follower starts less than 14 pt to the right, the arrow runs back along the line between the two rows (6 points). Corners rounded with radius 4, line 1.4 pt, small filled head.
- Rows: `timelineRows` = all bars, milestones and phases by `row` (ties in the order made). `moveRow(id, to:)` renumbers 0…n−1. One thing per row.
- `shift(ids, byDays:)`, `stretch(id, .start/.end, to:)`, `setDates(id, start:, end:)` — each returns how many OTHER bars were pushed.
- `settle`: (1) a moved bar that now starts before the end of a bar it comes after is put on the day after that end; (2) every follower that starts on or before its forerunner's last day is moved to the day after it, keeping its length, and so on down the chain. Bars are only pushed later, never pulled earlier.
- `stretch(.start)`: never past its own end, never before the day after its forerunners' latest end. `stretch(.end)`: never before its own start; pushes followers.
- `comesAfter(follower, after: forerunner)`: refused for a phase, for the same pair twice, and when it would close a ring (`leads(from:to:)`).
- `addBarAfter(id)`: row below, starts the day after, as long as the source (7 days after a milestone), the source's colour, joined.
- `duplicateRows`: the copy goes into the row under its original; arrows are not copied.
- `phaseGroups`: a phase holds every row under it down to the next phase; its days = first start … last end of its bars.
- `timelineRange(today:air:)`: first bar's start − air … last bar's end + air, widened to hold today.
- `timelinePicture()`: scale that fits 1100 pt, starts on a Monday (months: on the 1st), names column 120–260 pt by the longest name.
- New bar colours: taken in turn from the 7 branch colours; milestone purple; phases in turn teal, blue, orange, green, pink, purple.
- `countLine` for a timeline: "6 bars · 1 milestone · 2 phases" / "Empty". "Copy the board as text" gives the note's row list.

### PARAGON (read-only look at `~/Developer/AMS-PARA`, build 339: `TaskParser.swift`, `Note.swift`)
- A task line carries one day of its own: ` >2026-12-14` (PARAGON's "due"; the mark must stand alone between spaces or at the line's end). There is **no start or defer day** on a task. `@deadline(…)` exists, but PARAGON counts a task overdue from the earlier of the two, so "do on the first day, in by the last" would turn a running bar red on its second day. Therefore: the bar's **last day** is written in PARAGON's own form, the first day in plain words.
- Task line: `- [ ] Foundation (starts 8 Dec) >2026-12-12`. The year is added to the words when start and end are in different years: `(starts 28 Dec 2026) >2027-01-06`. A one-day bar and a milestone: `- [ ] Roof on >2027-02-20`.
- Project note: front matter as before plus `due: <last day on the timeline>` (PARAGON reads a project's own due date from that line); `## Outcome` = the title; `## Tasks` = the rows above the first phase, then `### <phase>` with its tasks, each group in date order (first day, then last day); `## Notes` = "- Walls comes after Foundation" lines; `## Log`.
- Note: `## Timeline` (rows with dates; a phase bold, its rows indented; "(milestone)" after a milestone's name), `## Comes after`, `## Tasks` (rows marked To do, as task lines with their dates).
- Only the to-do boxes: unchanged (`inboxTasks`).
- Seedboard still only adds new files.
- Shared-file changes in `Paragon.swift`: one line at the top of `note()` and of `project()`; `frontMatter`, `head`, `section`, `stamp` lost the word `private` so the timeline text uses the same ones.

### Screen
- New files: `TimelineView.swift` (input), `TimelineDraw.swift` (`TimelinePainter`, draws the live board and the picture), `TimelineBars.swift` (tools, zoom, chosen-bar bar, Dates page), `TimelineSession.swift` (the session's timeline side).
- Sizes: names column 170 pt (iPhone / narrow: 104); dates band 44 pt; row 34 pt and bar 22 pt on the Mac, row 40 and bar 24 on iPhone and iPad; bar corner radius 7; names 13 pt (Mac) / 15 pt; phase names semibold in the phase's colour; rows under a phase stand 10 pt further in; a milestone's name has a small diamond before it.
- Colours: bars `Paint.line(name)` (day and night sets); phase band `Paint.soft` at 55 % (night 40 %); phase's thin bar 6 pt at 80 %; weekend columns (Days only) edge colour at 20 %; date lines edge colour; Today line and tag `Paint.line("red")`, line 1.6 pt, white "Today" in a red capsule in the top of the dates band (a small word that would touch it is left out); today's number is red at the Days scale; chosen row: soft green plate in the names column and a 2 pt green ring round the bar; grips: 12 pt white circles with a green edge at both ends; the dot: 10 pt green circle 20 pt behind the end, joined by a dotted line; To do: the purple tick at the right of the name.
- New part colour `Part.timeline` (0xC4551F day, 0xF59A66 night) for the Bar tool, the Colour and Dates chips, the Today button, the Dates page and the starter.
- Press areas: grips ±12 pt outward (on a short bar only their outer side, so the middle can still be moved); dot ±11 pt; bars +4/+5 pt; arrows within 7 pt.
- Drags: bar middle = days (nearest whole day) and, one bar alone, rows (from 0.7 of a row up or down); grip = that end; dot = pull a "comes after" line (dashed ring on the bar it would land on); name = reorder rows; empty place or dates = slide. A press on the dot switches "Comes after" on from that bar.
- Several rows chosen (Shift on the Mac, Choose more elsewhere): they move together by days; bar shows To do, Copy, Remove.
- The chosen bar's buttons stand at the bottom above the tools (at the top they would cover the dates). The "comes after" hint and the read-only notice stay at the top.
- Zoom: buttons step the scale; a pinch, ⌘-scroll, ⌘+ / ⌘− add up and step once per factor 1.2; the day under the pointer stays in place. The rows cannot slide further than the last row plus room for the tools (150 pt; iPhone 215).
- Undo: every change is one step through `BoardSession` (a drag, a stretch with everything it pushed, a row move, Dates Save, a new bar, a join). Typing a name is its own step, as on every board.
- Read-only (newer format): everything can be looked at and slid; nothing changes.
- Hooks in shared files (all one or two lines): `BoardSession` (`timeline` state; `paste`, `duplicateSelection`, `pan`, `zoom`, `fit`, `reveal`), `BoardView` (canvas ↔ timeline, empty words, hint words, Paste menu item off, the three bars switch to the timeline ones, one extra case), `CanvasDraw` (`BoardPainter.draw` hands a timeline to `TimelinePainter`; two extra cases), `CanvasView` (`ScrollCatcher` no longer private), `RootView` (starter mark and colour), `Theme` (`Part.timeline`), `SendSheet` (two descriptions), `Sample`, Core `Board`, `BoardEdit` (`bounds`, `countLine`), `Outline` (`outlineText`), `Starters`, `Paragon`.

### Identifiers
`starter.timeline`, `timeline.canvas`, `timeline.empty`, `board.count`, `board.field`, `board.fieldDone`, `board.tools` › `tool.bar`, `tool.milestone`, `tool.phase`, `tool.after`; `timeline.zoom` › `zoom.out`, `zoom.value` (Days / Weeks / Months), `zoom.in`, `zoom.fit`, `timeline.today`; `board.selectionBar` › `sel.days`, `sel.name`, `sel.colour`, `sel.dates`, `sel.todo`, `sel.copy`, `sel.more`, `sel.remove`, `sel.after`; `board.colours` › `colour.<name>`; Dates page: `dates.start`, `dates.end`, `dates.length`, `dates.cancel`, `dates.save`. All existing identifiers are kept.

## 4. For the lead

**Launch arguments for pictures** (all with `-sampleData` last)
- `-board timeline` — opens the sample "Build timeline" (the only sample title with that word).
- `-pick <word>` — chooses the row with that word, e.g. `-pick Foundation` (grips, dot, the bar's buttons), `-pick Shell` (a phase), `-pick "Move in"` (milestone).
- `-scale days|weeks|months` — that scale, with today a third of the way in (read in `TimelineView`, not in `AppModel`).
- `-dates` — with `-pick`: opens the Dates page of that bar (read in `TimelineBars.swift`).
- `-send`, `-night` work as before.
- Suggested set: `-board timeline -pick Foundation` (day + night, Mac / iPad / iPhone); `-board timeline -scale days -pick Walls`; `-board timeline -scale months`; `-board timeline -pick Foundation -dates`; `-board timeline -send`.

**Screen test**: `UITests/TimelineUITests.swift` — 1 test (`testANewTimelineTakesABarShowsItsDatesAndZooms`). Written and compiled (`build-for-testing` on the Mac), not run.

**Changed existing tests**: `StartersTests` — the list of starter names now ends with "Timeline"; the "no starter overlaps its shapes" test skips the timeline (its bars are placed by days, not by frames).

**Icons** — used: `Glyph.new(.bar)` (Bar tool), `.new(.milestone)` (Milestone tool), `.new(.today)` (Today button), `.new(.calendar)` (Dates chip and page), `NewMark.timeline.standIn` (starter row; `StarterPicker.mark` returns an `AppMark`).
- `ICON-WANTED: phase — a short heading line with two shorter bars under it, in a soft band` (now: the frame mark).
- `ICON-WANTED: comes after — a bar, then a right-angled arrow down to a second bar` (now: the arrow mark).

**Left open / to decide**
- The project's `due:` line (last day of the timeline) is my addition to the brief; one line in `timelineProject` if it is not wanted.
- `>` carries the bar's LAST day (the brief's rule). The other way round — `>first day @deadline(last day)` — is possible in PARAGON, but makes a running bar overdue from its second day.
- An ordinary board made in 0.2 is written with format 2 as well (the format is per app version, as before). If only timelines should lock out 0.1, the board's format would have to be raised only when something new is on it — the lead's call together with the other format-2 picks.
- The scale and the place of a timeline are not remembered between openings (pick 26 is about that).
- A phase moves alone when its name is dragged (its rows do not travel with it); dragging a phase's thin bar does not move its bars.
- Pasting a list does nothing on a timeline (menu item greyed out there). A list → bars would be a new feature.
- The other builders' new things in the tool pill / selection bar (picks 7, 9, 10) do not reach the timeline's own three bars in `TimelineBars.swift`.
- `Core/BoardTests.swift` and `Core/StartersTests.swift` lie loose beside `Package.swift` (not part of any target) — not mine, not touched.

**Only a real device (or the lead's run) can prove**
- Nothing was launched: the look was checked from off-screen renders of the painter only (Mac size weeks/day, days/night; iPhone size months/day, weeks/night; the PARAGON picture). The bars at the bottom, the name field's place, the Dates page and all drags were never seen on a screen.
- Finger feel: grip and dot sizes on iPhone, the pinch stepping through the scales, dragging a name to reorder while the list is scrolled, the keyboard covering the names on the iPhone.
- Trackpad scroll and pinch on the Mac over the timeline; keys reaching the timeline after a button was pressed (the known B1 trap applies here too).
- The first real Send of a timeline into the real PARAGON notes (dates read as due days; the project's `due:`).
