# Panel for 0.5 — data safety and reliability

Reviewer's lens: **nothing is ever lost, nothing ever hangs.**
Read on 18 Nov 2026, Seedboard 0.4 (4), commit `a6e6f58`. Read-only: nothing was built, run or tested. Every finding below was traced in the code; what I could not confirm is marked **unsure**.

## In one look

- **Boards are in good hands.** The store (BoardStore.swift, Safety.swift) is careful and the earlier findings S1–S7 still hold (list at the end).
- **Starters are the weak spot.** They have their own small store that follows none of the boards' safety rules. Findings 1, 2, 3 and 9.
- **Pictures are sound at the core** (a file is written once, the tidy pass is cautious), but weak at the edges: late arrival, the amber dot, Export, Import, memory. Findings 4, 5, 6, 8, 10, 11.
- **Stored fields:** every field is written and read tolerantly today, `picture` and `crop` included. The guard test is weaker than it reads. Finding 12.

Ranked by how bad the loss or failure would be.

---

## 1. A starter being changed dies with the app

**Where:** `App/Sources/AppModel.swift:236-241` (`leaving`: `if closing { leaveChange() }`; `closing` is only true from the Mac's quit notice, `AppModel.swift:77-79`) · `App/Sources/SeedboardApp.swift:67-69` (iPhone and iPad call `leaving()` without it) · `App/Sources/StarterModel.swift:150-161` (the working copy lives in memory only; a change just sets `dirty`).

**Steps:** iPad. Starters, Change… on "Weekly review". Add ten notes. Switch to Photos to look something up. iOS drops Seedboard from memory (routine when memory is short). Open Seedboard again. The same happens after a crash or a forced quit on the Mac, because the quit notice never comes.

**What the owner sees:** the home page. The starter is as it was before. No line, no copy anywhere. Everything he changed is gone.

**Smallest safe fix:** keep the working copy on the device while it is being changed. On each change of the working copy (same half-second wait as a board) and in `leaving()`, write `Starters/<id>.working` in Application Support (device only, never iCloud) with the starter's id, the name and the board. Delete it in `endChange()` (that covers Save, Discard and leaving). At the end of `loadStarters()`: if such a file is there and the starter still exists, open it again as the working copy with `dirty = true` and say "You were changing the starter "Weekly review". Your changes are back." Do **not** save into the shelf when the app goes to the background: that would break Cancel and send half-done work to the other devices.

**Rule test:** `testAStarterWorkingCopyComesBackAfterTheAppWasStopped` — a working copy written and read back gives the same starter id, name and board; ending the change leaves no file.

---

## 2. A rename elsewhere wipes a starter's new content

**Where:** `Core/Sources/SeedboardCore/StarterShelf.swift:70` (`newer`: the whole entry wins by one time stamp) · `StarterShelf.swift:148-168` (`rename` and `move` store this device's old board together with the new name or place) · `App/Sources/StarterStore.swift:85-100` (the winner is written over the loser on the device and in iCloud; nothing is kept aside).

**Steps:** iPad, offline or just slow: Change… on "Weekly review", Save at 10:00. Mac at 10:05, which has not read the iPad's version yet (the Mac only reads starters when it comes to the front or the Starters page opens): drag "Weekly review" one place up. The Mac writes its entry: old content, new place, stamped 10:05. Next read on either device: 10:05 wins. On the iPad, `StarterStore.swift:95-97` writes the Mac's entry over the iPad's own file.

**What the owner sees:** the starter has its old content on both devices. The iPad's work is gone. No clash line, nothing under "Removed and earlier versions".

**Smallest safe fix:** two small parts.
(a) The content gets a stamp of its own: a new field `boardChanged` in `StarterEntry`, set only by `change`, `saveAs` and `backToOriginal`. `newer` takes name, grey line, place and "removed" from the entry with the later `changed`, and the board from the entry with the later `boardChanged` (missing = `changed`, so 0.4 files read as today; 0.4 carries the unknown field, `StarterShelf.swift:52`).
(b) Before `StarterStore` replaces a stored file whose board differs, it keeps the replaced bytes in SafetyCopies as `starter-<id>-<time>.seedstarter` (30 days, the same tidy as set-aside boards).

**Rule test:** `testAMoveOrRenameNeverWinsOverANewerStarterBoard` (StarterShelfTests).

---

## 3. Starter files skip the boards' safety rules

**Where:** `App/Sources/StarterStore.swift:63-67` with `:98-100` · `:74-80` · `:68-82`.

**Steps (three ways, all traced):**
- **Not arrived yet, written over.** The Mac changed a starter yesterday. On the iPhone iCloud has not brought the file yet (it shows as `.<id>.seedstarter.icloud`). Seedboard opens: line 63-67 skips the stub, the iPhone's older copy counts as the best, and line 98-100 writes that older copy into iCloud under the real name. BoardStore refuses exactly this (`BoardStore.swift:553-558`). What iCloud then does with the two versions is **unsure** (a parked version or an "… 2" file); both lead to the next two points.
- **Parked version dropped unread.** Lines 78-79 mark a parked version as settled and remove it whether or not it could be read (line 75 only uses it when it could). A version that has not been downloaded is thrown away. Boards only clear what was read and is safe (`BoardStore.swift:573-613`).
- **iCloud's own copies.** A file `<id> 2.seedstarter` is read like any other, and line 82 (`inCloud[found.id] = found`) lets whichever file the folder lists last win, whatever its date. The copy is never joined and never cleared.

**What the owner sees:** a starter jumps back to an older state on one device. If he then changes that older state, it becomes the newest and replaces the real one everywhere.

**Smallest safe fix:** three lines of the boards' rules in `read`: (1) remember the ids whose iCloud file is a stub and never write those to iCloud in the levelling step; (2) remove a parked version only after it was read and joined; (3) line 82 becomes "the newer of the two", and an "… 2" copy goes only once its content is in the main file. Together with the keep-aside of finding 2.

**Rule test:** move the decision into Core as a plain rule and test `testAStarterThatHasNotArrivedIsNeverWrittenOverAndOfTwoCopiesTheNewerWins`.

---

## 4. Pictures laid late overwrite newer changes

**Where:** `App/Sources/PictureViews.swift:128-156` (`lay`: waits at `:140`, then changes the session that asked at `:145`) · `PictureViews.swift:88-92` (the picker loads the photos first, which can take long with iCloud Photos) · `App/Sources/ClipBoard.swift:239-249` (a drop) · `App/Sources/AppModel.swift:253-263` (`keep` takes a save from any session whose board is in the list).

**Steps:** iPhone. Board X open. Choose 12 photos in the picker. While they load, go back to the list, open X again and type "abc" (saved). The first photo is ready: the **old** session (still alive in the task) adds the picture to **its** board (the state before "abc"), stamps it later than "abc" and saves. On disk X now has the picture and no "abc". Both stamps are ones this device made, so the store writes over without a safety copy (`BoardStore.swift:845-858`). The same wipes a change that came from another device while the photos were loading.

**What the owner sees:** "abc" is on screen. After the next start it is gone. (If he changes something more before quitting, the pictures are gone instead.) No line, no earlier version.

**Smallest safe fix:** a session that is no longer shown must not save. In `AppModel.open(_:)` (line 292-306), `closeDraft()`, `remove` and `cloudRemoved`: set `session?.onChange = nil` before the session is replaced. In `lay`, after each wait: `guard AppModel.shared.session === self` else stop and say "The pictures were not laid: the board was closed."

**Rule test:** `testAClosedSessionNeverSavesOverTheOpenOne` — open X, keep the session, open X again, change the old session: the list and the store still hold the new session's board.

---

## 5. A picture can miss iCloud without a sign

**Where:** `App/Sources/PictureStore.swift:94-100` (the iCloud write's result is thrown away at `:97`, the watch starts at `:99` anyway) · `:256-260` (`isUploaded` says "sent" for a file that is not there) · `:44-57` (iCloud's Pictures folder is asked for once per start; BoardStore asks again every 30 s, `BoardStore.swift:445-453`) · `:233-253` (a missing copy is only put right at the next fresh start).

**Steps:** iPhone, iCloud storage full (or the write is refused for any reason). Lay a picture. The device copy is fine; the iCloud write fails. Three seconds later the watch looks: the file is not in iCloud's folder, reading its state fails, and line 258 counts that as "sent". The amber dot goes out. The board itself goes up. Second way: iCloud is switched on after Seedboard started; pictures laid in that run never go up and never get a dot.

**What the owner sees:** no amber dot on the iPhone, so all looks safe. On the Mac and iPad: "Picture not here yet", for days (an iPhone app is rarely started fresh). If the iPhone is lost or reset before then, the picture is gone for good.

**Smallest safe fix:** (a) `take` notes whether the iCloud write worked; a name that failed stays in the "not in iCloud yet" set and the 3-second watch tries the write again (the step that is already at `:245-248`); (b) `isUploaded` answers "no" when iCloud is on and the file is not in iCloud's folder; (c) while the iCloud folder is unknown, ask again at each `take`, at most every 30 s.

**Rule test:** `testAPictureThatIsNotInICloudsFolderIsNeverCountedAsSent` (a plain rule in `PictureKeeping`).

---

## 6. Export all silently leaves pictures and starters out

**Where:** `App/Sources/BringBack.swift:128-130` (a picture whose bytes cannot be read is skipped without a word) · `App/Sources/PictureStore.swift:177-190` (`fileBytes`: a file that is still only in iCloud counts as "not there") · `BringBack.swift:123-126` (only boards are counted; the starters are never looked at) · the loop at `:128` runs on the main thread (the work only leaves it at `:131`).

**Steps:** iPad. The photos were laid on the iPhone, and some have not been downloaded to the iPad (or it is offline). Settings, Export all boards. The file is made, the line says "Last export: today". Weeks later he imports that file: the boards come in, with "Picture not here yet" where pictures were not packed. His own starters are not in the file at all.

**What the owner sees:** nothing at the time of the export. He believes he has a full backup. Also: with a few hundred pictures the app stands still while the button says "Making the file…", and all pictures are held in memory twice (**unsure** at how many pictures iOS stops the app).

**Smallest safe fix:** collect the names that could not be read, ask iCloud for them, and say it under the button: "Exported 14 boards and 31 pictures. 3 pictures are not on this device yet and are not in the file." Read the pictures inside the background task at `:131`. Pack every own or changed starter (and the pictures it names) in a folder `Starters` inside the zip.

**Rule test:** `testTheExportSaysWhichPicturesAreMissingAndPacksTheStarters` (ExportRules: the list of names to pack includes the starters' pictures; the summary line counts the missing).

---

## 7. Undo after Send lets tasks go twice

**Where:** `App/Sources/BoardSession.swift:765-773` (`markSent` writes `sent` and `sentTodos` without an Undo step) · `:132-143` (`undo`) and `:145-155` (`redo`) put the whole earlier board back, with its older `sent` and `sentTodos`.

**Steps:** tick a box "to do". Type something in another box. Send to PARAGON, tasks to the Inbox. Press Undo once (it takes back the typing). The board is now the snapshot from before the send: the box is still ticked, but no longer marked as sent, and the board's own "sent" mark is gone. Send again.

**What the owner sees:** the same task twice in PARAGON's Inbox. The board leaves the "Sent" group in the list.

**Smallest safe fix:** in `undo()` and `redo()`, before `set(back)`: `back.sent = board.sent ?? back.sent`, and `back.sentTodos` = the earlier ones joined with the present ones, limited to things that are on `back`. (Joining keeps "taking the tick off forgets it was sent" working, `BoardSession.swift:556`.)

**Rule test:** `testAStepBackNeverForgetsWhatWasSent` (a small Core helper `Board.keepingSentMarks(of:)`).

---

## 8. Many photos flicker as "Picture not here yet"

**Where:** `App/Sources/PictureStore.swift:28-32` (the memory holds 160 MB) · `:101`, `:138`, `:165` (each picture counts as width × height × 4: a phone photo of 2048 × 1536 is 12.6 MB, so about 12 fit) · `App/Sources/CanvasDraw.swift:256-259` (every picture on the board is asked for at each redraw, in view or not) · `App/Sources/PictureViews.swift:216` and `:233-243` (not in memory = the plate "Picture not here yet") · `PictureStore.swift:148-173` (a picture that was pushed out is read again at most every 3 s, pushes another one out, and the board redraws) · `App/Sources/CropPage.swift:20` and the small pictures (`imageNow`) read and unpack on the main thread when a picture is not in memory.

**Steps:** lay 20 phone photos on one board (the picker gives 12 at a time, so twice).

**What the owner sees** (**unsure**: worked out from the code, not seen on a device; the system's memory limit is not exact): some pictures show "Picture not here yet" although their files are on the device. Which ones changes every few seconds. The board keeps redrawing; the crop page and the small pictures in the list stutter. It looks like lost pictures.

**Smallest safe fix:** keep a copy sized for the board in memory (long side 1024, about 3 MB, so 50 fit in the same room), made with the same call `take` already uses (`:84-89`); read the full file only for Crop and for export; count the real bytes; and show the words "not here yet" only when iCloud was really asked (`isComing`), a plain plate otherwise.

**Rule test:** `testTheMemoryHoldsABoardOfFortyPhotos` (a rule for the kept size and its cost).

---

## 9. Leaving the app can hang on starter files

**Where:** `App/Sources/StarterStore.swift:40` (`flush` waits with no time limit; the boards' wait is 2 s, `BoardStore.swift:955-963`) · `App/Sources/AppModel.swift:241` (called on the main thread at every leave, also when no starter was touched) · `StarterStore.swift:35-37` and `:51-113` (one single line of work does the device write **and** all the iCloud reading and writing) · `App/Sources/StartersPage.swift:26` (a full read starts each time the app comes to the front).

**Steps:** iPhone on a slow network. Seedboard comes to the front; the read of iCloud's starter files begins. He leaves the app at once. `leaving()` waits on the main thread until that whole read is over.

**What the owner sees:** the app stands still while it is being left; iOS may stop it (**unsure** how long iCloud keeps such a read waiting; that it can wait is why BoardStore has two lines of work and a limit). Boards are safe: they were handed to their own line just before (`AppModel.swift:240`). A starter saved a moment earlier is not on the device until its turn comes.

**Smallest safe fix:** give StarterStore the boards' shape: the device write on its own line (never behind iCloud), `flush` waits 2 s at most (as `BoardStore.swift:956-958`), and is skipped when nothing was written since the last one.

**Rule test:** `testLeavingNeverWaitsLongerThanTwoSecondsForStarters` (flush comes back in time while the iCloud line is busy).

---

## 10. Import re-squeezes pictures and overwrites iCloud's

**Where:** `App/Sources/PictureStore.swift:193-197` (`adopt` calls `take(data, as: name)`) · `:79-100` (`take` unpacks, scales, saves again as JPEG 0.8, and writes to the device **and** over the same name in iCloud) · `App/Sources/BringBack.swift:144-169` (all of it on the main thread).

**Steps:** iPad whose boards show pictures that were laid on the iPhone (so the iPad's own folder has no copy, only iCloud's). Import the files of an export, the `.jpg` files too. For each picture `adopt` finds no device copy (`:195`), so `take` saves it again and writes over iCloud's original.

**What the owner sees:** nothing at once. Each picture gets a little worse with every import, the rule "a picture file is written once and never changed" (`PictureStore.swift:9-10`) is broken, and with a hundred pictures the app stands still during the import. If iCloud's original had not arrived yet there are now two versions under one name (**unsure** what iCloud makes of that).

**Smallest safe fix:** in `adopt`: a name that is on the device **or** in iCloud's folder (as a file or as a stub) is done. Otherwise write the given bytes exactly as they are (after checking they open as a picture). Do the work off the main thread.

**Rule test:** `testAPictureThatComesBackKeepsItsBytesAndIsNeverWrittenTwice`.

---

## 11. Tidy pass can run before iCloud caught up

**Where:** `App/Sources/PictureStore.swift:292-307` (once per start, 25 s after the first board opens) · `:311-357` (the pass; it deletes in the device folder and in iCloud's, `:346-354`).

**What holds (traced):** nothing goes while any file is still an iCloud stub or cannot be read (`:318`, `:331`, `:333`); the search looks at the raw bytes of Boards, Removed, SafetyCopies and Starters; a file must be 30 days old. I could not build a sure loss on iPhone or iPad.

**Steps (unsure):** a Mac that was not opened for more than a month (after a long trip). iCloud lists the picture files before it has brought the newest boards. Newer macOS shows a file that is not downloaded under its real name, with no stub, so the checks at `:318` and `:331` do not fire. A picture older than 30 days that only a not-yet-arrived board names is then deleted in iCloud, for every device. The device that laid it still has its own copy and puts it back at its next fresh start (`:245-248`), so a real loss needs that device to be gone too.

**Also traced:** the pass reads every file in Boards, Removed, SafetyCopies and Starters (`:327-336`) before it knows whether any picture is old enough, and it does so on the boards' iCloud line (`BoardStore.swift:1157-1163`): board saves to iCloud wait meanwhile. A `.DS_Store` in the Pictures folder (Finder makes one) switches the pass off for good at `:318` — safe, but nothing is ever tidied on that Mac.

**What the owner sees:** in the unsure case, "Picture not here yet" on boards for a while, or for good. In the traced case, a slow first minute with many boards.

**Smallest safe fix:** (1) find the old, unnamed files first and stop when there are none (move `:339` before `:327`); (2) a file goes only when it was unnamed at two passes at least 7 days apart (a small device file remembers the first time); (3) only a `.icloud` stub counts as "still in iCloud", other dot-files are ignored; (4) no pass while a board waits for iCloud.

**Rule test:** `testAPictureGoesOnlyWhenItWasUnnamedTwiceAWeekApart` (`PictureKeeping.deletable` with a first-seen date).

**A rule for the 0.5 builders:** a device still on 0.3 or 0.4 only looks in Boards, Removed, SafetyCopies and Starters. If 0.5 names a picture anywhere else (a new folder, a new kind of file), the older apps will delete that picture after 30 days. Keep every picture name inside those four folders.

---

## 12. The stored-fields guard misses unwritten fields

**Where:** `Core/Tests/SeedboardCoreTests/SafetyTests.swift:262-288`.

**Checked today, all good:** `Item` — 24 of 24 fields are written (`Board.swift:251-278`, `picture` at `:276`, `crop` at `:277`) and read tolerantly (`:222-248`; a broken crop becomes "whole picture", `:248`). `Link` 11 of 11 (`:357-371`), `Board` 12 of 12 (`:459-474`), `StarterEntry` 9 of 9 (`StarterShelf.swift:55-67`), `Stroke` 4 of 4 (`Ink.swift:70-77`). Format 3 and 4 make an older app read-only, as meant (`Board.swift:478`, `:492`).

**Steps (the gap):** the test only checks that what was written is **among** the listed names (`:284-287`), and it writes an item that has nothing but a parent (`:273-275`). A builder of 0.5 adds a field with its name, its reading line and its entry in the list, and forgets the `encodeIfPresent` line: the test passes. `Stroke`, `Lanes` (`Lanes.swift:38-51`: no carrying of unknown fields; an unknown direction word is read as rows and saved back as rows) and `StarterEntry` are not in the list at all, so a new field there does not force a new format number.

**What the owner sees:** nothing today. In 0.5: a new setting that is gone after the first save.

**Smallest safe fix:** in the test, fill **every** field of an item, an arrow and a board and require the written names to **equal** the list; add lists for stroke, lanes and starter.

**Rule test:** `testEveryStoredFieldIsReallyWritten` (that test itself).

---

## Smaller things seen (not counted)

- **Copy, Share and Send draw the whole board on the main thread with no upper size.** `App/Sources/BoardPicture.swift:34` halves the sharpness above 3000 points but a board 30,000 points wide is still drawn whole; `ClipBoard.swift:138` does it on every Copy. **Unsure** whether the system gives up politely or the app runs out of memory.
- **The picture watch never slows down.** `PictureStore.swift:268` looks every 3 s for as long as a picture cannot go up; the boards' watch slows to 30 s (`BoardStore.swift:249-257`).
- **A board made from a starter that a newer app wrote** is refused by the store without a word (`BoardStore.swift:847-848`, `:895`) and is gone at the next start.
- **Crop on a very narrow picture:** the frame's left edge can go below zero (`CropPage.swift:172-176`); Save then does nothing (`Pictures.swift:67-68`). No loss.
- **A long Pencil sketch** is drawn again stroke by stroke at every redraw (`InkDraw.swift:46-52`) and every save reads and packs the whole board several times (`BoardStore.swift:518-521`, `:826-859`, `:902-950`). **Unsure** about speed: not measured.
- **A small picture in the list** that was drawn while a picture was missing keeps the empty plate until the board changes (`BoardThumb.swift:41-46`).

## The earlier findings S1–S7: still hold

- S1 news held while typing: `AppModel.swift:138-198`, `Safety.swift:142-145`.
- S2 the removal mark carries its time: `Safety.swift:60-92`, `BoardStore.swift:694-721`, `:1051-1064`.
- S3 parked versions and "… 2" copies are joined: `BoardStore.swift:573-613`, `:723-726`, `:782-809`.
- S4 unknown kinds make the board read-only, unknown fields are carried: `Board.swift:146-151`, `:225-226`, `:478-493`.
- S5 the device copy first, a time limit, background time, the dot and the warning: `BoardStore.swift:884-899`, `:955-968`, `AppModel.swift:236-250`.
- S6 looked at in `AppModel.swift:487-542` only (the folder is looked for at each Send, the ticks are stored first): holds. Finding 7 is a new way for tasks to double. ParagonGate.swift was not read again.
- S7 a link before the boards are loaded: `AppModel.swift:407-442`.
