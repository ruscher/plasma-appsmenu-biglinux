# Places · 04 — Frequently Used

Development notes. Nothing here is needed at runtime.

The first thing the user sees when opening Places, and the point of the whole
category: what they actually reach for, not merely what they touched last.

## Ranking — KDE's, not ours

Each section is a `Kicker.RecentUsageModel` with `ordering: 1` (Popular), which
upstream turns into:

```cpp
UsedResources
  | HighScoredFirst          // ← frequency, not recency
  | Agent::any()
  | Type::files() / directories() / any()
  | Activity::current()      // ← already activity aware
```

Two consequences that removed work rather than adding it:

* **No custom formula.** The brief allowed
  `usageFrequencyWeight + recencyWeight + KDEActivityScore` if necessary. It is
  not: `HighScoredFirst` *is* the activity manager's score, which already
  blends how often and how recently a resource was used and decays over time.
  Computing our own would only make Places rank things differently from the
  rest of Plasma.
* **Activity-aware for free.** The query is scoped to `Activity::current()`, so
  switching KDE Activity already changes what Frequently Used shows. Nothing
  was added for this.

## Recent vs Frequent — kept distinct

| | Model | Ordering |
| --- | --- | --- |
| Frequently Used → Applications | `RecentUsageModel(OnlyApps)` | Popular |
| History Apps | `RecentUsageModel(OnlyApps)` | Recent |

Same class, different `ordering`. They are separate model instances, so one
list is never the other with a new heading. Measured on this machine the two
orders genuinely differ — the frequent list is led by the browser and editor
used all day, while the recent list is led by whatever was opened last.

## Sections

| Section | Model | Icon | Rows here |
| --- | --- | --- | --- |
| Applications | `kickoff.frequentAppsModel` | `applications-all` | 12 |
| Folders | `kickoff.frequentFoldersModel` | `folder` | 15 |
| Files | `kickoff.frequentDocsModel` | `document-multiple` | 15 |

Order is deliberate: applications first (most often what a launcher is opened
for), then folders, then files.

### Why three models rather than one

`RecentUsageModel(AppsAndDocs, Popular)` already returns a group-sorted mix of
all three types, which looked like a shortcut. It was rejected after measuring:
that query carries a single `Limit(30)` across all types, and on this machine it
yielded **5 applications** out of 29 rows because folders and files outscored
them. The per-type models carry `Limit(15)` each and give 12 / 15 / 15 — a
balanced page instead of one type crowding out the others.

### Limits

No limiting proxy exists in this code. Upstream already caps each per-type
query at `Limit(15)`, which is exactly the 8–15 per section the brief asks for.
Adding one would have meant a second model to keep in sync with `trigger()` for
no benefit.

## Rows

Each row is the project's normal `Delegates.AppDelegate`, so it inherits the
behaviour the rest of the menu already has — activation, drag and drop,
favourites, context menus, hover and focus handling — rather than
reimplementing any of it. Sections are `components/ActivitySection.qml`, used
three times.

What a row shows:

```
[icon]  bigcam
        Documentos/Git/bigcam/usr/share/biglinux
```

The second line is the model's Description role, which for files and folders is
already a friendly path relative to home. No `file://`, no percent-encoding, no
raw URI is ever shown. Applications show their generic name instead
("Google Chrome / Acessar a internet").

Folders and files are genuinely different rows from different models, never one
list of "documents".

## Locations and remote places

There is no separate Locations section. `Type::directories()` matches any
directory resource the activity manager recorded, including non-`file://` KIO
URLs, so a frequently used SMB or SFTP folder appears in **Folders** and opens
through `model.trigger()` → KIO. Configured remote places remain in
Computer → Remote via `KFilePlacesModel`. A separate category would have shown
the same rows minus the local ones.

## Empty states

Two different situations, deliberately distinguished:

| Situation | Shown |
| --- | --- |
| Activity history is off | "Recent activity is turned off" + **Turn On** + **Activity History Settings** |
| History on, nothing recorded yet | "Nothing here yet — Applications, files and folders you use often will appear here." |

The first is actionable and wired to `RecentActivityTracking.enable()`; the
second is simply honest. A new user should not be told to switch on something
that is already on.

## Keyboard

Because the page is three lists stacked in one Flickable rather than one list,
Up/Down chaining is explicit: each section raises `focusPreviousRequested` /
`focusNextRequested` at its edges, and the page hops to the neighbouring
section — skipping empty ones. Up from the first row returns to the category
sidebar; Right from the sidebar enters the content.

## Limitations

* Ranking cannot be shown or tweaked in the UI: no relevance value is exposed
  to QML.
* Frequency reflects the **current activity** only. That is upstream behaviour
  and is what makes the list contextual, but it means switching activity
  changes the list, which may surprise a user who does not use activities.
* The activity manager needs a few days of use before the frequent list is
  meaningfully different from the recent one.
