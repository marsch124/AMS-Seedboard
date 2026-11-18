# Built in 0.5 — the `safety` lane (data safety, DS 1 to 11)

Branch `wt-safety`. All eleven findings of `panel-data-safety.md` are built, each with its rule test in
`Core/Tests/SeedboardCoreTests/Safety05Tests.swift` (11 tests, named exactly as the note names them).
No new page, no new control, no new identifier, no new mark, no new launch word.
ONE stored field was added: `boardChanged` in a starter's entry (see DS 2).

Nothing of this was seen on a real device with iCloud: the rules are proven by the data tests, both platforms
build, and the Mac debug build was looked at with the example boards (see "Seen running" at the end).

---

## What the owner notices (for What's new / How it works / the specification)

### 1. A starter being changed survives the app being stopped (DS 1)
- Before: changing a starter ("Change…") lived in memory only. If iOS dropped Seedboard from memory, or the app
  crashed or was force-quit, everything changed was gone without a word.
- Now: while a starter is being changed, its working copy is written to THIS device half a second after each
  change (the same wait a board has) and again when the app is left. It is never put on the shelf and never sent to
  iCloud before Save, so Cancel still throws it away and the other devices never see half-done work.
- At the next start the working copy opens again, marked as changed (Save and Cancel work as always), with the line
  at the bottom, for 6 seconds: **You were changing the starter “Weekly review”. Your changes are back.**
- If that starter was removed meanwhile (on another device), the work is kept as a new own starter (grey line
  "Your own starter") and the line says: **The starter “Weekly review” was removed. What you were changing is kept
  as a new starter.** (This second case is my addition; the note only names the first. See "To decide".)
- Save, Cancel/Discard, and leaving the change by opening another board end the change: the working copy is deleted.
- A timeline starter that waited some days sits as far from today as it did when the work stopped.
- The working copy opens once the boards and the starters have been read at the start (a moment; on a very slow
  iCloud it can take longer, because the starters' first read includes iCloud's folder).
- Where: `Application Support/Starters/<starter id>.working` (device only). The file's field is `starter`, not `id`,
  so it can never be read as a starter.

### 2. A rename or a move elsewhere no longer wipes a starter's new content (DS 2)
- Before: of two copies of a starter the one with the later time won WHOLE. A rename or a move on a Mac that had not
  read the iPad's newer content yet put the old content back on every device.
- Now: the content has a time of its own. The name, the grey line, the place and "removed" come from the copy that
  was changed last; the BOARD comes from the copy whose content is the newer one.
- Before a stored starter file is replaced by a version with a different board, the replaced file is kept in
  SafetyCopies as `starter-<id>-<yyyyMMdd-HHmmss>-<6 letters>.seedstarter` for 30 days (tidied with the boards'
  set-aside versions). There is no page that shows these copies (the note asks for none).
- The owner's own Save over his own version is NOT kept aside (only a version this device had not seen).

### 3. Starter files follow the boards' iCloud rules (DS 3)
- A starter whose iCloud file has not arrived yet is never written over with this device's older copy.
- A version iCloud parked (two devices wrote at once) is cleared only after it was read and joined; one that
  cannot be read stays for the next look.
- Of iCloud's own copies ("<id> 2.seedstarter") the NEWER wins, whatever order the folder lists them in; a copy
  is cleared only once its content is in the starter's own file (or, if it lost with another board, in SafetyCopies).
- Saving a starter also reads iCloud's file first: what another device wrote meanwhile is joined in, not written over.

### 4. A board that was closed never saves over the open one (DS 4)
- Before: photos that were still loading (the picker, a drop) were laid by the CLOSED board and saved over newer
  changes, without a sign.
- Now: a board that is no longer on screen never saves. If its pictures arrive late, nothing is laid and the line
  says (brick red): **The pictures were not laid: the board was closed.**

### 5. The amber dot tells the truth about pictures (DS 5)
- Before: a picture whose write to iCloud failed (iCloud full) lost its amber dot after three seconds, and
  pictures laid before iCloud was switched on never went up in that run.
- Now: a picture that is not in iCloud's folder is never counted as sent. The board keeps the amber dot, and the
  watch writes the picture again: every 3 seconds for the first minute, then every 30 seconds (the watch used to
  look every 3 seconds for ever). While iCloud's folder is not known it is asked for again (30 seconds apart at
  most); once it is found, everything laid meanwhile goes up. iCloud switched off: nothing waits for ever.

### 6. Export all boards says what is missing, and packs the starters (DS 6)
- The line under "Export all boards", as soon as the file is made (it takes the place of "Last export: …" until
  Settings is opened again): **Exported 14 boards and 31 pictures. 3 pictures are not on this device yet and are
  not in the file.** One missing: "1 picture is not on this device yet and is not in the file." With starters:
  "Exported 14 boards, 2 starters and 31 pictures." No pictures: "Exported 3 boards."
- The missing pictures are asked for from iCloud at once, so they are here for the next export.
- The owner's own starters and every built-in whose board he changed (not the removed ones, not untouched
  built-ins) are in the zip, in a folder **Starters**, each as an ordinary `.seedboard` file that carries the
  starter's name; the pictures they show are packed too. "Import boards…" brings such a file in as a board;
  "Save as a starter…" makes it a starter again.
- The pictures are read in the background (the button no longer makes the app stand still for them).

### 7. Undo after Send never lets a task go twice (DS 7)
- Before: Undo after "Send to PARAGON" put the whole earlier board back, with its older "sent" marks; a second Send
  put the same tasks into PARAGON's Inbox again, and the board left the "Sent to PARAGON" group.
- Now: Undo and Redo keep what went to PARAGON: the board's own sent mark, the boxes that are in the Inbox, and the
  list of things that became tasks (`sent`, `sentTodos`, `sentTasks`). "Taking the tick off forgets it was sent"
  still works, and so does Redo of that step.

### 8. Many photos on one board stay visible (DS 8, the note marks it unsure)
- Confirmed in the code: the memory held about 13 phone photos (160 MB, 12.6 MB each); every picture is asked for
  at each redraw; a picture that was pushed out showed "Picture not here yet" and was read again, which pushed out
  another. NOT seen on a device.
- Now: the board keeps a copy with the long side at most 1024 pixels in memory (about 3 MB for a phone photo, so
  about 50 fit in the same 160 MB), counted by the bytes it really takes. The file keeps its 2048 pixels.
- Beyond the note, so a photo stays sharp when it is zoomed in: a picture that is IN VIEW and drawn clearly
  larger than its copy (more than 1.2 times) is read in full as well — a few at a time (64 MB, about five phone
  photos), never pushing out one that is on screen (no flicker), and let go again half a minute after it was last
  shown that large, or at once when iOS says memory is short.
- The words "Picture not here yet" show only when the file was looked for and is NOT on this device. While a
  picture is only being read, the plate shows the picture mark without words.
- "Crop the picture" reads the whole picture off the main thread; until it is there the page shows the board's copy.
- The picture for PARAGON, Share, Copy and the small pictures in the list use the 1024 copy (see "For the lead").

### 9. Leaving the app never hangs on starter files (DS 9)
- The starter store has two lines of work like the boards: the device's file is written at once and never waits
  behind iCloud; leaving the app waits for the device line only, 2 seconds at most, and not at all when no starter
  was written since the last time.

### 10. Import never re-squeezes a picture and never overwrites iCloud's (DS 10)
- A picture file from an export comes back byte for byte as it is (after a check that it opens as a picture).
- A name that is already on the device OR in iCloud's folder (as a file or as iCloud's place holder) is left as it
  is: "a picture file is written once and never changed" holds again.
- The import reads its files in the background. The words under "Import boards…" are unchanged.

### 11. The picture tidy pass is more careful (DS 11, the note marks it unsure)
- A picture file is deleted only when it was found unnamed at TWO passes at least 7 days apart (and is older than
  30 days, as before). The first time is remembered on this device (`UserDefaults`, key `picturesUnnamedSince`).
- The pass first looks whether any picture is old enough and unnamed; when none is, it reads nothing (before, it
  read every board, removed board and safety copy at each start).
- Only iCloud's place holder (`.<name>.icloud`) counts as "still in iCloud"; a `.DS_Store` no longer switches the
  pass off for good.
- No pass while a board still waits for its turn with iCloud; it looks again every 5 minutes, for half an hour.
- The unsure case (a Mac not opened for a month, iCloud lists pictures before boards) could not be tried; the
  7-day rule is the safety net for it.

### Smaller things
- Built: the picture watch slows down (in DS 5). A starter that a NEWER Seedboard wrote: making a board of it used
  to give a board that could not be saved and was gone at the next start; now a blank board is made and the line
  says (brick red, 6 s): **This starter was made by a newer Seedboard. Update the app to use it. A blank board was
  made instead.** Crop on a very narrow picture: the frame can no longer leave the picture.
- NOT built (more than a few lines, or another lane's file): Copy / Share / Send draw the whole board on the main
  thread with no upper size (`BoardPicture.swift`, the share lane's); a long Pencil sketch is redrawn stroke by
  stroke; a small picture in the list keeps the empty plate until the board changes (`BoardThumb.swift`); Export
  still holds all pictures in memory twice while the zip is made; the small list pictures still read on the main
  thread when a picture is not in memory (now the light 1024 copy).

---

## Stored field added
- `StarterEntry.boardChanged` (a time): CodingKeys case, tolerant reading (missing = `changed`), `encodeIfPresent`,
  added to the format-5 starter list in `SafetyTests.swift` and filled in `testEveryStoredFieldIsReallyWritten`.
  The format number is NOT raised. A 0.4 app carries the field unchanged; because a 0.4 app that changes the board
  carries an OLD stamp, the content's time is the later of `boardChanged` and the board's own `changed`
  (`StarterEntry.boardStamp`).
- Device only, not stored fields: `Starters/<id>.working` (Application Support), `picturesUnnamedSince` (UserDefaults).
- Picture names stay inside Boards, Removed, SafetyCopies and Starters: the working copy lies in Starters and the
  kept starter versions in SafetyCopies, so devices on 0.3 / 0.4 never delete a picture they name.

## New rules in Core (all plain, all tested)
- `StarterSafety.swift`: `StarterWorking`, `StarterFileName`, `StarterLevelling.plan`, `StarterKept`, `StoreLines`.
- `PictureSafety.swift`: `PictureKeeping.upload / watchLooks / memorySize / memoryCost / wantsSharp / stillInCloud /
  tidy(files:named:seen:…)`, `PictureFiles.adopt`.
- `SentSafety.swift`: `SafetyRules.maySave(asking:shown:)`, `Board.keepingSentMarks(of:)`.
- `ExportAll.swift`: `ExportRules.starterBoards / starterFiles / pictureNames / summary`; `BoardArchive.make`
  makes the folder a file name names. `KeptFiles.tidy` lets kept starter versions go after 30 days.
- `StarterShelf.swift`: `boardChanged`, `boardStamp`, the new `StarterEntry.newer`.

## For the lead and the other lanes
- `PictureStore.imageNow(_:)` and `image(_:)` now give the 1024 copy. The whole picture is
  `PictureStore.shared.fullImage(name)` (reads and unpacks now, not kept: call it off the main thread) — the share
  lane's PDF and anything that needs every pixel should use it (or `fileBytes`). A picture laid larger than about
  512 points is therefore a little softer in the picture for PARAGON than in 0.4.
- `PictureStore.image(_:shown:)`, `imageInMemory(_:)`, `isMissing(_:)`, `askFor(_:)` are new.
- `AppModel.importBoards` is now `async`. `ExportFile` has `summary`.
- `AppModel.open`, `present(draft:)`, `closeDraft`, `remove`, `cloudRemoved` set the old session's `onChange` to nil;
  the open board's `onChange` asks `SafetyRules.maySave`. A lane that makes its own `BoardSession` and wants it
  saved must go through `open`.
- Lines I added are said with `tone: .problem` where they are problems; I did not touch other `say(` calls.
- `ClipBoard.swift` is NOT touched: the drop of pictures goes through `lay`, which has the guard. A drop of WORDS
  onto a board that is closed before the words are read is dropped silently (no save, no line) — left as it is.

## To decide (the lead or Martin)
1. DS 1: when the starter was removed meanwhile, the work left behind is kept as a NEW own starter (the note is
   silent; the other choice is to throw the work away).
2. DS 6: the starters are packed as ordinary boards (`Starters/<name>.seedboard`), so the existing Import can read
   them; they come in as boards, not straight onto the shelf.
3. DS 8: the extra "read in full when zoomed in" (64 MB) goes beyond the note. Without it, a photo zoomed in would
   be softer than in 0.4. The picture for PARAGON / Share uses the 1024 copy unless the share lane reads the file.

## Seen running
- The Mac debug build with the example boards, once (`-board balcony -sampleData`): the two pictures of
  "Balcony makeover" draw from the new 1024 memory copies, the caption and the arrow as before. Quit at once.
- 305 rule tests pass (294 before, 11 new). Mac and iOS Simulator builds are green.

## Not seen running
- Nothing with real iCloud (two devices, a full iCloud, files that have not arrived, parked versions, "… 2" copies).
- The working copy coming back after a stop (it needs real files; the example boards never touch a file).
- 20 phone photos on one board on an iPhone or iPad; the zoomed-in full picture.
- Export with missing pictures; Import of an export's pictures.
- iPhone and iPad altogether (the simulators are not mine to use): the iOS build compiles.

## Drive-by problems seen and left
- `StarterStore`, `PictureStore` and `BoardStore` each spell the iCloud container's name themselves.
- `BoardThumb` draws a board's small picture on the main thread and reads its pictures there.
- `AppModel.send` saves the "already sent" ticks with `store.save` while the open session does not know them until
  `markSent`; an Undo in that moment is covered by DS 7 only after `markSent` has run.
