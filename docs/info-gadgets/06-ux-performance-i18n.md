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

---

# 14–19. The cross-cutting sweep

Rather than eyeballing twenty-four files, the sweep was written as a script
(kept in the session scratchpad, not shipped) that reads every gadget and
reports what it finds. Its first run is what turned up most of what follows.

## 15. Scroll — content that existed but could not be reached

The recurring defect had a recurring shape: `model: things.slice(0, n)`. That
is not a display limit, it is a deletion — the items past the cut do not exist
as far as the interface is concerned, and no amount of scrolling reaches them.

| gadget | was | now |
|---|---|---|
| News sources | `slice(0, wide ? 5 : 3)` | scrolling `GadgetTabStrip` |
| Currency rates | `slice(0, compact ? 4 : 8)` | scrolling `ListView` |
| Live Scores leagues | `slice(0, wide ? 4 : 3)` | scrolling `GadgetTabStrip` |
| Countdown finished events | `slice(0, compact ? 1 : 3)` | bounded scrolling list |
| GPU Meter cards | `slice(0, 2)` | scrolling list |
| Clipboard entries | `visible: index < maxRows` | scrolling `ListView` |

Countdown and GPU deserve a note. A finished countdown's row is the only way to
dismiss it, so hiding the fourth one left it stuck forever; and a machine with
three graphics cards simply never saw the third. Both now scroll, Countdown
within a bounded height so the running countdown is not pushed off the card.

Horizontal scrolling is used **only** where the content is naturally
horizontal — the source and league strips — and those strips disable their
wheel handler when everything fits, so the page behind keeps scrolling rather
than the strip swallowing the event.

Final state: every gadget with variable content has a real scrolling view and a
scrollbar that appears only when it is needed. The one gadget flagged without a
scrollbar, Notes, uses `QQC2.ScrollView`, which brings its own.

## 16. Internationalisation

The sweep found three visible literals with no `i18n`: the `W` unit in Battery
and two feed-address placeholders in News. All three are wrapped now, with
`i18nc` contexts.

Source strings are English throughout; no Portuguese reached the interface.
Every new string added by this work uses `i18n`, `i18nc` or `i18np`, including
tooltips, empty states, error text, button labels, placeholders and
`Accessible.name`, and the plural forms go through `i18np` rather than string
concatenation. Nothing in `locale/` was touched.

## 17. Performance

**Zero repeating timers run while their gadget is invisible.** Every one is
tied to `host.active`, which already folds in "the menu is open" and "this card
is in the viewport".

Network calls all go through `GadgetNet`, which applies a timeout, returns
errors through the callback rather than throwing, and is paired with a cache in
every caller. Two caches were made *stricter* by this work, because a cache
that answers the wrong question is worse than none: the weather cache now
records the location and unit it was fetched for, and the currency cache is
only usable if it covers every currency on screen — that one was silently
serving five rates for twenty-nine selections.

The one request-per-many-targets pattern in Currency was kept: 29 currencies
still cost exactly one request, confirmed by `requestId: 1` in the live test.

Image loading is bounded — the Gallery decodes at 1024 px regardless of the
photograph's real size, and clipboard thumbnails at icon size.

And the gadget cache, which is persisted into the plasmoid configuration, is
now pruned on load: a real config went from 28 keys to 6.

## 18. Privacy and security

| check | result |
|---|---|
| cleartext `http://` requests | **0** — the weather fallback was the only one and is gone |
| hard-coded API keys or secrets | **0** |
| clipboard content leaving the machine | none: no network call exists in that gadget, and the tests measure lengths and types only |
| clipboard content in logs | none, deliberately — not even truncated |
| shell invocations | 8, all reviewed |

Of the shell invocations, six are fixed command strings (the calendar opener
and the countdown alarm). The two that carry user-influenced data are Quick
Links, where a desktop id is validated against a pattern admitting no quote,
space or shell metacharacter, rejected if it contains `..`, single-quoted when
the command is built, and validated **again** inside the helper. Twelve
injection attempts were rejected in testing.

RSS treats its input defensively already: the parser never throws, strips HTML
for summaries, and was re-tested against truncated, malformed, empty and
HTML-instead-of-feed responses.

## 19. Compatibility

Nothing protocol-specific was introduced — a search for Wayland, X11, xcb,
`XDG_SESSION_TYPE`, xdotool and ydotool across the gadgets and tools finds
nothing.

That is an argument, not a test, so the VM was switched to an X11 session
(`plasmax11.desktop`) and the work re-run there. Session type confirmed from
the plasmashell process itself — `XDG_SESSION_TYPE=x11`, `DISPLAY=:0`, with
`Xorg` and `kwin_x11` running — never from the SSH shell.

| check | Wayland | X11 |
|---|---|---|
| Drive Info | 2 volumes, 2 rendered, `38,0 GiB free of 50,0 GiB` | 2 volumes, 2 rendered, `38,1 GiB free of 50,0 GiB` |
| Clipboard | 15 entries, 15 rendered, delegates built | identical |
| Quick Links | 11 resolved, 10 tiles | identical |
| QML messages | none | one, since fixed |

The X11 run earned its keep: it surfaced an `Overwriting binding` on
`DriveInfoGadget.volumes` that the Wayland sweep had not shown. It is fixed,
and the final Wayland run is clean again.

The VM was returned to its original state: the autologin file used to switch
sessions is gone, `/etc/sddm.conf.d/` holds only the `kde_settings.conf` it
started with, and the Wayland session is running.

**NOT TESTED:** fractional/HiDPI scaling, and resolutions other than the VM's
own. Those were not exercised and are reported as untested rather than assumed.
