# Places · 03 — Architecture

Development notes. Nothing here is needed at runtime.

## Shape

```
Places  (contents/ui/PlacesPage.qml)
│
├── Frequently Used        ← default entry point
│   ├── Applications       Kicker.RecentUsageModel(OnlyApps,    Popular)
│   ├── Folders            Kicker.RecentUsageModel(OnlyFolders, Popular)
│   └── Files              Kicker.RecentUsageModel(OnlyDocs,    Popular)
│
├── Computer
│   ├── Applications ┐
│   ├── Places       ├─ Kicker.ComputerModel  (wraps KFilePlacesModel)
│   ├── Remote       ┘    section headings from its `group` role
│   └── Devices          Solid via the hotplug + soliddevice data engines
│
├── History Apps           Kicker.RecentUsageModel(OnlyApps,    Recent)
├── History Files          Kicker.RecentUsageModel(OnlyDocs,    Recent)
└── History Folders        Kicker.RecentUsageModel(OnlyFolders, Recent)
```

## Where every value comes from

| Shown | Source | Notes |
| --- | --- | --- |
| Frequent apps/files/folders | `RecentUsageModel`, `ordering: Popular` | `HighScoredFirst`, scoped to `Activity::current()` |
| Recent apps/files/folders | `RecentUsageModel`, `ordering: Recent` | `RecentlyUsedFirst`, same activity scoping |
| Item name / icon / subtitle | the model's Display, Decoration and Description roles | the subtitle is already a friendly relative path (`Documentos/Git/bigcam`), never a URI |
| Opening an item | `model.trigger(index, "", null)` | keeps KIO's handling of remote URLs |
| System apps, user places, network | `ComputerModel` | |
| Computer section headings | `ComputerModel`'s `group` role | `KFilePlacesModel::GroupRole`, already translated |
| Device list | `hotplug` engine sources | event driven |
| Device label / icon / capacity / mounted | `soliddevice` engine keys | `Label`, `Icon`, `Size`, `Free Space`, `Accessible` |
| Mount / unmount | `soliddevice` service operations | |
| History on/off, Turn On | `components/RecentActivityTracking.qml` | reused unchanged |

Nothing is hard-coded, simulated or mocked, and no new statistics are computed.

## Files

| File | Role |
| --- | --- |
| `PlacesPage.qml` | **new** — the whole page: sidebar, the three content views, empty state |
| `components/ActivitySection.qml` | **new** — one titled block of a Kicker model, reused three times |
| `components/DeviceSection.qml` | **new** — storage devices from Solid |
| `main.qml` | three new frequent-by-type models |
| `FullRepresentation.qml` | the inline Places block replaced by `PlacesPage {}` |
| `components/AccessibleListView.qml` | gained `emptyIconName` so empty states can pick their icon |

`FullRepresentation.qml` shrank by ~3.5 KB: the page moved out whole, which
keeps the file that owns the StackView small and reduces the chance of
disturbing the transition guards that exist there.

## Two ownership decisions worth keeping

**The category selection lives on `PlacesPage`, not in the sidebar view.**
`AccessibleListView`'s inner ListView carries `currentIndex: count > 0 ? 0 : -1`
and re-asserts it at moments outside our control — it was observed snapping the
selection back to Frequently Used *seconds* after a category was chosen, when an
unrelated relayout (the device list filling in) re-evaluated that binding. The
sidebar is therefore a plain `ListView` whose `currentIndex` simply follows
`PlacesPage.currentCategory`. This sidebar needs nothing that
`AccessibleListView` adds: five rows, no sections, no empty state.

**The category is not reset on `kickoff.expandedChanged`.**
`FullRepresentation` replaces the stack item every time Places is opened, so a
fresh `PlacesPage` is built with `currentCategory` already at Frequently Used —
that alone satisfies "Frequently Used is the entry point". An additional reset
on `expandedChanged` was actively harmful: `expanded` was observed re-firing
`true` while the menu was already open, throwing the user back to Frequently
Used mid-session.

## Update model — no polling

| Data | Updates because |
| --- | --- |
| Frequent / recent | the Kicker models are live on the activity manager |
| Places / network | `KFilePlacesModel` is live |
| Devices appearing/disappearing | `hotplug` engine `sourcesChanged` |
| Capacity, mounted state | `soliddevice` engine `dataChanged` |
| History on/off | `RecentActivityTracking.refresh()` on menu open |

There is no `Timer` driving any of it, and no shell command anywhere on this
page.

## Rejected, with reasons

| Idea | Why not |
| --- | --- |
| Global Shortcuts section | KGlobalAccel exposes no usage data at all, so a "frequently used shortcuts" list would be invented ranking. Full reasoning in [places-02](places-02-kde-research.md). |
| Separate "Recent Locations" | `RecentUsageModel(OnlyFolders)` already returns non-`file://` directory resources; a separate category would show the same rows minus the local ones. |
| A "Continue" strip at the top | It would duplicate what the Home page already is, on a page whose job is exploration. Skipped rather than added for its own sake. |
| A custom `score = frequency + recency + activity` ranking | `HighScoredFirst` already is KDE's score, already activity-scoped. Re-ranking would only make Places disagree with the rest of Plasma. |
| A C++ plugin | Nothing essential turned out to be missing from QML. It would also turn a pure-QML `arch=any` package into a compiled one. |
