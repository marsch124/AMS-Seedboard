# 0.11 lane "store" — items 16 and 18

## What's new
- 16 (nothing to see): before, the code that saves boards, joins iCloud's numbered copies and sets old versions aside had no test of its own. Now 5 small tests run it on a throwaway folder with a stand-in for iCloud (save and read back, newer wins and the older is kept, iCloud's " 2" copy joined and cleared, removal mark and a later change bringing the board back, a file that cannot be read left alone). Takes about 0.3 seconds.
- 18: before, the weekly clean-up of unused pictures could not be looked at. Now Settings, under Your boards, has a line "Pictures nobody uses: 3 (12 MB)" with Show (the pictures, small) and Remove now (asks once: "Remove 3 pictures nobody uses? This cannot be undone." Cancel / Remove).

## How it works
- Under Your boards, below "Removed and earlier versions" / Export / Import, a line says how many pictures no board uses and how much room they take. "Show" lists them as small pictures. "Remove now" takes them away after one question. A picture used by any board, removed board, earlier version, safety copy or starter is never counted and never removed. If Seedboard cannot be sure (a board still waits for iCloud, a file cannot be read, a picture is still only in iCloud), it says "cannot tell right now" and nothing can be removed. A picture added within the last hour is not counted yet. The weekly clean-up still works as before (30 days old, two looks a week apart); "Remove now" does not wait those days because you ask for it.

## Spec
- `Core/.../UnusedPictures11.swift`: `PictureKeeping.unusedNow(files:named:now:complete:)` (plain `.jpg` name, not named, date known, older than `freshHours` = 1 hour, `complete` false = nothing), `unusedLine`, `sizeWords` ("under 1 MB", "4.2 MB", "12 MB"), `removeQuestion`.
- `App/Sources/UnusedPictures11.swift`: `PictureStore.unusedPictures()`, `removeUnusedPictures()` (scans again at the moment of removal, never trusts the shown list; coordinated delete in the device and iCloud Pictures folders), `UnusedPicturesRows`, `UnusedPicturesPage` (title "Pictures nobody uses"). Identifiers: `settings.unusedLine`, `settings.unusedShow`, `settings.unusedRemove`, `settings.unusedTold`, `unused.page`. Result words: "1 picture removed." / "N pictures removed." / "Nothing was removed: Seedboard could not be sure."
- `PictureStore.swift`: the reading of every kept copy became `PictureStore.keptBlobs(folders:places:)`, shared with the weekly tidy (same behaviour); `cloud` and `cloudOn` are no longer private.
- `BoardStore.swift`: `BoardDisk` is no longer private and has `init(support:cloudDocuments:)` (both nil in the app) so a test can point it at a throwaway folder.
- `project.yml`: new target `AMSSeedboardStoreTests` (macOS unit tests, compiles BoardStore.swift only) in the AMSSeedboard scheme's tests. Run: `xcodebuild test -project AMSSeedboard.xcodeproj -scheme AMSSeedboard -only-testing:AMSSeedboardStoreTests -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGN_ENTITLEMENTS=""`. Files: `StoreTests/BoardStoreTests.swift`. Core test: `UnusedPictures11Tests` (1).
- Counts: store tests 5, Core tests 484 total.

## Pictures
- Settings (gear) › Your boards. With `-sampleData` the Pictures folder is a temporary one; the line likely says "none" there.

## Not done / doubts
- Not seen on screen (no simulator run). The line looks at the files when Settings opens; it is not live.
- "Show" is a plain page of small pictures without names or dates.
- The unit test target does not test PictureStore (needs app singletons).
