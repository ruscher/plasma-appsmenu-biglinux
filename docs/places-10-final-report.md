# Places · 10 — Final report

Development notes. Nothing here is needed at runtime.

# Summary

Places was three model assignments behind a three-row sidebar: Computer,
"History" (which was silently applications-only), and a flat mixed Frequently
Used. It is now an activity hub with five categories, Frequently Used first,
built entirely on KDE's own data.

The most useful outcome of the research phase was how little needed inventing.
`RecentUsageModel(ordering: Popular)` already *is* the activity manager's
`HighScoredFirst` score, already scoped to `Activity::current()` — so no ranking
formula was written and Places ranks things exactly as the rest of Plasma does.
`ComputerModel` already wraps `KFilePlacesModel` and already reports
Applications / Places / Remote groups. The one genuine gap — internal drives,
capacity, mounted state, mount/unmount — was filled with Plasma's own Solid data
engines rather than a plugin or a shell.

# Architecture

```
Places
├── Frequently Used   RecentUsageModel(OnlyApps|OnlyFolders|OnlyDocs, Popular)
├── Computer          ComputerModel (KFilePlacesModel) + Solid devices
├── History Apps      RecentUsageModel(OnlyApps,    Recent)
├── History Files     RecentUsageModel(OnlyDocs,    Recent)
└── History Folders   RecentUsageModel(OnlyFolders, Recent)
```

Details in [places-03-architecture.md](places-03-architecture.md).

# Files changed

| File | Change |
| --- | --- |
| `contents/ui/FullRepresentation.qml` | the inline Places block (~3.5 KB) replaced by `PlacesPage {}` |
| `contents/ui/main.qml` | three frequent-by-type models |
| `contents/ui/components/AccessibleListView.qml` | `emptyIconName` so empty states pick their icon |

# Files added

| File | Role |
| --- | --- |
| `contents/ui/PlacesPage.qml` | the whole page: sidebar, three content views, empty state |
| `contents/ui/components/ActivitySection.qml` | one titled block of a Kicker model, reused three times |
| `contents/ui/components/DeviceSection.qml` | storage devices from Solid |
| `docs/places-01` … `places-10` | this documentation |

# Features implemented

* Frequently Used as the entry point, split into Applications / Folders / Files
  with real frequency ranking and friendly relative paths.
* History split into Apps, Files and Folders — enforced by the model's own type
  filter, not by filtering in QML.
* Computer keeps its Applications / Places / Remote groups and gains a Devices
  section listing **internal fixed drives**, which `ComputerModel` filters out.
* Device rows show Solid's icon, mounted state, and capacity as a bar plus
  pre-localised free/total text; Unmount or Eject appears only where Solid says
  it applies.
* Clicking an unmounted device mounts it through Solid and opens it when ready.
* An actionable empty state when the activity history is off, wired to the
  existing `RecentActivityTracking`.
* Keyboard navigation across the whole page, hopping between sections and
  skipping empty ones.

# Bugs fixed

* **"History" was applications-only.** The category name promised files and
  folders that the model could never return. Now three explicit categories.
* **Frequently Used showed no folders.** It used the combined apps+docs model.
* **Places opened on Computer**, not on what the user actually uses.
* **A selection that would not stick** — found only by instrumenting the page:
  `AccessibleListView`'s inner `currentIndex: count > 0 ? 0 : -1` re-asserting
  itself on an unrelated relayout, *and* a category reset firing on a spurious
  `kickoff.expandedChanged`. Both fixed at the cause.

# Performance improvements

No timers and no external processes anywhere on this page (verified: `Timer`
count 0 in all three new files). Everything updates from model and data-engine
signals. The device list rebuilds only when the set of UDIs changes, so routine
free-space updates do not recreate delegates. Models live on the plasmoid, not
the page, so opening Places builds delegates rather than queries.

# UX/UI improvements

One line per item, small dimmed section headings with discreet counts, no
cards, no per-item thumbnails. Capacity is a thin bar rather than a wall of
numbers, and turns to the negative colour above 90 %. Every icon name was
verified present in both Breeze and the BigLinux theme before use. Details in
[places-07](places-07-ux-ui-accessibility.md).

# Accessibility

Sections are `Accessible.Grouping` with heading labels; device rows announce
their state in words rather than relying on a dimmed icon; the Unmount/Eject
button's accessible name changes with the operation that actually applies; the
**Turn On** button explains what it enables. Full keyboard navigation with
section hopping that skips empty sections.

# KDE APIs used

| API | Via |
| --- | --- |
| KActivities / PlasmaActivitiesStats | `Kicker.RecentUsageModel` (`HighScoredFirst`, `Activity::current()`) |
| KFilePlacesModel | `Kicker.ComputerModel` |
| Solid | `hotplug` + `soliddevice` data engines and the latter's service |
| KIO | `model.trigger()` and `Qt.openUrlExternally` — never a constructed command line |
| KRunner | untouched; the search continues to work across the change |

# Tests performed

Full matrix in [places-09-tests.md](places-09-tests.md). Headlines: the
regression sweep drove Home → Apps → Places → Info → search → Places → search →
same-tab Places → Home with `busy=false` and **zero** plasmoid warnings; the
device filter was verified against the live machine (6 hotplug sources → 5
storage volumes shown, camera skipped, real capacities); category switching was
verified to hold over 10+ samples after the two ownership bugs were fixed.

# Known limitations

* **Eject is carried out as unmount.** `soliddevice.operations` offers
  `mount`, `unmount` and `updateFreespace`; a true tray eject would need the
  `hotplug` engine's `invokeAction` with a Solid predicate.
* **Mount errors are silent.** A failed mount leaves the device unmounted with
  no explanation. Worth fixing next.
* **No device context menu** — mount/unmount is a row button.
* **No temporal grouping in the histories.** `RecentUsageModel` exposes no
  timestamp role to QML, and using file mtimes would answer a different
  question than "when did you last open this".
* **No "Forget this item".** `ResultModel::forgetResources()` exists upstream
  but is not exposed through Kicker, and the brief rightly forbids touching the
  SQLite database directly.
* **No Global Shortcuts section.** KGlobalAccel exposes no usage data at all,
  so any "frequently used shortcuts" ranking would be invented. Reasoned out in
  [places-02](places-02-kde-research.md).
* Hotplug, mount, unmount and the history-off empty state were **not tested
  live** — no removable device was available, and neither unmounting a system
  volume nor wiping the user's real activity statistics was acceptable on their
  working desktop.

# Future improvements

1. Surface mount failures — the service already returns a result.
2. Real eject via `hotplug`'s `invokeAction`.
3. Ask upstream Kicker to expose the resource timestamp and `forgetResource()`;
   both unlock features the brief wanted (temporal grouping, "Forget this
   item") and neither can be done correctly without them.
4. Verify hotplug and mount/unmount on a machine with a spare removable device.
5. A frame-time profile if any stutter is ever reported; none was observed, but
   nothing was measured with a stopwatch either.
