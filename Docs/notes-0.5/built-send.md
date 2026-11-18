# Built in the `send` lane (0.5) — picks 17, 19, 20 and the Send-side bugs

Panel findings: `panel-thought-to-action.md` 2, 5 (a, b, c), 6, 9 (safe variant); `panel-thinking-flow.md` 1.
The rule stays: Seedboard only ADDS to PARAGON — a new note, a new picture, lines appended to the waiting list `capture-outbox.jsonl`. It reads PARAGON's notes; it never opens an existing PARAGON file for writing.

## What became a task is remembered at every Send
- Every task line of a note, a project and the Inbox is written through one place (`ParagonExport.taskLine`, `SendTasks.swift`), which also notes the thing and the exact words sent. Send stores them with `board.noteSent(…)` (`Board.sentTasks`): place `note` for "As a note", "As a project" and a sent branch; place `inbox` for "Only the to-do boxes"; for "Add what is new" the place where the lines went.
- Taking the To do tick off a thing forgets its Inbox entry (as before for `sentTodos`), so ticking it again sends it again. Its entry for a note stays.
- Removing a thing forgets its entry. A copy never carries entries: Make a copy, a board imported from an export, an earlier version brought back as a copy, a board made from a starter (all now clear `sentTasks` as well as `sent` / `sentTodos`).

## Bug fixed: a box already in the Inbox is not a second task
In a note or a project, a thing that already went to the Inbox as a to-do is written as a plain line:
`- Permit (already in the Inbox)` — never `- [ ] Permit` again. The count line under the box says "1 already in the Inbox". The row "As a note" then says "The 2 to-do boxes become tasks in it." counting only the boxes the Inbox does not have.

## 17 — "Add what is new to “<title>”"
- When the board already went to PARAGON as a note or a project and holds things that have become tasks since, the Send page has a NEW FIRST ROW, chosen when the page opens:
  **Add what is new to “Summer cabin”**
  - note at its place: "3 new tasks go into the project. Nothing that is there is touched." (1: "1 new task goes into the project. …"; a note: "… into the note. …")
  - note not at its place (renamed, moved, removed in PARAGON): "The project is not where it was: the 3 tasks go to the Inbox." (1: "the task goes to the Inbox.")
- Seedboard looks first (reading only, off the main thread, `ParagonGate.look`): the note at `SentInfo.path` there / not yet brought by iCloud (a `.Name.md.icloud` file counts as there) / gone. Only a path inside PARAGON's folder is looked at.
- What is new: a board sent by 0.5 — every task thing not in `sentTasks`. A board sent by 0.4 (no list) — the note is READ, and a thing whose words already stand there as a task line is not new (those are remembered from then on); if that note cannot be read, no row is offered (better no row than the same tasks twice).
- Send writes ONLY lines to the waiting list. Note there: each line is aimed at it (`target: note(path: "Projects/Summer cabin.md")`, exactly PARAGON's `CaptureTarget`), and PARAGON files it itself at the end of that note's "## Tasks" (`Vault.capture` → `Note.append(task:)`; checked in PARAGON's code, build 340). Note gone: the lines go to the Inbox, with their way back (below). New bars of a timeline go with their days.
- What cannot follow is said, under the box: "2 things were renamed and 1 bar moved since 18 Nov. PARAGON keeps the old ones." (one: "PARAGON keeps the old one.") A bar counts as moved when only its days changed. With the add row chosen, beside it: **Send a fresh copy** (goes to "As a project" or "As a note", whichever the board was — today's behaviour, a second note).
- With the add row chosen, the Name field is hidden, and the line at the bottom reads: "Seedboard only hands PARAGON the new lines. PARAGON puts them at the end of the tasks itself; Seedboard never changes a note you already have." (Otherwise, as before: "Seedboard only adds something new. It never changes a note you already have; sending again makes a second note.")
- Sending just one branch (the branch switch on) never offers the add row; switching it on while the add row is chosen goes to "As a note".
- After Send: "1 new task is on the way into “Summer cabin”. They appear there when you switch to PARAGON (PARAGON 340 or newer)." / "3 new tasks are on the way to the PARAGON Inbox. They appear …". Nothing new: "Nothing on the board is new for PARAGON."
- Like the to-dos: the board is marked and stored BEFORE the lines are handed over; if the hand-over fails, the marks come off again.
- Limit (from the note): new tasks land at the end of the Tasks part, not under their own branch or phase heading.

## 19 — The box "What PARAGON gets" (and bugs a, b, c)
- Under the rows and switches: the heading "What PARAGON gets" (caption, PARAGON purple), a box 168 points high that scrolls, then the count line.
- It is read out of the very text Send writes (`ParagonExport.preview(ofNote:)` / `preview(ofTasks:)`), so it cannot differ from what arrives. A note / project: the board's small picture (54 high; a sent branch: the words "The picture"), the parts ("Outcome", "Tasks", "Notes", "Log") bold, headings inside (`###`) semibold purple, tasks with an empty purple box (10 × 10) and their day at the right in purple ("12 Dec"), plain lines grey, indented 14 per level. To-dos and "Add what is new": the task lines. Links show as their name ("Summer cabin"), the day is taken out of the words.
- Count line: "13 tasks · 3 headings · 1 already in the Inbox · last day 20 Feb" (parts left out when 0; "1 task", "1 heading"; "No tasks").
- (a) Words: on the to-dos row and after Send: "They appear there when you switch to PARAGON (PARAGON 340 or newer)." Row: "2 to-do boxes go to the Inbox as tasks. They appear there when you switch to PARAGON (PARAGON 340 or newer)." After Send: "2 tasks are on the way to the PARAGON Inbox. They appear there when …". (The guide still says the old sentence at `Guide.swift:415` — for the texts builder.)
- (b) All ticked boxes already sent: "All 4 to-do boxes are already in PARAGON." (one: "The 1 to-do box is already in PARAGON."). Nothing ticked, as before: "No to-do boxes are waiting. Choose a box and press To do first."
- (c) A timeline, "As a project": "All 6 bars and 1 milestone become tasks with their days." (one thing: "The bar becomes a task with its days." / "The milestone becomes a task with its day.")
- (d) the line after Send with "Open" is the `feel` lane's.

## 20 — Inbox to-dos keep their days and say where they come from; "Start:" reminders
- A timeline bar sent as a to-do keeps its days: "Permit (starts 1 Dec) >2026-12-05" (PARAGON reads the day with its own task reader, so it lands dated).
- Switch **Say where they come from** (on at first, remembered on this device — `UserDefaults` key `send.sayOrigin`), shown with "Only the to-do boxes" and with "Add what is new" when the lines go to the Inbox. On: every Inbox to-do ends with its way back, BEFORE the day: "Order timber [Summer cabin](seedboard://board/<id>)", "Permit (starts 1 Dec) [Build timeline](seedboard://board/<id>) >2026-12-05". When the board is a project in PARAGON that is at its place: "Order timber — [[Summer cabin]]". Square brackets in a board's name become round ones inside the link.
- On a timeline's Send page the switch **Also remind me when a bar starts** (off each time the page opens). On: every bar longer than 3 days gets one more task right before its own, under the same heading: "- [ ] Start: Foundation >2026-12-08" (in a note, a project, the to-dos and "Add what is new"). The box shows them before Send.

## TF 1 (bug) — a named plain frame is a heading
- Note: under "## Notes" first the things that lie in no named frame, then "### Pros" with its things, "### Cons" with its things. Everything in reading order (rows from the top, each row left to right), not the order made. A thing belongs to the smallest named frame its middle lies in. Frames with lanes keep their own rule; a frame with no name gives no heading; a mind map's ideas belong to no frame.
- Project: ticked notes/text inside a named frame become tasks under "### <frame name>"; the others stay under "### To do"; the project's Notes part is grouped like the note's.
- More → Copy the board as text: "Notes:" with the loose lines, then "Pros:" and its lines, "Cons:" and its lines.

## Launch words (Mac debug build; `-sampleData` last)
- `-board Summer -send -sentBefore` — the open board shown as sent a week ago as a project, its last task(s) new and one renamed (page only, nothing stored). `-sentGone` — the same with the project gone from its place.
- `-board timeline -send -sendAs project -starts` — timeline page, "As a project", start switch on. `-sendAs add` chooses the add row.
- `-paragonFolder <copy> -sendNow project+add+todos` — several sends in a row; `add` first lays something new on the board (a ticked note "Order timber", or on a timeline a 10-day bar "Roof"). `-starts` = start switch on, `-noOrigin` = way back off.
- Pictures: `scratchpad/pics-send/add-day.png`, `scratchpad/pics-send/timeline-day.png`.

## New identifiers
`send.kind.add`, `send.gets` (the box), `send.count`, `send.cannotFollow`, `send.freshCopy`, `send.sayOrigin`, `send.remindStarts`. Screen test `UITests/SendUITests.swift` (2 tests) — compiled, NOT run.

## Stored fields
None added (uses the groundwork's `Board.sentTasks`). Device only: `send.sayOrigin`.

## Seen running
On a COPY of PARAGON's Example Vault with `-paragonFolder`: "As a project" wrote `Projects/Summer cabin.md`; then "Add what is new" appended ONE waiting line `{"text":"Order timber","target":{"note":{"path":"Projects/Summer cabin.md"}},"asTask":true,…}`; to-dos after that sent nothing twice. Timeline to-dos with `-starts`: "Start: Find builder [Build timeline](seedboard://board/…) >2026-11-02" and "Find builder (starts 2 Nov) [Build timeline](…) >2026-11-13". Timeline project + add: "Start: Roof >2026-12-27", "Roof (starts 27 Dec 2026) >2027-01-05" aimed at `Projects/Build timeline.md`. The Send page looked at by day on the Mac (both pictures above).

## NOT seen
PARAGON itself filing the lines (PARAGON was not run; its code was read, and a data test reads the aimed line with a copy of PARAGON's reader); how PARAGON shows a `seedboard://` link inside a task row; the page by night; the iPhone and iPad page (built only); the screen tests.

## Left alone (for the lead)
- Now unused, kept to keep the join small: `timelineNote` / `timelineProject` (Timeline.swift), `sequenceNote` / `sequenceProject` (Sequence.swift), `ParagonExport.taskLines` (Paragon.swift).
- The problem line on the Send page is still `.red` (the `feel` lane's tones).
- Join may clash in: `AppModel.send` (feel lane's line after Send), `SendSheet.swift` (feel lane's tick on the Send button), `AppModel.duplicate` (main has the same `copy.sentTasks = []` line), `ExportAll` / `Kept` / `StarterShelf` (one line each, safety lane's files), `ProjectPlan.swift` / `Paragon.swift` (door lane's link line, if it writes into notes).
