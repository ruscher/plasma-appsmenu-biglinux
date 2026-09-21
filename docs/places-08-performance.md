# Places · 08 — Performance

Development notes. Nothing here is needed at runtime.

## The rule this page follows

Nothing on this page polls. Every value arrives because a model or a data
engine pushed it.

| Data | Update mechanism |
| --- | --- |
| Frequent / recent items | Kicker models, live on the activity manager |
| Places, network | `KFilePlacesModel`, live |
| Device set | `hotplug` engine `sourcesChanged` |
| Device capacity / mounted | `soliddevice` engine `dataChanged` |
| History on/off | `RecentActivityTracking.refresh()`, on menu open |

`grep -c "Timer" PlacesPage.qml components/ActivitySection.qml
components/DeviceSection.qml` → **0**. There is no timer, and no external
process is spawned anywhere on this page — no shell, no `lsblk`, no
`udisksctl`, no `qdbus`.

## Cost of opening Places

The models are **not** created when Places opens. `main.qml` declares them as
plasmoid-level properties, so they exist for the life of the applet and are
shared with the Home page. Opening Places builds delegates, not queries.

Row counts actually rendered on this machine:

| View | Rows |
| --- | --- |
| Frequently Used | 12 + 15 + 15 = 42 across three sections |
| Computer | 14 + 5 devices |
| History Apps / Files / Folders | ≤ 15 each |

Well inside the 8–15 per section the brief asks for, and bounded by upstream's
own `Limit(15)` — there is no query that could return hundreds of rows.

## Delegate creation

* `ActivitySection`'s lists use `reuseItems: true`.
* All content lists are `interactive: false` with
  `Layout.preferredHeight: contentHeight`, sitting inside one Flickable per
  category. The page scrolls as a single surface instead of trapping the wheel
  in whichever list the pointer is over.
* Only the visible category's view is `visible`/`enabled`; the others are
  hidden, so their delegates are not laid out.
* The device list rebuilds its `ListModel` **only when the set of UDIs
  changes** — a routine free-space update leaves every delegate in place. This
  was deliberate: the naive version recreated all rows on every `dataChanged`.

## Measured behaviour

| Check | Result |
| --- | --- |
| External processes spawned by Places | 0 |
| Timers | 0 |
| plasmashell warnings from the plasmoid | none |
| Binding loops | none reported |
| Crashes across ~12 plasmashell restarts during development | none |
| Device list rebuild on capacity change | skipped (set unchanged) |

## One real bug this area produced

An early version created `SoftwareSearch`-style per-page models and reset the
category on `kickoff.expandedChanged`. Instrumenting the page showed `expanded`
re-firing `true` while the menu was already open, which reset the user's
category mid-session. The reset was removed entirely — a fresh `PlacesPage` is
built on every visit anyway, so it was redundant as well as harmful. Cheaper
and correct.

## Not measured

No frame-time or CPU profiling was run. The claims above are structural (no
timers, no processes, bounded row counts, shared models) plus observed absence
of warnings, not stopwatch numbers. A proper profile with
`QSG_RENDER_TIMING` would be the next step if a stutter is ever reported.
