# Lane safety — built (ideas 7 to 12)

Rules live in `Core/Sources/SeedboardCore/Safety14.swift`, tests in `Safety14Tests.swift` (5 small tests).

## 7. Share as picture, size limit
- A picture is never made bigger than about 100 million pixels. A board that would pass that is drawn at a smaller scale.
- Share page (Picture chosen): a small grey line under the explanation says exactly: "Shown smaller". Identifier `share.shownSmaller`. Shows only when the board to be shared is that large.
- Not done: no change for ordinary boards (still 2x, 1x above 3,000 points).

## 8. Very large PDF page in strips
- A page whose board is shrunk four times or more to fit the paper, or that holds more than 500 things, is drawn as 4 strips top to bottom, one after the other with the screen free in between. The PDF looks the same. No words, no controls.

## 9. Undo of "Move to a new board"
- Undo also puts the new board away (it is never deleted); it is found under Put away. Notice at the bottom (board notice): "The new board “<name>” is put away." Redo brings it back into the list (only if Undo put it away).
- Only for moves made in this open session (not after the board is closed and reopened).

## 10. Make a copy of a put-away board
- The copy is no longer put away: it is in the list. (Rule moved into Core: `Board.becomeCopy`; all other resets as before.)

## 11. Long shared words
- Share page problem line: "Only the first 20,000 letters were taken." (same place and style as the picture problem lines).

## 12. A tick PARAGON was not told about
- When the "this bar is done" line cannot be written (no waiting list found, folder refuses), it is kept on the device (settings key `paragon.doneNotTold`, up to 200, 60 days) and tried again at the next start and at Settings > Check again. Duplicates are not kept.
- On the board: small grey line "Not told to PARAGON yet" (grey, no mark, at the top beside the other lines; identifier `board.notTold`) until it went through.
- Interpreted "the bar" as the board's own line row (the item has no room for text); the line shows on the board that holds the untold tick, not on one bar.
- PARAGON not changed. Changed shared files: AppModel.swift (copy, quiet put away, tellParagonTicked + queue), ParagonGate.swift (`appendDone` returns true/false), BoardView.swift (one line), BoardSession.swift (movedOut + undo/redo follow), Doors.swift (one line), Share/ShareViewController.swift (one line), SharePlate.swift, BoardPicture.swift, BoardPaper.swift.

## Could not see
Nothing run on screen; no screen tests added (no new screens). Strips drawing not compared against a printed page.
