# Panel before 0.5 — the flow of thinking (18 Nov 2026)

Lens: how fast a thought gets onto a board, how a board grows from a seed to a structure, and what the best thinking tools do that Seedboard 0.4 lacks or does clumsily. Read: `Docs/SPEC.md`, `Docs/PANEL-0.2.md`, the code as it stands at commit a6e6f58, and the pictures in `Docs/pictures`. Nothing was built, run or changed. Every "Today" was checked in the code; the line numbers are from that commit.

Ten findings, ranked by how much each would lift the app. Two are BUGs (wrong today), eight are IDEAs (Martin picks).

The short of it: getting ONE thought onto a board is fast, and a mind map grows well with the keys. The weak spots are (a) the second, third, tenth sticky note, (b) the step after the dump — sorting a pile and turning it into a structure, where today everything is typed again — and (c) the hand-over, where the sorting done with frames is lost.

---

## 1. Groups in frames are lost in PARAGON — BUG

**Today:** The "Pros and cons" starter is two plain frames named Pros and Cons with sticky notes in them (`Core/Sources/SeedboardCore/Starters.swift:81-93`). Sent as a note, every sticky note lands in ONE flat list under "Notes", in the order the notes were MADE, not where they lie; the words "Pros" and "Cons" appear nowhere in the text (`Paragon.swift:101` and `259-262`). Only a frame WITH lanes gets headings (`ParagonLanes.swift:15`). The same loss in a project's Notes (`Paragon.swift:134-136`) and in More → Copy the board as text (`Outline.swift:183`). So a pro and a con stand mixed in PARAGON, and any sorting done by dragging notes into named frames survives only in the picture.

**Better:** A plain frame with a name is a heading.
- Note: under "Notes", first `### Pros` with its things, then `### Cons`, then the things that lie in no frame. Inside a group and outside: reading order (left to right, then down), not the order made. The rule for "what lies in a frame, in reading order" already exists and works for plain frames (`Lanes.swift:246`, `things(in:)`).
- Project: ticked things inside a frame become tasks under `### <frame name>` instead of the one flat "To do" group.
- Copy the board as text: "Pros:" and its lines, "Cons:" and its lines.
- A frame with no name: its things are listed as today.
- One data test: the Pros and cons starter, sent as a note, has the two headings with the right notes under each.

**Does it well:** Miro (frames become the sections of an export), Whimsical, MindNode (the outline keeps the grouping).
**Size:** S.

---

## 2. Next note and next shape while typing — IDEA

**Today:** Ideas chain: Return makes the next idea, Tab an idea under, and the iPhone/iPad keyboard bar has buttons for both (`App/Sources/MapOrder.swift:174-189`). Sticky notes do not chain:
- Return and Tab in a sticky note only end the typing (`CanvasView.swift:233` and `236-242`).
- The bar over the screen keyboard shows only "Done" for a note AND for a shape (`MapOrder.swift:190-193`). Tab on a real keyboard makes the next shape with its arrow (`ArrowSession.swift:61-83`), but on the iPhone there is no button for it.
- Mac: two clicks on empty board make a note only when nothing was chosen before the first click (`CanvasView.swift:583-591`). Right after typing a note, that note is chosen — so the next double-click only un-chooses, and it takes three clicks to get the next note.
- iPhone and iPad: two presses on empty board show the whole board (`CanvasView.swift:578-582`). The only "new thing right here" is: rest the finger 0.5 s → menu → New note here.
So a brain dump of ten notes is ten trips to the tool row, and each note lands in the middle of the view (`BoardSession.swift:380-392`), not where he is working.

**Better:**
- a. Tab while typing in a sticky note: the words are kept, the next note appears right beside it (same colour, same size, 16 points to the right; when that place is taken, under the first note of the row) and the typing goes on. A new note left empty goes away again, as an empty new idea does.
- b. Keyboard bar on iPhone and iPad: for a note a button "Next note" (does a.), for a shape "Next shape" (does what Tab does today). Same look as the idea buttons, in the notes / shapes colour, hand-drawn marks.
- c. Mac: two clicks on empty board ALWAYS make a note there, also when something was chosen.
- d. His pick, because it changes a gesture he has today: two presses on empty board on iPhone and iPad make a note right there too (as on the Mac). "Show the whole board" keeps its button in the zoom cluster.

**Does it well:** FigJam and Whimsical (⌘Return = next sticky), Miro (Tab = next sticky), Scapple and Kinopio (double-click anywhere and type — the whole app is built on it).
**Size:** S.

---

## 3. Turn a thing into another kind — IDEA

**Today:** Only a flow shape can become another flow shape (`Core/Sources/SeedboardCore/Shapes.swift:66`, the guard needs both to be shapes). A sticky note cannot become an idea or a box. An idea hangs only under an idea; anything else is refused (`MindMap.swift:211-214`). A note dragged onto an idea is simply laid on top of it (`CanvasView.swift:489-498`). So the most common way of thinking — dump loose notes first, build the structure afterwards — means typing every note again as an idea.

**Better:**
- a. "Turn into" in the menu of a thing and behind the bar's "…", for one or several chosen things: Sticky note, Box, Text, Idea. Words, colour, the To do tick and the place stay; arrows stay; one Undo step. An idea turned into something else leaves its map, and the ideas under it move up to its parent.
- b. Drag a sticky note, a box or a text onto an idea: the dashed green frame shows (the one an idea drag shows today); let go and it becomes an idea under that one. A notice "Now an idea" with Undo for 6 seconds, like "Made its own map".
- c. Several notes chosen → "Make a mind map" in the bar: a small page asks for the middle idea (filled in with the board's name; Cancel, Save); the notes become main branches in reading order. Notes that lie in a named frame hang under a branch with the frame's name.
- d. The way back, in an idea's menu: "Break into notes" — the idea and those under it become sticky notes in a neat column in the branch's colour.

**Does it well:** Miro ("switch type": sticky ↔ shape ↔ text ↔ card), Scapple (drop one note on another to join them), MindNode (drag any node onto another; pull one out to make it free).
**Size:** M.

---

## 4. Sort a pile of notes — IDEA

**Today:** With several things chosen the bar has Line up, Even gaps, Same size, Duplicate, To do, Remove — no Colour (`App/Sources/BarActions.swift:216-227`), although the colour rule already takes several things (`BoardSession.swift:560-576`). Colouring eight notes is eight times choose → Colour → dot. "Line up" puts things on one line and keeps their places along it (`Tidy.swift:30-41`), so a pile becomes a line of notes lying on each other. There is no grid and no gathering by colour.

**Better:**
- a. A Colour button in the bar and in the menu when several things are chosen (the ring shows only when all have the same colour).
- b. "Tidy" in the bar from 3 chosen notes or shapes: a neat grid where the pile lies — its top left corner stays, at most 5 across, 16 points apart, reading order kept. One Undo step.
- c. "By colour" behind "…": one column per colour, in the order of the colour dots.
- d. "Choose all of this colour" in a note's menu.
- e. Later, his pick: names for colours on a board ("pink = risk"), shown as a small key in a corner of the board and its picture, and used as headings in PARAGON.

**Does it well:** Miro (cluster and sort stickies by colour), FigJam ("Tidy up"), Freeform (align and distribute), Kinopio (tags by colour).
**Size:** S for a., M for b. to d.

---

## 5. A door from one board to another — IDEA

**Today:** Boards cannot point to each other. The specification says "there are still no files or links on a board" (`Docs/SPEC.md:1001`); the only link the app opens is PARAGON's (`App/Sources/AppModel.swift:546-550`). The app can already follow a link to a board (`AppModel.swift:404-416`), but nothing on a board can hold one. A board that gets too big can only get bigger; a part can be copied to another board by hand (Copy, New board, Paste) and leaves no trace of where it went.

**Better:** A new thing, the Door (board format 5): a small card with the other board's colour dot, its name and its small picture.
- Two presses, or Return, open that board. The top bar then has, at the left, "‹ <name of the board he came from>" to go back (Mac also ⌘[).
- Made in three ways: (1) menu of empty board → "Door to a board…" → the list of boards with the search field, "New board" at the top; (2) drag a board from the list onto the open board (Mac, iPad); (3) with things chosen → menu → "Move to a new board…": asks the name (Cancel, Save), the chosen things (a branch, a frame with what lies in it) move to a new board and a door is left in their place.
- A door to a removed board says "This board was removed" with Bring back (the rule and the line exist, 2.1).
- An arrow can start or end at a door. In PARAGON a door is a line with a link that opens that board.

**Does it well:** Muse (boards inside boards — its whole idea), Kinopio (links between spaces), Miro and Whimsical (link to a board), tldraw (pages).
**Size:** M to L.

---

## 6. Make a timeline from a plan — IDEA

**Today:** A timeline is its own kind of board and starts empty or from the starter. A list cannot be pasted onto it (`BoardSession.swift:471`; `Docs/SPEC.md:1008`), and nothing turns a mind map or a "Plan in steps" board into bars — although the bricks are there (`Core/Sources/SeedboardCore/Timeline.swift:448` adds a bar, `:480` a bar that comes after another). A plan that grew as a map is typed again as bars.

**Better:**
- a. More → "Make a timeline of it" on an ordinary board. A NEW board "<name> timeline" is made; the old one stays. Each main branch becomes a phase with its name; each idea under it becomes a bar of 7 days, starting today, one after the other, each "comes after" the one before in its phase. A flow: its shapes in arrow order become bars in a chain. When ideas are ticked To do, only the ticked ones (the same rule as "a project by the ticks"). With ideas chosen: only those. Deeper ideas are left out, and the notice says so: "12 bars made. 5 deeper ideas stayed on the board."
- b. On a timeline board, Paste (⌘V, menu, More) of a list: one bar per line under the chosen row, 7 days each, in a chain; a line with indented lines under it becomes a phase.

**Does it well:** Miro (a mind map's branches into cards on a timeline), MindNode (map → tasks), Whimsical (one board, several views of the same thing).
**Size:** M.

---

## 7. Share a part, as picture or PDF — IDEA

**Today:** More → "Share a picture…" makes one picture of the WHOLE board (`App/Sources/BoardView.swift:261`; `BoardPicture.swift:13-43`). It is made of dots, twice the size, and only plain size when the board is wider than 3000 points — so a big board goes soft exactly when it is big. A picture of only what is chosen exists just on the clipboard after Copy (`ClipBoard.swift:138`). There is no PDF and no printing anywhere in the code.

**Better:** "Share…" takes the place of "Share a picture…" (More, File menu) and opens a small plate:
- What: Whole board · What is chosen (only when something is) · Each frame a page (only when the board has named frames).
- As: Picture · PDF · Words (the list that "Copy the board as text" makes).
- A full-colour Share button, Cancel; Escape is Cancel.
- The PDF is drawn by the same painter as lines and real letters: sharp at any zoom, the words can be found and marked, white ground, day look. "Each frame a page" gives one page per frame in reading order, the frame's name as its heading — a board becomes a small hand-out.
- Mac: File ▸ Print… ⌘P. Menu of a thing or of several: "Share this…" opens the plate at "What is chosen".

**Does it well:** Miro (frames to PDF pages), Freeform (PDF), MindNode (PDF, picture, text), Excalidraw and Whimsical (export only what is chosen).
**Size:** M.

---

## 8. Pasted paragraphs become a mind map — BUG

**Today:** Any text with two lines that are not empty counts as a list (`Core/Sources/SeedboardCore/Outline.swift:71-73`) and becomes a mind map with "Ideas" in the middle (`Clip.swift:173-178`; `BoardSession.swift:481-483`). The same for text dragged in from Safari (`ClipBoard.swift:331`) and for the Shortcuts action "New board from text" (`Outside.swift:11`). Two paragraphs copied from an e-mail or a web page become a map whose branches are whole paragraphs.

**Better:** Text is a list only when (a) at least one line begins with a list mark, a number, a tick box, a heading mark or an indent, or (b) every line is short (80 letters at most). Anything else is ordinary text and becomes ONE Text thing with its lines kept. With one idea chosen nothing changes (the lines hang under it). More → "Paste a list as a mind map" always makes a map — the way to say "I do mean a map". One data test: two paragraphs → one text; three short lines → a map; a marked list with one long line → a map.

**Does it well:** Freeform and Miro (text stays text; only list rows become separate notes), Whimsical.
**Size:** S.

---

## 9. Add a thought to a board from anywhere — IDEA

**Today:** Three Shortcuts actions: New board from text, New board, Open board (`App/Sources/Intents.swift:83`, `110`, `132`). None adds to a board that already exists, and all three bring the app to the front (`openAppWhenRun = true`, lines 86, 113, 135). A thought for "Summer cabin" that comes while he is in another app means: open Seedboard, find the board, press a tool, type.

**Better:** A fourth action, "Add to a board": Board (the same chooser as Open board; first choice "the board opened last"), Text, and a switch "Open the board afterwards" (off). One line becomes a sticky note beside the newest note of that board (not in the middle of the view); on a board that is one mind map and nothing else, a new main branch. Several lines follow the paste rule (finding 8). The app stays in the back. When the board is opened next, the things added from outside are chosen once, so he sees what arrived. Phrase: "Add to <board> in Seedboard". Works from Raycast, Siri, the Action button, and from the Share sheet through a shortcut.

**Does it well:** MindNode (Quick Entry: type a list anywhere, it lands in a map), Kinopio (share sheet → inbox space), Miro (capture from the phone).
**Size:** S to M.

---

## 10. A mind map as a list, side by side — IDEA

**Today:** A map becomes a list and a list a map only by way of the clipboard: More → Copy the board as text (`Core/Sources/SeedboardCore/Outline.swift:161`) and More → Paste a list as a mind map (`App/Sources/BoardView.swift:249-254`). There is no list to read or type in beside the map. On the iPhone a map of 40 ideas is read by sliding about at 75 %.

**Better:** On a board with a mind map, a "List" button in the top bar (a hand-drawn list mark; ⌘L).
- Mac and iPad: a panel at the right, 280 wide; the map stays in view. iPhone: the list takes the screen; the same button goes back to the map.
- Each idea is a row, set in by its level, with its branch's colour dot. Pressing a row chooses the idea and brings it into view on the map; choosing on the map lights the row.
- In the list the same keys do the same things as on the map — Return next idea, Tab and Shift+Tab in and out a level, ⌘↑ / ⌘↓ move — and a row can be dragged to another place. All four rules exist (`addSister`, `addChild`, `moveOut`, `shiftIdea`). A small arrow on a row folds it; a tick box at the row's end is To do.
- Notes and shapes are not in the list; a line at the bottom says "5 notes and 3 shapes are on the board only."
- Nothing new is stored: it is a second view of the same ideas.

**Does it well:** MindNode (the Outline beside the map is why people stay with it), Whimsical (mind map ↔ document), Scapple with Scrivener.
**Size:** L.

---

## Looked at and left out on purpose

- Focus on one branch ("Only this branch"), find inside a board, and fold by pressing the dot were all part of pick 22 of the 0.2 panel, which Martin turned down. Not proposed again.
- "See also" lines between ideas and a note on an idea: pick 23, turned down. Not proposed again.
- One neighbour of pick 22 is worth a yes-or-no at some point, and is NOT the same thing: the search over ALL boards finds a board by the words on it (`Core/Sources/SeedboardCore/Home.swift:19-40`), but the found board opens at its old place with no sign of where the word is. A found board could show the line that holds the word under its name and open with that thing chosen and in view. Size S. Left out of the ten because it sits close to what was turned down.
- Presenting a board step by step (Miro, Freeform scenes): no audience here; "Each frame a page" in finding 7 covers the hand-out.
- Team things (comments, votes, cursors), accounts, anything with a server: not for this app.
