# Shared framework — QML warnings that were hiding real errors

The clipboard bug (`04`) sat in the journal for a long time as two `TypeError`
lines per row. They were invisible in practice for two reasons: this
installation sets `QT_LOGGING_RULES=*=false` session-wide, and once logging is
re-enabled the launcher emitted **72 "Overwriting binding" warnings** per start
for the Info page alone, which is enough noise to lose a real error in.

None of those 72 were defects on their own, but clearing them is what makes the
journal usable as a diagnostic tool, so they were fixed at the source rather
than filtered.

## What they were

QML warns when an imperative assignment destroys a property's initial
*binding*. A plain literal initialiser is not a binding, so assigning over it is
silent. Every warning came from the same shape: a property declared with an
expression and later assigned.

| Where | Property | Frequency |
|---|---|---|
| `GadgetHost.qml` | `accent`, bound to `Kirigami.Theme.highlightColor` | 23 gadgets set their own colour, every start |
| `GadgetHost.qml` | `cfg`, initialised `({})` | twice per settings save, per gadget |
| `GadgetGrid.qml` | `positions` `({})`, `occupancy` `[]` | every layout recompute |
| `QuotesGadget.qml` | `current`, bound to `local[0]` | every start |
| `FullRepresentation.qml` | `currentIndex`, bound to `root.initialTab` | every time the menu opens |

## How they were fixed

The pattern is the same in each case: split the property into a settable half
carrying **no** initialiser (or a literal) and a read-only half that supplies
the default.

```qml
// gadgets assign accentColor; everything reads accent
property color accentColor: "transparent"
readonly property color accent: accentColor.a > 0 ? accentColor : Kirigami.Theme.highlightColor
```

`accent` deserves a note, because the naive fix is wrong: fifteen gadgets
*read* `host.accent`, so simply dropping the theme binding would have left
those elements transparent. Inverting the split — gadgets write `accentColor`,
everyone reads `accent` — keeps all fifteen readers untouched and preserves the
theme fallback for any gadget that states no colour of its own.

`GadgetHost.cfg` became `cfgData` (settable, no initialiser) plus a read-only
`cfg` that is never `undefined`. This one carried the most risk, since `cfg`
drives every gadget's settings and `onCfgChanged` drives the weather refresh,
so it was re-verified end to end: a manual city (`Porto Alegre`) still
geocodes, persists its coordinates and fetches a forecast
(`scopeKey city:porto alegre|c`, 21 °C).

## Result

Measured on the VM with logging re-enabled, opening the menu on the Info page:

| | Before | After |
|---|---|---|
| ClipboardGadget `TypeError`s | one pair per rendered row | 0 |
| "Overwriting binding" from our QML | 72 | 0 |
| Any `org.biglinux.appsmenu` warning or error | many | **none** |

## Cache growth (performance)

Also fixed here, described in `00-current-architecture-audit.md`: the gadget
cache is persisted into the plasmoid config and was never pruned. A real config
on the VM held 28 keys, including seven orphaned weather and seven orphaned
currency payloads from gadget instances that no longer existed. `InfoPage`
now drops, on load, every key whose prefix is neither a live instance uid nor a
live gadget id; that config went to 6 keys.
