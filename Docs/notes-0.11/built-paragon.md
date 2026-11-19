# Lane paragon — picks 5, 26, 27, 40

## 1. What's new
- 5: A failed Send said "This device cannot reach PARAGON's Inbox" for a full disk, a locked file and a closed iCloud alike. Now it names the real cause: disk full, folder locked/read-only, file in use by another app, PARAGON's folder missing, iCloud full, iCloud off or not reachable. Before: 1 line for all; now: 6 causes (+ a plain fallback with the system's reason).
- 26: After Send, to-dos in the Inbox had only the filled "in PARAGON" ring. Now a small purple line on the board says "N waiting for PARAGON", "N in PARAGON" once the read-back has seen them filed, and "N not filed yet — open PARAGON" after 24 hours.
- 27: With 2 or more things chosen, the Send page offers the switch "The 3 chosen things": only those (an idea brings what hangs under it) go, as a note or as to-dos. Before: only a branch (1 idea) or a frame.
- 40: More menu has "Copy the board as an email" under "Copy the board as text": first line `Here is my board “Title”:`, the outline, last line `Made with Seedboard`.

## 2. How it works
- A Send problem now tells why and what to do ("The Inbox could not be saved: the disk is full. Free some space, then send again. Nothing was changed.").
- Things sent to the Inbox: the line under the board shows how they stand. It turns to "in PARAGON" when Seedboard's read of the board's note finds them there; a day without that, it says "not filed yet — open PARAGON". A board sent only as to-dos has no note to read, so it stays "waiting" and then "not filed yet".
- Choose two or more things, press Send, switch on "The 3 chosen things": Project and Add what is new go away; Note and Only the to-do boxes remain. The board is not marked as sent.
- Copy the board as an email: paste into Mail.

## 3. Spec
- Core `Paragon11.swift`: `SendCause` (classify(Error), words(_:what:), words(for:what:), `inboxFolderMissing`); `InboxWait` (State waiting/filed/late, `lateAfter` 86 400 s, `state(of:in:seen:now:)`, `line(for:seen:now:)`); `Board.chosenOnly(_:)`, `Board.chosenWords(_:)`, `Board.emailText`.
- Mapping: POSIX 28/69 full; 1/13/30 locked; 16/26/11/35 in use; 2/20 missing; Cocoa 640 full, 513/642 locked, 4/260/2 missing, 4354 iCloud full, 4352/4353/4355 iCloud unavailable; the underlying error is looked at too (4 levels).
- Time base of "a day": `board.sent.when`, else `board.changed` (Send itself touches it). Seen = `ParagonEcho.read[board.id]`.
- `SendProblem.because(String)` new; `.noInbox` now says: "PARAGON's Inbox folder is missing on this device. Open PARAGON once, then check again in Settings. A note or a project can still be sent." Note/picture/Inbox write failures use `because`. `append` throws the POSIX error of `open`.
- App: `Paragon11Views.swift` `InboxWaitLine` (ids `board.inboxWait`, `board.inboxWait.words`), placed after `SentLine` (top, and `low: true` for timeline / Who does what) in BoardView. Send page: `SendSwitch` id `send.chosenOnly`, caption "Just these things are sent, as a note or as to-dos. The board is not marked as sent."; `AppModel.send(... chosen:)`. Menu id-less button "Copy the board as an email", flash "The board is copied as an email."
- Test: `Paragon11Tests` (3 tests).

## 4. Pictures
Chosen switch: `-sampleData` last, open a board, choose 2+ things, Send. Wait line: a board with a to-do sent to the Inbox (`-sendAs todos` flow); nothing launch-driven added.

## 5. Not done / doubts
- Inbox-only boards are never read back (no note), so they show "waiting" then "not filed yet" even when PARAGON filed them; true "in PARAGON" shows only when the task is found in the board's note.
- The line has no Open button (text only).
- Menu words are "Copy the board as an email" (not "Copy as email") to match its neighbour.
- Item 5: "iCloud off" when PARAGON's notes are not found is still the old "not found" line.
