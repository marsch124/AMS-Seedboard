# Built: lane extras (30, 33, 41, 43)

## 1. What's new
- 30 Names for colours: before, a colour chip in the bar always said "Yellow", "Green" ...; the legend's words were only on the legend card. Now a sticky note's colour chips say the legend's word ("Question") when the board names that colour, a small line with that word shows under the dots, and PARAGON's note puts it after each sticky note of that colour: "- Call Alex (Question)". Nothing new is saved.
- 33 Fold a map to its main branches: before, ideas folded one at a time (Unfold all only opened). Now the middle of a mind map has one button "Main branches only": every first-level idea that has ideas under it folds (the "+N" badges show). Pressed again it says "Open all" and every folded idea of that map opens. Mac: Board menu "Main Branches Only" / "Open All Branches" (works with any idea of the map chosen).
- 41 Tick sound: before, ticking was silent (a light tap on iPhone only). Now a soft two-note tick plays when a to-do box is ticked (not when un-ticked) and when a tick-list line in a sticky note is ticked. Settings has a new part "Sounds" with the switch "Tick sound": on at first on iPhone and iPad, off on the Mac.
- 43 Open Recent: before, the Mac had no list of opened boards (Dock menu listed the 5 changed last). Now File has "Open Recent" (last 5 boards opened, newest first) and the Dock menu ends with "Opened Recently" listing the same (boards already shown higher in the Dock menu are left out there).

## 2. How it works
- Colour names: say what a colour means in More, Colour legend...; the name then shows with the colour of a chosen sticky note (under the dots and as the dot's name) and after the note in PARAGON's note. A tick-list note is sent line by line as before, without the word.
- Main branches only: choose the middle of a map; press "Main branches only". Press "Open all" to see everything again. A map with no ideas under its first level has no such button.
- Tick sound: Settings, Sounds, Tick sound. It follows the silent switch and never stops music.
- Open Recent: File, Open Recent lists the last five boards you opened on this Mac; removed or put-away boards are left out.

## 3. Spec
- Core `Extras11.swift`: `Board.legendWord(forColour:)`, `legendWord(ofNote:)`; `ParagonExport.namedBullet(_:in:picture:)` (used by `notesBody` in SendFrames.swift: both loose notes and per-frame notes); `Board.showsMainBranchesOnly(_:)`, `canFoldToMainBranches(_:)`, `toggleMainBranchesOnly(_:)` (uses `Item.folded`); `RecentBoards.limit = 5`, `.opened(_:in:)`, `.shown(_:among:)`.
- `Remembered.recent: [UUID]` (device settings key seedboard.remembered, not the board file, not synced; tolerant decode; boards that are gone are dropped by `keeping`). `Remember` is now an ObservableObject with `@Published recent`.
- App `Extras11.swift`: `TickSound` (ambient, mixWithOthers, 2 notes 1318.5 + 1975.5 Hz, volume 0.5, UserDefaults key "tickSound", default true on iOS / false on macOS; silent when launched with -sampleData or -uiTesting); `SoundsSection` (id `settings.tickSound`, header "Sounds"); `OpenRecentMenu`; `RecentDesk`; `BoardSession.toggleMainBranches`; bar action id `mainBranches` (words "Main branches only" / "Open all", chevron mark, shown when the centre of a map with something to fold is chosen).
- Hooks: `toggleTodo` (BoardSession) and `sequenceToggleTodo` call `TickSound.play()` when ticking on; `pressMark` (MarksSession) when a tick-list line goes from unticked to ticked.
- Colour dots: `.help` + accessibility label carry the legend word; small caption id `colour.legendWord` under the dots when the colour in use has a word.
- Edited shared files: BarActions.swift (`act` no longer private; colour word; mainBranches button), ChosenBar.swift (ColourRow), Menus.swift (Open Recent line, Mac only), MacHabits.swift (Dock menu), MapCommands.swift (Board menu line), SettingsView.swift (SoundsSection), Remember.swift, BoardSession.swift, SequenceSession.swift, MarksSession.swift, Core Remember.swift, SendFrames.swift.
- Test: Core/Tests/SeedboardCoreTests/Extras11Tests.swift (3 tests).

## 4. Pictures
- 30: `-sampleData -board Marks` (has a legend), choose a sticky note.
- 33: `-sampleData -board <a mind map sample>`, choose the middle, press Main branches only.
- 41, 43: nothing to see (sound; menu on the Mac).

## 5. Not done / doubts
- Dock/File "recent" is not recorded under -sampleData (nothing is remembered there), so pictures show it empty.
- Legend word is not put on tick-list notes in PARAGON's note, nor on project notes' task lines (only the Notes section).
- The caption under the dots makes the colour plate a little taller when a word shows; the lead should check it on iPhone.
- "Main branches only" button is on the middle's bar only (other ideas: Mac Board menu works for any idea).
- No screen test, no pictures (as briefed).
