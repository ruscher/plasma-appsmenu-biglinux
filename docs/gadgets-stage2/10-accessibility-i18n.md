# 10 — Accessibility and internationalisation

## Internationalisation

The kit's `audit.py` scans every `gadgets/**/*.qml` for user-visible
properties (`text`, `placeholderText`, `title`, tooltips,
`Accessible.name/description`) whose value is a literal not wrapped in
`i18n*`. Result on the final tree: **0 untranslated visible literals**.
The same pass flags Portuguese words inside source strings; its one hit
is an English sentence in the Weather attribution (a substring match), not
Portuguese.

Rules followed by the new and changed strings:

- English source, `i18nc` with a context for anything short or ambiguous
  (`"@info data rate", "%1 KiB/s"`; `"@action:button", "New game"`;
  `"@info short temperature status", "Moderately high"`).
- Plurals through `i18ncp` (`"%1 fan turning" / "%1 fans turning"`,
  `"%1 column" / "%1 columns"`).
- Numbers through `toLocaleString(Qt.locale(), …)` — speeds, sizes,
  temperatures, RPM.
- Names that a daemon already localises are used as-is, never rebuilt:
  KSystemStats sensor names (the VM and the host showed *Temperatura
  média*, *Ventoinha 1*), plasma-nm's detail labels and values in the
  Network → Details tab, the GPU marketing names.
- The header's Edit/Done button is sized from `TextMetrics` of **both**
  translations, so the right-hand controls stay put in any language.
- The Countdown notification component ships a `Name[pt_BR]`.

## Accessibility

What each changed piece exposes (counted with `grep`, then read):

| file | `Accessible.*` | keyboard |
|---|---|---|
| `SensorGadget` | rows are `ListItem`s named *"<name>, <temperature>, <status>"*; group headers are `Heading`s | — |
| `FansGadget` | rows named *"<name>, <rpm> RPM"* / *"<name>, stopped"*; the icon is `Accessible.ignored` | — |
| `CountdownGadget` | 10 sites: each event row, bell / dismiss / remove buttons named | — |
| `NetworkGadget` / `NetworkDetails` | section titles are `Heading`s; copy buttons are named *"Copy <field>"*, and their tooltip reads *"Copied"* for a moment after use | — |
| `GalleryGadget` | previous / next buttons named | `activeFocusOnTab`, Left / Right |
| `Game2048` | d-pad buttons *Move left/up/down/right* | `Keys.onPressed` arrows |
| `Sudoku` | cells as `Accessible.Cell` with value or *"empty"*, pad digits and *"Clear cell"* | arrows move, 1–9 enter, 0 / Delete / Backspace clear, N toggles pencil marks |
| `Minesweeper`, `FlowConnect` | cells as `Accessible.Cell` with state | — |
| `BlockPuzzle` | tray slots as `Accessible.Button` *"Piece n"* / *"Piece n, selected"*; board cells | — |
| `InfoPage` | the page is a `Pane` named *"Info dashboard"*; column buttons *"%1 columns"*, *"Edit gadgets"* / *"Finish editing gadgets"*, *"Add gadget"*; the auto-scroll zones are `Accessible.ignored` | — |
| `GadgetHost` / `GadgetTitleBar` | the title is a `Heading`; title actions are `PC3.ToolButton`s named after their action; the edit badges are *"Remove %1"*, *"Change size of %1"*, *"Configure %1"* | title actions and badges are ordinary buttons, reachable by Tab |

Colour is never the only channel: the temperature band is also in the
subtitle text, the row tooltip and the accessible name; the fan state is
in the "0 RPM" text; the *LIVE* mark in Sports is a word, not only a dot;
Block Puzzle's rejected placement is tinted **and** the piece stays in
the tray.

Motion respects the system: every animation is `enabled` on
`Kirigami.Units.longDuration > 0` (the fan timer too), so
*Animation speed: instant* stops all of it. The fan spin has its own
switch as well.

## Stated limits

- No screen-reader session was run (no Orca on the lab VM); the
  properties above were verified in the sources and in the engine, not
  through AT-SPI.
- Board games without a keyboard model (Minesweeper, Flow Connect, Block
  Puzzle) are pointer / touch games; their cells announce state but are
  not keyboard-playable. That is unchanged from the previous stage.
