# Lane "tick" — pick 28: a box ticked on a board ticks its task in PARAGON

## What's new
### Seedboard
- Before: a bar or milestone you marked done on a board stayed on the board; PARAGON's task stayed open. Now: marking it done (the Done button on a timeline board) also tells PARAGON, which ticks that one task. One line per thing; only things that became PARAGON tasks.
- Unticking on the board does nothing in PARAGON.
### PARAGON 341
- Before: PARAGON only learnt about Seedboard boards by reading its notes. Now: when it files its waiting list it also ticks the task a Seedboard board says is done — only when exactly one open task has exactly those words in the Inbox or in the named note or project. Otherwise nothing changes and nothing new is made.

## How it works
- Seedboard: "Mark a bar or milestone done and, if it was sent to PARAGON as a task, PARAGON ticks it the next time it opens. Taking the mark off here changes nothing in PARAGON."
- PARAGON: "A box ticked on a Seedboard board ticks its task here: the one open task with the same words, in the Inbox or in the note or project the board went to. If there is none, two, or it is already ticked, nothing happens."
- An older PARAGON (340) skips the line without filing anything.

## Spec
- Seedboard: `Core/Sources/SeedboardCore/Tick11.swift` (`ParagonExport.DoneLine`, `doneData`, `Board.doneLines(since:now:)`); hook in `BoardSession.change` (`onTicked`), `AppModel.tellParagonTicked`, `ParagonGate.appendDone`. Appends to the same `capture-outbox.jsonl` (O_APPEND). Nothing for sample boards or when no waiting list. Undo/redo write nothing.
- Line: `{"kind":"seedboardDone","words":"<SentTask.words>","board":"<title>","place":"inbox"|"note","path":"Projects/X.md"(note only),"when":"<ISO 8601>"}`. No `id`, no `text`.
- A note-place task needs `Board.sent.path`; without it no line.
- PARAGON 341: `CaptureItem.seedboardDone` (`SeedboardDone`), custom Codable in `Capture.swift`; `Vault.tickSeedboardDone`; used in `AppModel.drainOutbox` (not counted as "filed", no message). Ticks with `Note.complete` (`- [x] … @done(day)`, repeat next copy). Match = same task line ignoring id/box/done. Unknown `kind` = line skipped. Note still downloading = line kept for a later try.
- Tests: `Tick11Tests` (Seedboard), `SeedboardDoneTests` (PARAGON).

## Pictures
Nothing to see.

## Not done / doubts
- The only "tick" a board has for a sent thing is Done on timeline bars/milestones (`doneDay`); the to-do ring and tick-list lines in notes are not tied to PARAGON tasks, so they write nothing.
- Needs PARAGON 341 shipped to have an effect; before that the line is harmlessly skipped.
