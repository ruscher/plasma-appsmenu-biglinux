# Places · 06 — Histories

Development notes. Nothing here is needed at runtime.

## The problem this fixes

There was one category called "History", and it was wired to
`kickoff.recentUsageModel` — which is `shownItems: OnlyApps`. A category named
"History" that could never show a file or a folder, while the models holding
recent files and folders already existed and were only used by the Home page.

## Now

| Category | Model | `shownItems` | `ordering` |
| --- | --- | --- | --- |
| History Apps | `kickoff.recentUsageModel` | OnlyApps | Recent |
| History Files | `kickoff.recentDocsModel` | OnlyDocs | Recent |
| History Folders | `kickoff.recentFoldersModel` | OnlyFolders | Recent |

The separation is enforced by the model, not by filtering in QML: upstream
builds the query with `Type::files()` or `Type::directories()`, so a file can
never appear under Folders and vice versa.

No new models were needed — all three already existed for Home and were simply
not reachable from Places.

## Rows

The same `Components.AccessibleListView` + `Delegates.AppDelegate` used
everywhere else, so activation, drag and drop and context menus are unchanged.
Files and folders show their friendly relative path as the subtitle.

## Empty states

Each category says what is missing, with a matching icon
(`applications-all`, `document-open-recent`, `folder-open-recent`) via the
`emptyIconName` property added to `AccessibleListView`:

```
No recently used applications yet
No recently used files yet
No recently used folders yet
```

When the activity history is switched off entirely, the page shows the
actionable "Recent activity is turned off" state with **Turn On** instead —
the three per-category messages would be misleading there, since nothing will
ever appear until tracking is enabled.

## Temporal grouping — considered, not implemented

The brief asks for Today / Yesterday / Earlier this week grouping *if the model
provides trustworthy timestamps*. It does not: `RecentUsageModel::data()`
exposes Display, Decoration, Description, FavoriteId, Url, Group,
HasActionList and ActionList — there is no timestamp role reaching QML. The
underlying `KActivities::Stats` result has one, but it is not forwarded.

Inventing dates from file mtimes would be wrong: mtime is when the file was
last *written*, not when the user last opened it, which is what this list is
about. So no grouping was added. Doing it properly would mean exposing the
resource's `lastUpdate` through Kicker, which is an upstream change.

## Forget this item

Not implemented, and deliberately so. `KActivities::Stats::ResultModel` does
provide `forgetResource()`, and the `recentlyused` KIO worker links against it
— but `RunnerMatchesModel`/`RecentUsageModel` do not expose it to QML, and the
brief is explicit that the SQLite database must never be touched directly.
Clearing history therefore stays with System Settings, reachable from the
empty state's **Activity History Settings** button.
