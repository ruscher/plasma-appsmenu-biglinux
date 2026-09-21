# Places · 01 — Current state audit

Development notes. Nothing here is needed at runtime.

Environment: BigLinux, Plasma **6.7.4**, KF **6.29**, Qt 6, Wayland, pt_BR.

## What Places is today

`FullRepresentation.qml` renders Places as two lists side by side: a category
sidebar (a hand-written `ListModel` of three rows) and a content list whose
model is chosen by index.

```qml
model: {
    switch (categorySidebar.currentIndex) {
        case 0: return kickoff.computerModel      // Computer
        case 1: return kickoff.recentUsageModel   // History
        case 2: return kickoff.frequentUsageModel // Frequently Used
        default: return null
    }
}
```

So the whole feature is three model assignments. There is no Places-specific
component, delegate or page file.

## Models in play

Declared in `main.qml`:

| Property | Type | Configuration | Used by |
| --- | --- | --- | --- |
| `computerModel` | `Kicker.ComputerModel` | `systemApplications` from config | Places → Computer |
| `recentUsageModel` | `Kicker.RecentUsageModel` | `shownItems = 1` (OnlyApps) | Home "Recent Apps" **and** Places → History |
| `frequentUsageModel` | `Kicker.RecentUsageModel` | `ordering = 1` (Popular) | Home "Frequent" **and** Places → Frequently Used |
| `recentDocsModel` | `Kicker.RecentUsageModel` | `shownItems = 2` (OnlyDocs) | Home only |
| `recentFoldersModel` | `Kicker.RecentUsageModel` | `shownItems = 3` (OnlyFolders) | Home only |

## Problems found

1. **Wrong default.** The sidebar opens on index 0 = Computer. The brief wants
   Frequently Used to be the first thing the user sees.

2. **"History" is apps-only, and silently so.** It reuses `recentUsageModel`,
   which is `shownItems = OnlyApps`. A category called "History" that never
   shows a file or a folder is misleading — and the models that *do* hold
   recent files and folders (`recentDocsModel`, `recentFoldersModel`) exist
   already but are only wired into Home.

3. **Frequently Used is a flat mixed list.** `frequentUsageModel` is
   `AppsAndDocs`, so apps and documents interleave with no grouping and folders
   never appear at all.

4. **No devices.** `ComputerModel` does carry places and removable devices, but
   it filters out fixed drives, exposes no capacity, no mounted state and no
   mount/unmount actions — so internal disks and any device management are
   simply absent.

5. **No empty state.** With the activity history switched off every category is
   a blank list with no explanation and no way to fix it, even though
   `components/RecentActivityTracking.qml` already exists and can both detect
   and enable it.

6. **Category list is a hand-maintained `ListModel`** with `setProperty()` calls
   in `Component.onCompleted` to translate the strings — awkward, and it makes
   adding categories more error-prone than it needs to be.

## What `ComputerModel` actually gives us

Reading `plasma-workspace/applets/kicker/computermodel.cpp` (v6.7.4) rather
than guessing: it is a `QConcatenateTablesProxyModel` over

1. `RunCommandModel` — the "Run Command" row,
2. `SimpleFavoritesModel` — the configured system applications,
3. `FilteredPlacesModel` — a `QSortFilterProxyModel` over **`KFilePlacesModel`**.

This matters a lot, because it means **KFilePlacesModel and Solid already reach
QML through Kicker**, with no plugin of our own:

- `GroupRole` returns `KFilePlacesModel::GroupRole` for places and
  `i18n("Applications")` for apps — which is why Computer *already* renders
  "Aplicativos / Locais / Remoto" section headings through
  `AccessibleListView`'s existing `section.property: "group"`.
- `trigger()` opens the URL, and for an unmounted device calls
  `Solid::StorageAccess::setup()` and opens it when setup finishes — the
  click-to-mount-then-open flow already exists.

Its limits are equally concrete:

```cpp
return !m_placesModel->isHidden(index)
    && !m_placesModel->data(index, KFilePlacesModel::FixedDeviceRole).toBool();
```

Fixed (internal) devices are filtered out. And `ComputerModel::data()` returns
`{}` for every role it does not special-case, so there is **no** ActionList,
no capacity, no mounted state. `onSetupDone` also returns silently on error, so
a failed mount produces no feedback.

## What `RecentUsageModel` actually gives us

From `recentusagemodel.cpp`:

```cpp
auto query = UsedResources
    | (m_ordering == Recent ? RecentlyUsedFirst : HighScoredFirst)
    | Agent::any()
    | (m_usage == OnlyDocs ? Type::files()
       : (m_usage == OnlyFolders) ? Type::directories() : Type::any())
    | Activity::current();
```

Three things follow, and they shape the whole design:

- `ordering: Popular` is **`HighScoredFirst`** — KDE's real frequency score.
  There is no need to invent a ranking formula.
- The query is already scoped to `Activity::current()`, so the
  "activity-aware ranking" the brief asks about is **already the behaviour**.
- `shownItems` cleanly separates apps / files / folders.

So "frequently used files" is simply `shownItems: OnlyDocs, ordering: Popular`.
Nothing new is required to get it.

## RecentActivityTracking

`components/RecentActivityTracking.qml` exposes `tracking`, `busy`, `enable()`
and `openSettings()`. Places should reuse exactly that API for its empty state
rather than re-deriving the state, so it keeps working unchanged when the
separate recent-files branch improves the detection behind it.

## Opportunities for reuse

| Need | Already available |
| --- | --- |
| Frequency ranking | `RecentUsageModel(ordering: Popular)` — `HighScoredFirst` |
| Activity awareness | built into that query |
| Per-type separation | `shownItems` |
| Places / Network grouping | `ComputerModel` + `GroupRole` + existing section delegate |
| Click-to-mount | `ComputerModel.trigger()` |
| History on/off + enable | `RecentActivityTracking` |
| Section headings | `AccessibleListView`'s `section.property: "group"` |
| App context actions | existing `AppDelegate` / `ActionMenu` |

The gap that genuinely needs new code is **devices**: fixed drives, capacity,
mounted state and mount/unmount. See
[places-02-kde-research.md](places-02-kde-research.md).
