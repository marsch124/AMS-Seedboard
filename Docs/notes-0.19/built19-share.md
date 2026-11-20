# Seedboard 0.19 — lane "share" (picks 43, 44, 46)

Branch wt19-share. Core: `Core/Sources/SeedboardCore/Share19.swift`; app: `App/Sources/Share19.swift`. Tests: `Core/Tests/SeedboardCoreTests/Share19Tests.swift` (4 tests), `UITests/Share19UITests.swift` (written, built, not run).

## 43 Share Picture of This Frame
- Before: "Share this…" on a chosen frame opened the Share plate; no one-tap picture of one frame. Now: a line that makes a PNG of only that frame and what lies in it and opens the system share choice at once.
- Words: **"Share Picture of This Frame"** (share mark `.new(.share)`, the same as "Share…"; no new SF Symbol).
- Where: the bar of one chosen frame (`sel.frame.picture`, mark and word on Mac/iPad, mark only on iPhone, drop order 4 — before "Send this frame to PARAGON…"); the frame's menu (`menu.frame.picture`, right-click / press and hold); Mac File menu after "Share…" (grey unless exactly one frame is chosen).
- Picture: the same renderer as the board picture (`BoardPicture.png`: white, day look, 40 air, 2x), pictures read from their files (as Share does). Content = frame + things whose middle lies inside it (+ everything under an idea, arrows between them) — the same "inside" rule as "Send this frame". File name = frame's words ("/ : \" become "-"), else "Frame" (`Board.framePicture(of:)`, title set there).
- Works on read-only boards too (it changes nothing). Not on boards that place themselves. Failure line: "The picture could not be made." (red).
- Not seen running (no simulator). An empty frame still gives a picture of the empty frame.

## 44 Preview on the Send page
- Before: the page had the picture-and-rows box "What PARAGON gets". Now: that box stays and a **"Preview"** part (`send.preview`, text `send.preview.text`) sits under it: the first 8 lines of the text that is written, small monospaced caption in a soft rounded box; button **"Show all (N more lines)"** / **"Show less"** (`send.preview.toggle`), shown only when more than 8 lines. Text is selectable.
- Follows the choice (As a note / As a project / Only the to-do boxes / Add what is new), the name, the frame/branch/chosen switches and "Say where they come from".
- Built from the same function: new `ParagonExport.handoverText(project:board:title:picture:now:choices:)`, which `ParagonGate.send` now calls to write the file and the Preview calls. The Preview uses picture name "picture.png" and the current time (the real file has the real picture name and send time). Inbox rows: the exact lines `inboxSend` / `addSend` hand over. Test: preview text == written text (note and project).
- Note: the note text starts with its front matter (--- block); it is shown as written.

## 46 Paste a checklist
- Forms read (`Checklist.parse`): "- [ ] x", "* [ ] x", "+ [ ] x", "[ ] x", "☐ x" = open; "- [x]", "* [x]", "[X]", "☑", "☒", "✓", "✔" = done; "• x", "◦ x", "– x", "- x", "* x" = open (bullets). Every non-empty line must start with a mark and at least one must be a box/tick; otherwise paste is exactly as before (bullets alone stay a plain list/map).
- Result: ideas, each marked To do (`Item.todo = true`); a ticked line also gets `Item.doneDay` = today. Open = the existing purple hollow to-do ring. Done = the EXISTING "done" mark: green ring with white tick, words greyed (`TodoState.done`, the mark a task ticked off in PARAGON has). To show it, `Board.todoState(of:)` now returns `.done` for a non-timeline thing with To do + `doneDay` (timeline bars unchanged, they have `isDone`). `doneDay` on ideas already existed (Access11 says "done" aloud).
- Layout: no idea chosen → a small map with centre "Checklist" (one line: just that idea) at the paste spot; one idea chosen → lines hang under it. All in the one existing undo step (`session.change`); not on read-only, timeline or Who-does-what boards (those keep their old paste).
- Taking To do off such an idea also clears its done day (BoardSession.toggleTodo), so it is a plain idea again.
- Left out / to decide: Send to PARAGON still sends a done idea as an OPEN task (only done timeline bars are skipped, `Paragon.swift:165`); nesting by indent is not kept (flat list); the "Paste a List as a Mind Map" menu line is unchanged.

Signs: no new marks or colours. Done ring/tick (green) now also appears on pasted ticked ideas — same meaning (done); hollow purple ring = to do; the Preview heading is PARAGON purple like "What PARAGON gets".
