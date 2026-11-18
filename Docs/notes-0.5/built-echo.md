# Built in 0.5 — lane "echo" (pick 16, the reading half)

Finding 1 of `panel-thought-to-action.md`: **the board shows what is sent and done.** Seedboard now READS the note a board became in PARAGON and says how far it is. It never writes, moves, renames or removes anything there, and it writes no `^t…` ids.

## What shows on screen

### 1. The line on a board that is a note or a project in PARAGON
One small purple line (a soft purple capsule with a thin purple outline, the hand-drawn send mark 13 points in front, words in PARAGON's purple, the app's "pill" text size):

- `Project “Summer cabin” · 5 of 13 done · checked 14:02` followed by a small full-purple pill with white words **Open in PARAGON**.
- A note says `Note “…”` instead of `Project “…”`.
- When the note holds no task of the board: `Note “Ideas” · checked 14:02`.
- Read on an earlier day: `… · checked 17 Nov 14:02` (the day and the 24-hour time).
- PARAGON's notes are not on this device, or iCloud has not brought the note yet: `Project “Summer cabin” · not checked on this device yet` (Open in PARAGON stays).
- No note in PARAGON's folder holds the board's link any more: `Project “Summer cabin” · no longer in PARAGON's notes` (no Open in PARAGON).
- Too narrow for the whole line (iPhone): `Project “Summer cabin” · 5 of 13 done` with the pill **Open**; still too narrow: the words are cut in the middle.

Where: under the board's top bar, in the middle, above the bar of what is chosen. On a **timeline** and a **"Who does what"** board it sits at the bottom, just above the tools, because their top holds the dates and the names (under the top bar it covered the months and "Today"; seen and moved).
Not shown on a starter's working copy, and not on a board that was never sent as a note or a project.

### 2. The count
`5 of 13 done` = of the board's things that are found as tasks in the note, how many are ticked off there. Left out of both numbers: tasks cancelled in PARAGON (as PARAGON's own project count does), tasks that were re-worded or taken out in PARAGON, and things no longer on the board. (PARAGON's own project count counts top-level tasks only, so its number can differ.)

### 3. The marks on the things (`ParagonEcho`)
What was read is laid over the board's own knowledge: a thing whose task is ticked in the note is `.done`, cancelled there `.cancelled`, still open there `.inParagon`. A re-worded task simply stays "in PARAGON". The marks themselves are drawn by the `looks` lane from `todoStates`; after a reading the open board is drawn again at once.
A board sent by 0.4 kept no words: its things are matched by the task lines it would send now, so its ideas and shapes get their marks too, also the ones that were never ticked "to do" (one line changed in `Feel.swift`, see below).

### 4. Open in PARAGON opens the note that was found
All three "Open in PARAGON" (the new line, the Send page's "Last sent", the list's press-and-hold menu) now open the note under the title it has NOW in PARAGON — also after it was renamed or moved to the Archive there. Before: by the title it was sent under, so after a rename it opened nothing.

### 5. The card and the row
- Home page card: `Changed 2 days ago · 5 of 13 done`. A card is narrow: when that does not fit it says `2 days ago · 5 of 13 done`, and when that does not fit either `5 of 13 done`. (Seen on the Mac: the card showed "2 weeks ago · 2 of 4 done".) A board with nothing to say keeps exactly "Changed 2 days ago".
- iPhone list row: `Changed 2 days ago · 5 of 13 done · 5 shapes · 5 notes`.
- The narrow list beside an open board (Mac, iPad) shows no "Changed …" and so got nothing.

## How it reads (the rules)

- **When:** a sent board opens · right after a Send · when PARAGON's notes are found after the start · when Seedboard comes to the front (the Mac: `didBecomeActive`; iPhone and iPad the same), at most once in 15 seconds. Coming to the front and the start look at every sent board, so the cards are right too. Always off the main thread.
- **Where:** first where the note was found last time, then where Seedboard wrote it (`SentInfo.path`). A note there counts when it holds the board's own link `seedboard://board/<id>`.
- **Gone from its place** (renamed, moved to the Archive): every note in PARAGON's folder that is on this device is looked through for that link. If several hold it (a second Send, a sent branch), the one with most of the board's tasks wins, then the newest. Opening or sending a board searches at once; by itself a board whose note is gone is searched again at most every 10 minutes.
- **Never fetched in bulk:** a note iCloud has not brought is passed over in the search; hidden folders (PARAGON's settings, safety copies, Deleted) and `Pictures` are not looked into; a note over 2 MB is passed over. Only the ONE note at its known place is asked for from iCloud when it is not here yet.
- A note that stands where Seedboard wrote it but no longer holds the link (the line was taken out by hand) is still taken when no other note holds the link.
- **A task line** is read by PARAGON's own rule (`- [ ]`, `* [x]`, `+ [X]`, `- [-]`, `- [>]`, also indented; not inside a ``` or ~~~ block). `x`/`X` = done, `-` = cancelled, blank or `>` = still to do.
- **Matching** is by the words that were sent (`board.sentTasks`), with PARAGON's own marks lifted out on both sides: `^t3fa2c1`, `@done(…)`, `@repeat(…)`, `@since(…)`, `@deadline(…)`, the first `>2026-12-05` (with or without a time), `!` `!!` `!!!`, `~45m` `~1h` `~1h30m`; spaces squeezed. So "Permit (starts 1 Dec) >2026-12-05" still matches after PARAGON ticked it and wrote "@done(…)" and its id behind it, and after the day was moved in PARAGON.
- First the things that went into the note, then those that went to the Inbox (an Inbox to-do he filed into the note by hand is then found there). Two things with the same words take the lines with those words in the note's order.
- A board that keeps no words of a thing in the note (sent by 0.4): matched by the task lines it would send now as the same kind (note or project) — mind map, shapes, lanes, timeline bars with their days, "Who does what" messages.
- **The title** shown and opened is the note's `title:` line (PARAGON writes it at a rename), else its file name.
- **Kept on this device only:** `Application Support/Echo/read.json` (board → where the note was found, its title, the states, the two numbers, when it was read). Never in a board file, never in iCloud. Dropped for boards that are gone. With `-sampleData` or `-paragonFolder` nothing is written.

## Files

New: `Core/Sources/SeedboardCore/Echo.swift` (`ParagonRead`: all rules, pure text), `Core/Tests/SeedboardCoreTests/Echo05Tests.swift` (11 data tests), `App/Sources/ParagonLook.swift` (`ParagonGate.look`, reading only — kept out of `ParagonGate.swift` so the `send` lane has that file alone), `App/Sources/EchoKeeper.swift` (when it looks, what is kept), `App/Sources/SentLine.swift` (the line, and `DoneWords` for the card), `UITests/EchoUITests.swift`.

Small hunks in existing files:
- `AppModel.swift`: one line in `init` (`EchoKeeper.shared.watch(self)`), one line in `openInParagon` (the found title).
- `BoardView.swift`: `SentLine(session: session)` as the first line of the top stack, `SentLine(session: session, low: true)` before `TimelineSelectionBar`.
- `HomeView.swift` (`BoardCard`): one observed object, `Text(board.changedWords())` → `DoneWords(…)`, the card's spoken label gets the same tail.
- `RootView.swift` (`BoardList`): one observed object, the iPhone row's words.
- `Feel.swift` (`ParagonEcho.marks`): the read state is also laid over a thing the board itself does not know as sent (`|| marks[id] == nil`), and the comment on `read` (it now also keeps `.inParagon`). Needed for boards sent by 0.4.

No stored field added. Board format untouched. `project.yml` untouched.

## Identifiers
`board.sentLine` (the line, a container), `board.sentLine.words`, `board.sentLine.open`.

## Launch words
- `-echoEvery <seconds>` (DEBUG): looks again by itself, for trying it on a throwaway folder.
- For a picture: `-ApplePersistenceIgnoreState YES -paragonFolder <copy of the example notes> -board Workshop -sampleData` (put a note `Projects/Workshop bench.md` with task lines "Step 1" … "Step 5" into the copy), or `-sendNow project -echoEvery 2 -board Garage` and then change the note by hand.
- Trap seen: `-night` directly in front of another launch word swallows it (`-night -ApplePersistenceIgnoreState YES` → no window came). Put `-night` just before `-sampleData`.

## Marks wanted
None (the line uses the send mark that is already there).

## Tests
- 11 data tests in `Echo05Tests.swift`, one per rule: PARAGON's task lines · words without PARAGON's marks · matching by the words sent · re-worded stays "in PARAGON" and twins in order · an Inbox to-do filed into the note · a 0.4 project · a 0.4 timeline with its days · the board's link and the note's title · the line's words · "checked" today and on another day · a reading kept and read back. All 305 rule tests pass.
- One screen test `EchoUITests.testASentBoardSaysWhatItBecameInParagon` (the line on the sent sample board, none on an unsent one). It compiles; it was NOT run.

## Seen running (Mac debug build, sample boards, a scratch copy of the example notes)
- Day: "Project “Workshop bench” · 2 of 4 done · checked 15:58" with Open in PARAGON (2 ticked, 1 cancelled, 2 open in the note).
- Night, after a real Send into the scratch copy: "Project “Garage shelves” · 0 of 5 done · checked 16:02"; then the note renamed to "Garage shelves 2027", moved to Archive, two ticked, one cancelled → "Project “Garage shelves 2027” · 2 of 4 done · checked 16:02"; then the note taken away → "Project “Garage shelves 2027” · no longer in PARAGON's notes".
- A timeline sent into the scratch copy: "Project “Build timeline” · 0 of 7 done" above the tools.
- The home card: "2 weeks ago · 2 of 4 done".

## NOT built
- Reading back a branch that was sent alone: such a Send leaves no place on the board (`sent` stays empty), so there is no line and no done marks for it; its ideas show "in PARAGON" through `sentTasks` (groundwork + the `send` lane).
- Reading the Inbox: a to-do that went to the Inbox stays "in PARAGON" until he files it into the board's own note.
- "5 of 13 done" in the narrow list beside an open board (Mac, iPad).

## NOT seen running
- iPhone and iPad (no simulator for this lane): the narrow form of the line with "Open", the iPhone row.
- A press on Open in PARAGON (it would have opened his PARAGON).
- A note that iCloud has not brought yet, and his real PARAGON folder (never touched).
- Coming to the front as the trigger (tried with `-echoEvery` instead).
- The marks on the things: the `looks` lane draws them; here only the states were filled.

## For the lead at the join
- The `timeline` lane adds its own line ("3 of 8 done · 1 late · ends 20 Feb"): look once that it and this line do not sit on each other on a sent timeline.
- The `feel` lane moves the line at the bottom ("flash") to the window's level: on a timeline the PARAGON line sits right above where the flash was.
- The Send page's "Last sent … “title”" (the `send` lane's file) still names the title the note was sent under; its Open in PARAGON already opens the found note.
- After the `send` lane is joined: check once on a scratch copy that a thing it records with `noteSent(…, place: .note)` gets its done mark (the words it keeps must be the task line without "- [ ] ").

## Drive-by problems seen and left
- `-night` swallowing the next launch word (above).
- The iPhone row's count line is cut earlier now on a sent board ("… · 5 of 13 done · 12 ideas · 5 sha…"): one line, the tail goes first.
