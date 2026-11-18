# Panel before 0.5 — Apple platform expert

Lens: being a great citizen of each device (iPhone one hand; iPad with Pencil, keyboard, trackpad, windows; Mac menus, windows, drag and drop, printing), plus widget, Shortcuts, Spotlight, share, Handoff.
Read 18 Nov 2026, 15:10, from the code at 0.4 (build 4) and `Docs/SPEC.md`. Nothing was built or run; every "Today" is read from the code.

## What is already there (so it is not proposed again)

- Three Shortcuts actions with Siri phrases: New board from text, New board, Open board (`App/Sources/Intents.swift:83-192`). All three open the app.
- Device search with one entry per board (`App/Sources/Spotlight.swift:93-106`).
- Links `seedboard://board/<id>` (`Core/Sources/SeedboardCore/Safety.swift:188-192`), opens where you left (`Remember.swift`).
- Mac menus File / Edit / View / Insert / Board, the same with an iPad keyboard (`Menus.swift:64-141`); Space + drag; right-click menu; Option-drag copy.
- Drop IN of words and pictures on a board (`ClipBoard.swift:331`); copy / paste as own form + words + PNG.
- Pencil: own strokes, double-tap and squeeze follow Settings, Only Draw with Apple Pencil (`InkViews.swift:215-268`, `InkDesk.swift:132`); iPad trackpad scroll, pinch, hover.
- Share a picture (PNG) from More and from File (`BoardView.swift:260`, `Menus.swift:283-309`).

Not there at all (searched the whole of `App/Sources` and `App/Config`): a second window, printing, PDF, Handoff, a widget, a share extension, Services, a Dock menu, a Help menu line, a file type for `.seedboard`, anything draggable OUT, the camera, app-icon quick actions.

Ranked by how much each would lift the app.

---

## 1. Send to Seedboard from any app — IDEA

**Today:** nothing can be sent TO a board from Safari, Photos, Mail or Notes. The spec says so: "No Share-sheet action of its own" (`Docs/SPEC.md:931`). The only ways in are paste, drop on an open board (`ClipBoard.swift:223-250`), and a Shortcut he would have to build himself.

**Better:** a share extension "Seedboard" on iPhone, iPad and Mac. Share text, a link or pictures → a small page: what came (one line), then "New board" (full colour, first) and his pinned + recent boards with their colour dots → Cancel / Send. It lands the next time Seedboard is in front, with the line "2 things came in from Share."
- Target `AMSSeedboardShare`, `type: app-extension`, `supportedDestinations: [iOS, macOS]` — copy the skeleton of PARAGON's `ParagonShare` (`~/Developer/AMS-PARA/project.yml:156-199`), which already is one target for both. Bundle id `com.schabbauer.AMSSeedboard.Share` by `POST /v1/bundleIds`. SwiftUI page in a `UIHostingController` / `NSHostingController`; `NSExtensionActivationRule` as a dictionary: text, 1 web URL, up to 10 images.
- A waiting list, the same pattern Seedboard already writes for PARAGON: the extension appends one JSON line per shared thing (own id, board id or "new", kind, words, picture file name) and puts shrunken pictures beside it. The app writes a small `boards.json` (id, name, colour, pinned; newest 30) to the same place whenever the list changes — hook: the debounce in `Spotlight.swift:25-31`.
- The app empties the list at the end of `AppModel.load`, on `scenePhase == .active`, AND on the Mac on `NSApplication.didBecomeActiveNotification`. Text → `Board.addWords` (a list becomes a mind map), a link → a note "page title + address", a picture → `PictureStore.adopt` + a picture thing. A line is deleted only after the board was saved.
- New Core rule `Board.arrivalSpot(size:)`: a free column to the right of everything on the board, stacked downward, so an arrival never covers anything (one data test). Findings 3 and 7 use the same rule.

**Traps:**
- Where the list lives. First choice: the app group the app already has (`group.com.schabbauer.amspara`, own subfolder `Seedboard/arrivals/`). Attaching that group to the NEW bundle id cannot be done by the API; it was done for the app itself in the developer portal in the built-in browser on 18 Nov — the same two clicks, if that sign-in is still alive. Fallback with no portal: keychain group `D24ENP83QQ.com.schabbauer.AMSSeedboard` — fine for text and links, NOT for pictures; then ship text + links first and say so.
- The Mac spells the group `D24ENP83QQ.group.com.schabbauer.amspara` (own entitlements file, as the app has).
- PARAGON's Inbox bug of today is the lesson: on the Mac `scenePhase` does not fire when he just switches apps; without the `didBecomeActive` hook arrivals would sit unseen.
- A share extension may not open the app; the page must say "It is on the board the next time you open Seedboard."
- Extension memory is small (about 120 MB): shrink pictures with `CGImageSourceCreateThumbnailAtIndex` (long side 2048), never decode the full image.
- Extension version and build must equal the app's or the upload is refused; `SKIP_INSTALL: YES`; `Tools/release.sh` must sign the second bundle id.

**Size:** L. **New target:** yes (one, for all three devices).

---

## 2. Two boards side by side, each in its window — IDEA

**Today:** one window, on purpose: "One window: no New Window" (`SeedboardApp.swift:27-36`); the model holds ONE open board (`AppModel.swift:14`, `session`). The iPad cannot open a second window either: `App/Config/Info.plist` has no `UIApplicationSceneManifest`. Copy and paste "between boards" (built in 0.2) means closing one board to see the other.

**Better:** "Open in a new window" for a board — in the row's menu (`RootView.swift:275`), the home card, File ▸ Open in New Window, and on the iPad by dragging a row to the screen's edge.
- `WindowGroup("Board", id: "board", for: UUID.self) { $id in BoardWindow(id: id) }` plus `@Environment(\.openWindow)`. A value window is unique by itself: asking for a board that already has a window brings that window forward — so a board can never be open twice, which is the data-safety rule we need.
- iPad: `UIApplicationSceneManifest` → `UIApplicationSupportsMultipleScenes: true` in `project.yml`; the row's drag carries an `NSUserActivity` with `targetContentIdentifier = <board id>` (`.onDrag` with `NSItemProvider.registerObject(activity, visibility: .all)`), the window group gets `.handlesExternalEvents(matching:)`. Works with Stage Manager and the iPadOS 26 windows.
- Model: `sessions: [UUID: BoardSession]` instead of one `session`; the main window's detail column shows "This board is open in its own window" + "Bring it here" when asked for the same board.
- Mac: the board window has no list (toolbar + board only), remembers its size and place (`.defaultSize`, the system restores), and joins the Window menu by name.

**Traps (all read from the code):**
- Singletons that assume one board: `PictureDesk.shared.ask` (`PictureViews.swift:20`) is heard by EVERY open board — the ask must carry the board's id; `model.showSend` (`AppModel.swift:23`, sheet in `BoardView.swift:180`) would open the Send page on every window; `MenuDesk.rename` / `.remove` (`Menus.swift:27-28`) are heard by all; `model.flash` shows in all; `BarDesk.shared` holds one pointer and one drag.
- The 0.5-second save and `leaving()` (`AppModel.swift:236-287`) handle one session; they must loop over all.
- Menus are fine already: `@FocusedObject session` follows the key window (`Menus.swift:47`).
- `Remember` keeps one `open` id; keep it for the main window only, let the system restore the others.
- UI tests: `-ApplePersistenceIgnoreState YES` is already used; add it for iPad scenes too.

**Size:** L. **New target:** no.

---

## 3. Add a thought without opening the app — IDEA

**Today:** every Shortcuts action opens Seedboard (`openAppWhenRun = true`, `Intents.swift:86, 113, 135`) and none can add to a board that exists. "New board" offers only the seven built-in starters (`Intents.swift:66-81`; the spec admits it, `SPEC.md:930`). Nothing gives a board back as words or as a picture.

**Better:** four new actions, all through the one model as today:
- **Add to board** — Text, optional Picture (`IntentFile`, images), Board (optional; empty = the board changed last). `openAppWhenRun = false`: the app is woken in the background, adds a sticky note (a list → a mind map, a picture → a picture) at `Board.arrivalSpot`, saves, and answers "Added to Summer cabin." Phrase "Add to \(\.$board) in Seedboard". From Raycast on the Mac this is: type a thought, pick a board, Return — the board never comes to the front.
- **Board as text** (`ReturnsValue<String>`, the outline) and **Board as picture** (`ReturnsValue<IntentFile>`, the PNG of `BoardPicture.png`) — so a shortcut can mail or message a board.
- **Find boards** — `EntityPropertyQuery` on `BoardEntity` (name, changed, pinned, sent) so Shortcuts can list "boards changed this week".
- **New board** takes his own starters: replace the fixed `StarterChoice` enum by a `StarterEntity` with a query over `model.shelf.shown`.
- iOS 18 / macOS 15 and later: `BoardEntity: IndexedEntity`, so Siri and the search know boards as things, not only as phrases.

**Traps:**
- In the background the iCloud folder can be slow; `whenLoaded()` already waits (`Intents.swift:16-19`), the action has about 30 seconds. Before returning, wait for the device copy (`flush`) exactly as `leaving()` does, or the process is frozen mid-write.
- If the board is the open one, the change must go through its `BoardSession.change` (so Undo and the screen follow), else through `AppModel.edit` (`AppModel.swift:391`).
- An add on a device that has not yet received a newer version from iCloud ends as a clash (the loser goes to Earlier versions, the clash line says so). Acceptable, but say it in "How it works".
- At most 10 App Shortcuts per app (7 after this); a parameter phrase needs every board name refreshed — already done (`Spotlight.swift:52-55`).
- Timeline and "Who does what" boards place things themselves: Add to board must refuse them with a plain line.

**Size:** M. **New target:** no.

---

## 4. Print a board, save it as PDF — IDEA

**Today:** no printing anywhere (no `NSPrintOperation`, no `UIPrintInteractionController`, no ⌘P). The only way out on paper is a PNG (`BoardPicture.swift:13-42`), white ground, at most twice the size — a big timeline printed from Preview is soft and cut.

**Better:** File ▸ Print… ⌘P and File ▸ Export as PDF… (Mac menu and iPad keyboard), "Print…" and "Save as PDF…" in More.
- One painter, one more output: `ImageRenderer(content:).render { size, draw in … }` into a `CGContext` PDF (`CGContext(consumer:mediaBox:)`, `beginPDFPage`, `draw(ctx)`, `endPDFPage`). Reuse the exact view of `BoardPicture.png`.
- A small plate before printing (Cancel / Print): **One page** (fit, landscape by itself when the board is wider than tall; a timeline always landscape) or **Across pages** (2, 4, 6 or 9 sheets with 10 mm overlap for a wall plan); title and date in the foot, small.
- Mac: `PDFDocument(data:).printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true)`, run as a sheet on the board's window. iPhone / iPad: `UIPrintInteractionController.shared`, `printingItem = pdf`, `printInfo.orientation`; on the iPad presented from the More button.
- `CommandGroup(replacing: .printItem)`; `Transferable` for the PDF (`.pdf`) so Share and drag (finding 7) can offer it too.

**Traps:**
- The Mac app is sandboxed: printing needs `com.apple.security.print: true` in `AMSSeedboard-macOS.entitlements` — without it the print panel fails. Not there today.
- A SwiftUI `Canvas` inside `ImageRenderer` may arrive in the PDF as a bitmap, not as lines. Check by zooming the PDF to 800 %. If it is a bitmap, render at print sharpness (`scale` about 4 for 300 dpi, tiles for big boards) — still far better than today's PNG.
- The plain key P is the Picture tool; ⌘P is free.
- Pictures on the board: use the stored JPEG bytes, not the 160 MB cache copies, or a board with many photos runs out of memory while printing.
- Night look never prints: force the day paint as `BoardPicture` does.

**Size:** M. **New target:** no.

---

## 5. Widget: plant a seed from the home screen — IDEA

**Today:** no widget, no Control Centre button, no Lock Screen entry. Starting a thought on the iPhone is: find the icon, wait, press New board at the top of the list.

**Better:** one widget extension for iPhone, iPad and Mac (PARAGON's `ParagonWidgets` is the pattern, `~/Developer/AMS-PARA/project.yml:210-250`).
- **Small "Plant a seed":** the sprout, one press → a new blank board, ready to type (`widgetURL`).
- **Medium "Boards":** a full-colour New board tile + three pinned / recent boards (colour dot, name, "changed …" as `Text(date, style: .relative)` so it stays right without reloads); each is a `Link` to `seedboard://board/<id>`.
- **Large:** six boards; with their small pictures only if the shared folder of finding 1 is available.
- **Lock Screen:** `accessoryCircular` sprout → new board; `accessoryRectangular` → the board changed last.
- **Control (iOS 18 and later):** `ControlWidgetButton` "New board" for Control Centre, the Lock Screen and the Action button, running the existing `NewBoardIntent`.
- App side: new links `seedboard://new/<starter id>` (today `BoardLink.id` knows only `board`, `Safety.swift:188-192`); `WidgetCenter.shared.reloadAllTimelines()` on the same debounce as the search.
- Look: flat, his hand-drawn marks from AMSIcons as shapes, one calm ground per widget, no glow; `containerBackground` and `widgetAccentable` so the tinted and clear home-screen looks of iOS 26 stay readable.

**Traps:**
- Data: names, ids, colours and dates are a few KB → the keychain group `D24ENP83QQ.com.schabbauer.AMSSeedboard` with `kSecAttrAccessibleAfterFirstUnlock` (the route proven in Reading Companion; no portal, no App Group). Small pictures do not fit that route.
- Bundle id `com.schabbauer.AMSSeedboard.Widgets` by the API; version and build equal to the app's.
- `NewBoardIntent` must be compiled into the app AND the widget target for the Control to see it.
- The Mac widget needs its own sandbox entitlement file.
- With `-sampleData` nothing may be written to the keychain (as with the search today).

**Size:** M. **New target:** yes (one; shares nothing with finding 1's target but the bundle-id step).

---

## 6. System search misses most words; no Handoff — BUG + IDEA

**Today:**
- The device's search knows a board's name and only its first 300 letters (`Core/Sources/SeedboardCore/Outside.swift:36-50`, used at `Spotlight.swift:97-98`). A word further down a big board is never found, although the app's own search finds it (`Home.swift:19-22`). The result has no picture (`Spotlight.swift:94-105` sets no thumbnail).
- No Handoff: no `NSUserActivity` anywhere, no `NSUserActivityTypes` in `Info.plist`. A board open on the iPhone does not offer itself on the Mac.

**Better:**
- Search: `about.textContent = every word of the board` (cap about 20 000 letters; it is searched, not shown), keep the 300 letters as `contentDescription`; `about.thumbnailData` = the small picture `Thumbs` already draws (`BoardThumb.swift:8`), as JPEG about 300 x 188. Rename the key `seedboard.searchTold` (`Spotlight.swift:17`) once, so every board is told again. On iOS 18 / macOS 15: `CSSearchableItem.associateAppEntity(BoardEntity(board))` so the result also carries "Open board".
- Handoff: in `BoardView`, `.userActivity("com.schabbauer.AMSSeedboard.board") { a in a.title = board.title; a.isEligibleForHandoff = true; a.targetContentIdentifier = id; a.userInfo = ["id": …, "changed": …, "scale": …, "x": …, "y": …] }`; `NSUserActivityTypes` in `project.yml`; `.onContinueUserActivity` in `OutsideDoors` (`Menus.swift:236`) → the same path as a link, then the same zoom and place. The Mac shows Seedboard's icon at the Dock's end, the iPad in its Dock, the iPhone in the app switcher.

**Traps:**
- Handoff can be faster than iCloud. The activity carries the board's `changed`; if this device's copy is older, show the board read-only with "Waiting for the newest version from iCloud…" until it arrives (at most 20 s, then open what is here). Otherwise two devices edit two versions and he gets a clash line.
- `userInfo` takes only plain values (the id as a string). Mark `relatedUniqueIdentifier = board id` on the activity so search does not show the board twice.
- Thumbnails are drawn on the main thread (`ImageRenderer`): only for boards whose `changed` moved, after the debounce, never while typing.
- A board not on this device yet is already handled ("opens when it arrives", `AppModel.swift:416-435`).

**Size:** S (search) + S (Handoff). **New target:** no.

---

## 7. A board is a real file: drag out, open, AirDrop — IDEA

**Today:** the app declares no file type (`Info.plist` has no `UTExportedTypeDeclarations`, no `CFBundleDocumentTypes`). His iCloud Drive shows a "Seedboard" folder (`project.yml:79-82`, public scope) full of files named `<UUID>.seedboard` (`BoardStore.swift:469`) with a blank icon; a double-click does nothing useful. A board from the export opens only through Settings ▸ Import boards… (`BringBackBars.swift:186`, any file may be chosen). Nothing in the app can be dragged OUT: no `.draggable` / `.onDrag` in `App/Sources`; a home card is a plain button (`HomeView.swift:213`).

**Better:**
- Declare `com.schabbauer.seedboard.board` (extension `seedboard`, conforms to `public.data` and `public.content`, own document icon: the sprout on white) and the document type with `LSHandlerRank: Owner`. `onOpenURL` (`SeedboardApp.swift:63`) learns file addresses: a file named after a board that is in the list → open that board; any other → import as a new board (the existing `ExportRules.imported`) and open it. So: tap in Files, double-click in the Finder, AirDrop, a Mail attachment all work.
- Drag OUT of a board card and a list row: `.draggable(BoardGift(board))`, a `Transferable` with three forms — the `.seedboard` file (`FileRepresentation`), the PNG (the existing `BoardPNG`, `BoardPicture.swift:46-55`), the outline as text. Dropped on the Finder it is the file, in Mail or Notes the picture, in a text field the words.
- Drop ON a list row: words or a picture dropped on a board's row land on THAT board (`dropDestination` + `Board.arrivalSpot`); a `.seedboard` file dropped on the list is imported. That moves things between boards without a second window.
- "Share the board…" beside "Share a picture…" in More and in File.
- A travelling board carries its pictures inside (a `pictures` table, base64) — only in the shared / dragged file; the stored files stay as they are. Import adopts them (`PictureStore.adopt`).

**Traps:**
- Without the pictures-inside form a shared board arrives with "Picture not here yet" plates.
- Never conform the type to `public.json` / `public.text`: text editors would offer themselves and Quick Look would show raw text.
- Files from outside are security-scoped: `startAccessingSecurityScopedResource()` around the read; on iPhone and iPad they arrive as a copy in the app's Inbox folder — delete it after import.
- A file inside the app's OWN iCloud folder must be opened by id, never imported (that would make a copy of the board he just tapped).
- A drag from a list row must not swallow the row's press or its press-and-hold menu: on iPhone test that the 0.5 s menu still wins when the finger rests.
- Small pictures of boards IN Files and the Finder would need a Quick Look thumbnail extension — a second new target; leave it out, the document icon is enough.

**Size:** M. **New target:** no.

---

## 8. Pencil: a rough box becomes a real box — IDEA

**Today:** the Pencil draws sketches (own strokes) and moves things. A drawn rectangle stays a drawing; to write into a shape with the Pencil he must first press it twice to open the field (`Guide.swift:289`). The step from "scribbled idea" to "tidy flow" is done again by hand with the tools.

**Better:**
- **Tidy shapes.** When a stroke ends and the tip rests 0.4 s (the Freeform habit), test it: a closed loop that fits a rectangle, an oval or a diamond (mean distance to the fitted outline under 8 % of its diagonal) becomes a real Box / Oval / Diamond of that size and place; an open stroke that starts on one thing and ends on another becomes an arrow between them. One Undo gives the raw stroke back. A switch "Tidy shapes" in the Draw plate, on at first. Apple gives no public recogniser for this — it is an own rule in Core (`InkShape.swift`) with data tests, which suits "every rule gets a data test".
- **Write straight onto a shape.** `UIIndirectScribbleInteraction` on the touch surface (`TouchLayer.swift`): its delegate offers every thing with words as an element (`requestElementsIn`, `frameForElement`), and `focusElementIfNeeded` calls `session.beginEdit(id)` and hands back the field. Writing over a box then starts typing in it, no double press.

**Traps:**
- Needs a real iPad with a Pencil to tune (thresholds, the 0.4 s rest). The simulator proves the rule, not the feel. If he has no Pencil with him until January, build the rule now with data tests and keep the switch OFF until he has tried it.
- `focusElementIfNeeded` must return the real `UITextInput` responder; the typing field is a SwiftUI `TextField` (`CanvasView.swift`, `LineField`). Either find the first responder after focusing, or make that one field a UIKit text view.
- Scribble on a thing competes with "Pencil drag on a thing moves it" and with the 0.5 s hold menu (`TouchLayer.swift`, `HoldWatch`); use `shouldDelayFocusForElement` and let a drag longer than 10 points win.
- Tidy shapes must not fire inside a sketch he is still drawing (strokes join one sketch within 5 s and 40 points): only a stroke that begins a new sketch is tested.
- Timeline and "Who does what" boards have no drawing: nothing to do there.

**Size:** M (tidy shapes) + M (write onto a shape). **New target:** no.

---

## 9. The Mac's own habits: Help, Dock, iPhone camera, Services — BUG + IDEA

**Today:**
- BUG: there is no `CommandGroup(replacing: .help)` (only `.newItem`, `.pasteboard`, `.toolbar`, `.undoRedo` are filled: `Menus.swift:66, 100, 114`, `BoardView.swift:457`). So the Mac's Help menu shows the system's own "AMS Seedboard Help", which answers that help is not available — while a full guide sits in Settings (`SettingsView.swift:20-22`).
- The Dock icon's menu is empty; a picture can come only from a file or the clipboard (`PictureViews.swift`, open panel); selected text in another app cannot be sent over; the board's name in the title bar is dead text (`BoardView.swift:171`); Space on a chosen picture does nothing (`Menus.swift:426-429` asks for typing, `BoardSession.swift:219` refuses it for a picture).

**Better (each small, all in one go):**
- **Help menu:** "How Seedboard Works" and "What's New" open the two pages in their own small window (`Window("How it works", id: "guide")`), so the guide can stay open beside the board. The Help menu's search field then finds menu lines by itself.
- **Dock menu:** `NSApplicationDelegateAdaptor` + `applicationDockMenu`: New Board, then the pinned and five recent boards.
- **Picture from the iPhone (Continuity Camera):** `ImportFromDevicesCommands()` in the scene and `.importsItemProviders([.image])` on the board → File ▸ Import from iPhone or iPad ▸ Take Photo / Scan Documents / Add Sketch; the photo lands on the board where the pointer was. Also as a line in the right-click menu of empty board.
- **Services:** `NSServices` in `Info.plist` — "New Seedboard Board from Selection" (send type `public.utf8-plain-text`): mark text in Safari or Mail, right-click ▸ Services → a new board (a list becomes a mind map) through `Outside.board(title:text:)`. No extension needed; this is the Mac half of finding 1 for text.
- **Title:** `.navigationTitle($name)` with `.toolbarTitleMenu { Rename, Pin, Make a copy, Save as a starter }` — on the Mac a click on the name renames it, on the iPad the name becomes the system's own title menu. The More menu stays as it is.
- **Space on a chosen picture = Quick Look** (`.quickLookPreview($url)` with the stored file): the photo at full size, pinch and arrow keys through the board's pictures. Caption stays on two presses and in the bar.

**Traps:**
- A new Service shows only after the app was started once and the system re-read its services (sometimes after a log-out); tell him to look under Services after the first start, and that it can be switched on in System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Services.
- The right-click menu is an own `NSMenu` (`BoardMenu.swift`, `MacMenu`): the camera line there needs `NSMenuItem.importFromDeviceMenuItem` and the catcher view answering `validRequestor(forSendType:returnType:)` / `readSelection(from:)`.
- `navigationTitle` with a binding renames on every key; keep the rule "empty is refused" (`AppModel.rename`) and write only when the field is left.
- Space is already three things on the board (hand, start typing, a focused button): Quick Look only when exactly one picture is chosen and no drag happened — one more case beside `MenuRules.spaceStartsTyping` with a data test. The key is free there today, so nothing he uses changes.
- A `Window` scene for the guide adds a line to the Window menu; give it `.keyboardShortcut("?", modifiers: .command)`.

**Size:** S each, M together. **New target:** no.

---

## 10. iPhone: everything under the thumb — IDEA (needs his pick, one picture)

**Today:** on the iPhone the two things done most — New board and Search — sit at the very TOP of the list (`RootView.swift:78-110`), the far corner for one hand. Pressing the app icon long shows nothing of its own. A photo can only be picked from the library (`PictureViews.swift:83`); the camera is not offered.

**Better:**
- **Thumb row** (iPhone layout only, `phone == true`): search and a round full-colour "+" at the bottom of the list. On iOS 26: `.searchable` with `DefaultToolbarItem(kind: .search, placement: .bottomBar)`, `ToolbarSpacer`, and the "+" as a bottom-bar item; on iOS 17–18 the same row by `.safeAreaInset(edge: .bottom)`. Mac and iPad stay exactly as they are.
- **Press the app icon long:** New board, New mind map, New board from the clipboard, and the two pinned boards (`UIApplicationShortcutItems` in `Info.plist` + dynamic `UIApplication.shared.shortcutItems`; marks as template pictures drawn in his style, not system symbols).
- **Camera on the picture tool:** hold the Picture tile → a plate "Photos / Take a photo / Scan a page". Take a photo = `UIImagePickerController(.camera)`; Scan = VisionKit `VNDocumentCameraViewController`, which straightens a paper sketch or a whiteboard before it lands on the board.
- **Three-finger undo and shake to undo:** register each board step with the window's `UndoManager` (`@Environment(\.undoManager)`, `registerUndo(withTarget:)` + `setActionName`), so the system's own gestures work on iPhone and iPad and the Mac's Edit menu says "Undo Move" instead of plain "Undo". The own 120-step stack stays the truth; the system's manager only calls `session.undo()` / `redo()`.

**Traps:**
- The thumb row MOVES two things he placed. His rule: a redesign never moves what he placed without asking — show ONE picture (today / proposed) and lock the pick with a screen test.
- Quick actions need a `UIApplicationDelegateAdaptor` and a scene delegate (`windowScene(_:performActionFor:)`, and `connectionOptions.shortcutItem` on a cold start); route them through `AppModel.open(url:)` with the new `seedboard://new/…` links of finding 5.
- The camera needs `NSCameraUsageDescription` in `project.yml` ("To put a photo straight onto a board."); the photo picker needed no question, the camera asks once.
- The system's undo gestures reach the app only if the touch surface does not swallow three-finger touches: `TouchLayer.swift` takes one and two fingers; check that a third finger cancels the two-finger slide cleanly, and leave `editingInteractionConfiguration` at `.default`.
- The Edit menu's Undo / Redo are replaced by hand today (`BoardView.swift:457-468`); when the system's manager is fed, keep ONE path or one press undoes twice.

**Size:** M. **New target:** no.

---

## Order I would build in

1. Finding 6 (search + Handoff) and finding 9's Help menu: small, no risk, fixes two real gaps.
2. Finding 3 (Add to board), which also brings `Board.arrivalSpot` — the groundwork for 1 and 7.
3. Finding 4 (print, PDF) and finding 7 (real file, drag out).
4. The two new targets together in one round (findings 1 and 5): one bundle-id step, one signing change in `Tools/release.sh`, one check of both platforms in `/v1/builds`.
5. Finding 2 (windows) as its own round: it touches the model's heart and wants a quiet build.
6. Findings 8 and 10 once he has a Pencil in his hand and has picked from one picture.

Not proposed, on purpose: find in a board, a note on an idea, tool pill words, big-board speed (turned down in `PANEL-0.2.md`, picks 9, 22, 23, 27); a Quick Look extension (a third new target for little); Live Activities; anything with a server.
