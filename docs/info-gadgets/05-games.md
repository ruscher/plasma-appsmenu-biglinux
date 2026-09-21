# 13. Games — five of them behind one card

## Architecture

Five gadgets would have crowded the gallery for no benefit, so the games share
one entry:

```
items/GamesGadget.qml          the card: selector, loader, shared settings
items/games/Game2048.qml       moved from items/PuzzleGadget.qml, unchanged
items/games/Minesweeper.qml
items/games/Sudoku.qml
items/games/FlowConnect.qml
items/games/BlockPuzzle.qml
```

The selector is the same scrolling strip the news sources use, so five names
never squeeze each other into illegibility. A game may publish its own options
as a `gameSettings` Component and the shared dialog shows them under the game
picker, which is how difficulty reaches the user without a gadget each.

Two things had to be got right for this not to cost anybody anything:

* **The 2048 survives.** Its file moved but its code and its `cfg.best` key did
  not change, so a high score saved before this reorganisation is still read.
* **Existing boards keep their gadget.** A layout saved with `id: "puzzle"`
  would simply have lost the card. `InfoPage.migrate()` rewrites it to
  `"games"` on load, keeping position and settings and adding `game: "2048"`,
  and bumps a `1x1` card to `1x2`, since there is now a selector above the
  board. Verified on a real config: `{"id":"puzzle","size":"1x1","cfg":{}}`
  came back as `games`, `1x2`, `{"game":"2048"}`.

Sudoku asks for a 2×2 card. Rather than drawing a nine-by-nine grid nobody
could read, a card that is too small says so and offers the way out.

## Licensing

Everything here is written for this project and carries the same
`GPL-2.0-or-later` as the rest. No third-party code, artwork or sound is
bundled. The two games that echo commercial products use generic names —
**Flow Connect** and **Block Puzzle** — with mechanics implemented from
scratch; the shapes in Block Puzzle are polyominoes, which are mathematics
rather than anyone's artwork, and every colour comes from a palette defined in
the file. Sudoku ships no puzzles at all: it generates them.

## The games

**Minesweeper** — 8×8/10, 10×10/18 or 12×12/30 by difficulty. Mines are laid
*after* the first click, excluding that cell and its neighbours, so an opening
move can never lose. Flood fill is iterative, because a recursive one would
risk the stack on a large empty region. Right-click or long-press flags.

**Sudoku** — a complete grid is built by randomised backtracking and then cells
are removed (42 / 34 / 27 clues). Conflicts are highlighted live rather than
only at the end, pencil marks are stored as a bitmask per cell, and the
keyboard works throughout: arrows, 1–9, Delete, and N for notes.

**Flow Connect** — join each pair of dots without crossing. The two base boards
were laid out by hand so that a full-coverage solution exists, and each new
game applies one of the eight rotations and mirrors, which preserves
solvability. Drawing works by dragging and by tapping square by square, so a
mouse, a finger or taps alone all work. Crossing another colour cuts that
colour's path back rather than refusing the move.

**Block Puzzle** — three offered pieces, placed by tapping the piece and then
the board, with a preview under the pointer. Full rows and columns are found
together and cleared together, so a piece completing both scores for both, and
the game ends when none of the three still fits anywhere.

## Tests (all five, in the running engine)

| game | checks |
|---|---|
| 2048 | loads, two tiles at reset, moves accepted, previous best (8) still read |
| Minesweeper | mines laid on first click, **first click never loses**, flag toggles, revealing all 54 safe cells of an 8×8/10 board wins |
| Sudoku | 42 clues at Easy, **0 conflicts in a fresh puzzle**, filling in the generated solution is detected as solved |
| Flow Connect | 5 pairs, 0 joined at start, a path drawn dot-to-dot reports `firstPairConnected: true` |
| Block Puzzle | tray of 3, all three placed legally, score grows, a hand-filled row clears completely |

## One bug worth recording

The Flow board would not build: `Property 'transform' of object FlowConnect is
not a function`. A helper had been named `transform`, and **every `Item`
already has a `transform` property**, which shadowed it. This is the third
member of that family met in this mission, after `clip` (which is what made
the clipboard list look empty, `04-…-clipboard.md`) and `state` from an earlier
one. The rule is simple and worth repeating: never name anything on an `Item`
after a property `Item` already has.
