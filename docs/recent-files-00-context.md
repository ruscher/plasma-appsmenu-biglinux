# Recent Files & Locations — 00 · Context

Development notes. Nothing here is needed at runtime: the plasmoid works the
same whether or not `docs/` is installed by the package.

## The problem as reported

In `plasma-appsmenu-biglinux`, everything fed by the KDE activity history was
dead: Recent Apps, Recent Files, Recent Folders, Frequently Used, and
Places > History. The Home page showed a call to action —

> Recent files and locations are turned off — **Turn on recent files**

— and clicking it appeared to do nothing. Worse, on some machines the button
*disappeared* while the lists stayed empty, so the menu claimed the feature was
on while it plainly was not.

`balooctl6 status` reported Baloo enabled, which was taken as evidence that the
feature should work. It is not evidence of anything (see
[02-root-cause](recent-files-02-root-cause.md)).

## The two projects involved

| Project | Role |
| --- | --- |
| [`plasma-appsmenu-biglinux`](https://github.com/ruscher/plasma-appsmenu-biglinux) | The menu. Reads the state, shows the call to action, offers "Turn on". |
| [`biglinux-settings`](https://github.com/ruscher/biglinux-settings) | The **Recent Files & Locations** switch under *Usability*. |

They each had their own idea of what "enabled" means, and the two definitions
did not agree — the heart of the inconsistency users saw.

## The architecture that actually matters

```
an application opens a file / folder, or the menu launches an app
        │
        ▼
KActivities ResourceInstance ─ D-Bus ─▶ org.kde.ActivityManager.Resources
                                              .RegisterResourceEvent
        │
        ▼
kactivitymanagerd · StatsPlugin::acceptedEvent()   ◀── THE GATE
        │                                               what-to-remember
        │                                               off-the-record-activities
        │                                               url-filters
        ▼
~/.local/share/kactivitymanagerd/resources/database  (sqlite)
        │  ResourceEvent / ResourceScoreCache
        ▼
libPlasmaActivitiesStats  (KActivities::Stats::ResultModel)
        │
        ├──▶ Kicker RecentUsageModel ──▶ the menu
        │       OnlyApps / OnlyDocs / OnlyFolders / ordering=Popular
        │       → Recent Apps, Recent Files, Recent Folders,
        │         Frequently Used, Places > History
        │
        └──▶ kio "recentlyused" worker ──▶ Dolphin
                recentlyused:/files, recentlyused:/locations
                → Recent Files, Recent Locations
```

A second, independent subsystem covers the XDG recent-documents list:

```
KRecentDocument  ──  kdeglobals [RecentDocuments] UseRecent
        │
        ▼
~/.local/share/recently-used.xbel   (file dialogs, GTK apps)
```

**Baloo appears nowhere in either path.** It indexes file *content* for search.

## Files that matter

`plasma-appsmenu-biglinux`

- `contents/tools/recent-activity` — new. The single source of truth.
- `contents/ui/components/RecentActivityTracking.qml` — reads that state, offers `enable()`.
- `contents/ui/HomePage.qml` — the call to action and the recent sections.
- `contents/ui/FullRepresentation.qml` — Places > History / Frequently Used.
- `contents/ui/main.qml` — where the four `RecentUsageModel`s are declared.

`biglinux-settings`

- `usability/recentActivity.sh` — new. Byte-identical copy of the helper above.
- `usability/recentFiles.sh` — the `check` / `toggle` entry point.
- `usability/recentFilesRun.sh` — applies the change.
- `usability_page.py` — builds the switch row (unchanged).

## Expected behaviour

1. The menu reports the feature off **only** when it really is off.
2. "Turn on recent files" turns on everything needed, verifies it, and updates
   the UI without a logout — or reports a failure and keeps the button.
3. The settings switch and the menu always agree.
4. Turning the feature off, then on again, does not destroy the user's history.
