# Final report — Info gadgets

Twenty numbered items, all addressed. Everything below was verified on the lab
VM (Plasma 6.7.4 / KF 6.29 / Qt 6.11.2) against the deployed package; the
evidence is in `07-test-matrix.md` and the per-item documents.

## What was wrong, and what it turned out to be

Three defects were worth more than their individual gadgets, because the same
mistake was waiting elsewhere:

**An id that a built-in property shadows.** The clipboard gadget's root was
`Item { id: clip }`, and every `Item` already has `clip : bool`. Inside every
delegate, `clip.preview(…)` was `false.preview(…)`. The header counted entries
correctly while every row drew empty — the reported "8 items and an empty
list". The same trap caught a helper named `transform` in the new Flow board.
The rule: never name anything on an `Item` after something `Item` already has.

**Reentrancy through a signal that fires twice.** `GadgetHost.saveCfg()` emits
`cfgChanged` twice for one save. Weather guarded with `if (busy) return` and
then relied on that very signal to continue after geocoding — so the forecast
was never requested, `busy` stayed true forever, and every later refresh was
rejected too. One bug produced all three reported symptoms: manual city, °F and
the endless spinner. The fix is to react to a derived key naming the request
rather than to the signal, and to let requests supersede one another instead of
being dropped.

**`slice(0, n)` used as a display limit.** It is not one; it is a deletion. Six
gadgets hid content that nothing could reach: news sources, currency rates,
league switcher, finished countdowns, GPU cards and clipboard entries.

## Per gadget

| Gadget | Problem | Fix | Tested | Result |
|---|---|---|---|---|
| Weather | manual city, °F and endless spinner — one reentrancy bug | single exit point, request generation, key-based trigger, scope-checked cache | 11 cases incl. offline | **PASS** |
| Weather (provider) | cleartext `http://ip-api.com` was the live path | HTTPS-only keyless chain | empty cache forces the chain | **PASS** |
| Calendar | unclear icon; "back to today" hidden on the month label | verified icon; generic `titleActions` slot + Today button | navigate 3 months, return | **PASS** |
| GPU Meter | last in the layout; `gpu` icon exists nowhere | reordered CPU→GPU→Memory; uses `cpu`; all cards listed | layout + icon presence | **PASS** |
| Quick Links | copied names/icons drifted (`bigstore` ≠ `big-store`) | resolve through `.desktop` with a new helper; `gio launch` | 10 resolved, 1 launched, 4 injections | **PASS** |
| News / RSS | three feeds to drop; sources past the third unreachable | defaults trimmed and verified; scrolling `GadgetTabStrip`; stale caches swept | 8 sources, 3 formats, 10 edge cases | **PASS** |
| Drive Info | "3 volumes" over 2 rows; no hotplug | rewritten on Solid; header counts what it renders | full attach→mount→unmount→detach cycle | **PASS** |
| Quote of the Day | untranslatable third-party quotations | 40 original `i18nc` messages; one verified provider; structural fallback | local, online, online-down | **PASS** |
| Countdown | unsaved event discarded silently | generic `requestClose` hook on the shared dialog; Add/Discard/Cancel | 6 cases | **PASS** |
| Currency | `slice(0, 4/8)`; cache ignored the selection | scrolling list; cache must cover what is shown; Select all / Clear | 1, 4 and 29 currencies | **PASS** |
| Live Scores | score off centre, small badges, cramped settings | symmetric columns; bigger badges with fallback; responsive grid; interval + notifications | 117 px → 0 px; 3/2/1 columns | **PASS** |
| Gallery | four formats; a bad file cost a turn | eight more formats, each decoded on the target; failures remembered and skipped | 10 formats + a corrupt file | **PASS** |
| Clipboard | "N items" over an empty list | root id renamed; tooltips, thumbnails, masking, scrolling | 7 checks, counts only | **PASS** |
| Games | only 2048 | one `Games` card with five games and a migration | all five + migration | **PASS** |

## Shared components

Changes that paid off across the board, rather than in one gadget:

* `GadgetTabStrip` — a scrolling chip strip, now used by News and Live Scores.
* `GadgetHost.titleActions` — a gadget can put a button beside its title.
* `GadgetSettingsDialog.tryClose()` — a settings page can refuse to close.
* `cacheKeys` / `cacheRemove` — a gadget can forget what it no longer needs.
* `InfoPage.pruneCache()` — the persisted cache no longer grows forever; a real
  config went from 28 keys to 6.
* `InfoPage.migrate()` — a renamed gadget keeps its place and its settings.
* The `accent` split, which removed 23 warnings a start.

## Journal

The measure that matters most, because it is what let the clipboard bug hide
for so long. Opening the menu on the Info page, with logging re-enabled:

| | before | after |
|---|---|---|
| `TypeError`s from ClipboardGadget | one pair per rendered row | 0 |
| "Overwriting binding" from our QML | 72 | 0 |
| **Any** `org.biglinux.appsmenu` message | many | **none** |

## Honest limits

* No pointer or touch input was exercised anywhere: Wayland blocks synthetic
  input and `spectacle` core-dumps on this VM. Logic was driven through the
  same functions the handlers call. Drag and drop is untestable by any
  injection tool, by upstream design.
* Fractional/HiDPI scaling and other resolutions were not tested.
* Live-score notifications were not observed firing on a real goal.
* Klipper **ignores images by default**, so the Gallery-quality image path in
  the clipboard is dead for most users until they enable it in Klipper.
* TheSportsDB's free tier returns one upcoming fixture per league, and no live
  feed for motorsport.
* `qmllint` is necessary but not sufficient: it accepted a file with two `id`
  declarations in one object. Only loading it in the engine caught that.

## VM state

Returned to how it was found: session back on Wayland, `/etc/sddm.conf.d/`
holding only its original `kde_settings.conf`, no probe left in the deployed
package, no test host left in any provider, gadget settings back to defaults,
the temporarily-attached test disk detached with no persistent change to the
domain, `klipperrc` removed (it did not exist before), and all scratch files
deleted. No credential was written to any file, commit, log or document.
