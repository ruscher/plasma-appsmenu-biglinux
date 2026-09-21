# Recent Files & Locations — 02 · Root cause

Every claim here is backed either by a controlled experiment on the test VM or
by the kactivitymanagerd v6.7.4 sources, quoted inline.

## Summary

The current activity was listed in `off-the-record-activities`, so
kactivitymanagerd discarded **every** resource event before it reached the
database. Neither project ever checked that key. The menu checked two other
keys, found them satisfactory, hid its "Turn on" button and displayed empty
models; the settings switch checked a third set of keys that nothing in KF 6
reads, and reported the opposite. Baloo was never part of the picture.

## 1. The gate, in upstream source

`kactivitymanagerd/src/service/plugins/sqlite/StatsPlugin.cpp`, v6.7.4:

```cpp
bool StatsPlugin::acceptedEvent(const Event &event)
{
    return !(
        // If the URI is empty, we do not want to process it
        event.uri.isEmpty() ||

        // Skip if the current activity is OTR
        m_otrActivities.contains(currentActivity()) ||

        // Exclude URIs that match the ignored patterns
        any_of(m_urlFilters.cbegin(), m_urlFilters.cend(), ...) ||

        (m_whatToRemember == SpecificApplications
         && m_blockedByDefault != boost::binary_search(m_apps, event.application)));
}
```

and the configuration it reads (`loadConfiguration()`):

```cpp
m_blockedByDefault = conf.readEntry("blocked-by-default", false);
m_whatToRemember   = (WhatToRemember)conf.readEntry("what-to-remember", (int)AllApplications);
...
m_otrActivities    = conf.readEntry("off-the-record-activities", QStringList());
```

`off-the-record-activities` containing the current activity is a hard stop, on
equal footing with "do not remember". Nothing downstream can compensate.

## 2. The controlled experiment

Identical configuration in both runs except the one key. Events were injected
through the same D-Bus entry point applications use.

**A — activity off-the-record (state as found):**

```
off-the-record   = 82dd571b-…      enabled = true      what-to-remember = 0
ResourceEvent BEFORE: 0
  → RegisterResourceEvent × 3
ResourceEvent AFTER : 0            ScoreCache AFTER: 0
```

**B — same machine, key removed, daemon restarted:**

```
off-the-record   = ''              enabled = true      what-to-remember = 0
ResourceEvent BEFORE: 0
  → RegisterResourceEvent × 3
ResourceEvent AFTER : 3

kwrite  /home/ruscher/Documents/biglinux-recent-test-01.txt  2026-09-21 12:39:42
kwrite  /home/ruscher/Documents/biglinux-recent-test-02.txt  2026-09-21 12:39:42
kwrite  /home/ruscher/Downloads/biglinux-recent-test-03.txt  2026-09-21 12:39:42
```

One key, nothing else. That is the root cause.

Confirmed again with real applications rather than injected events: launching
`kwrite` on a file and `dolphin` on a folder produced

```
org.kde.kwrite   /home/ruscher/Downloads/biglinux-recent-test-03.txt
org.kde.dolphin  /home/ruscher/biglinux-recent-testdir
org.kde.kwrite   /home/ruscher/Documents/biglinux-recent-test-01.txt
```

## 3. Why the button disappeared

The old `RecentActivityTracking.qml`:

```js
root.tracking = enabled && root.whatToRemember !== 2
```

With `enabled=true` and `what-to-remember=0` this is `true`, so the call to
action was hidden. Its `enable()` wrote exactly those same two keys — so
clicking "Turn on" *guaranteed* the button would vanish on the next refresh,
whether or not anything had been fixed. The user saw the button disappear and
the lists stay empty. That is the reported symptom, exactly.

## 4. `enabled` is a no-op on Plasma 6

Both projects treated `kactivitymanagerd-pluginsrc`'s `enabled` key as the
master switch. It is not. `Application::loadPlugins()`:

```cpp
const auto offers = KPluginMetaData::findPlugins(
    QStringLiteral(KAMD_PLUGIN_DIR), {}, KPluginMetaData::AllowEmptyMetaData);
for (const auto &offer : offers) {
    d->loadPlugin(offer);          // no configuration check anywhere
}
```

There is no filter callback and no config lookup; `StatsPlugin` never reads
`enabled` either. Verified on the VM:

```
enabled = false  → restart daemon → RegisterResourceEvent
ResourceEvent: 3 -> 4      >>> RECORDED anyway: 'enabled=false' is a NO-OP <<<
```

The legacy `kactivitymanagerdrc [Plugins] …ResourceScoringEnabled=false` on this
machine is equally inert, for the same reason.

The key is still written (both BigLinux tools and System Settings surface it)
and a literal `false` is still honoured for display, so the two projects agree
with what the user last asked for — but it is never the thing that makes the
feature work.

## 5. `kioslaverc [recentlyused]` has no consumer

`recentFiles.sh` gated the switch on `FilesEnabled`, and `recentFilesRun.sh`
wrote `FilesEnabled` / `LocationsEnabled` / `MaxItems`. Nothing reads them:

```
$ grep -rl "LocationsEnabled" /usr/lib /usr/lib/qt6/plugins
(no results)

$ grep -rl "FilesEnabled" /usr/lib /usr/lib/qt6/plugins
/usr/lib/libdolphinprivate.so…      → UnderlineFilesEnabled, setTabsForFilesEnabled
/usr/lib/libkonsoleprivate.so…      → UnderlineFilesEnabled
/usr/lib/libgtk-4.so…               → unrelated
```

Only unrelated symbols that happen to contain the substring. The
`recentlyused` KIO worker itself contains no such string at all:

```
$ strings /usr/lib/qt6/plugins/kf6/kio/recentlyused.so | grep -iE 'FilesEnabled|kioslaverc'
(nothing)
```

Requiring `FilesEnabled == "true"` therefore made the settings switch read OFF
on every default installation, where `~/.config/kioslaverc` does not even exist.

## 6. What Dolphin's Recent Files actually uses

The same activity database — not `recently-used.xbel`, not `kioslaverc`:

```
$ ldd /usr/lib/qt6/plugins/kf6/kio/recentlyused.so | grep -i activ
  libPlasmaActivitiesStats.so.1
  libPlasmaActivities.so.7

$ strings … | grep KActivities
  KActivities::Stats::ResultModel::ResultModel(Query, QObject*)
  KActivities::Stats::Query::setOrdering(Terms::Order)
  …
```

So one fix covers Dolphin's *Recent Files* and *Recent Locations* as well as
every list in the menu.

## 7. Why `balooctl6 enable` was never the answer

Baloo indexes file **content** for search. It is absent from the entire path:

```
$ ldd …/kicker/libkickerplugin.so | grep -i baloo   → nothing
$ ldd …/kio/recentlyused.so       | grep -i baloo   → nothing
$ ldd /usr/lib/libPlasmaActivitiesStats.so.1 | grep -i baloo → nothing
```

Empirically, with Baloo fully disabled:

```
$ balooctl6 disable
$ balooctl6 status   → "Baloo is currently disabled."
$ recent-activity check → true
  daemon → RECORDING
  recentApps=2  recentDocs=3  recentFolders=1  frequent=6
```

Everything kept working. Baloo was restored to its original enabled state
afterwards. `balooctl6 status` showing "running" says nothing whatsoever about
Recent Files, which is why it was such a misleading signal.

## 8. A trap worth recording

Probing the daemon over D-Bus to ask whether the feature works is not safe:

```
$ qdbus6 org.kde.ActivityManager /ActivityManager/Features \
    IsFeatureOperational org.kde.ActivityManager.Resources.Scoring
Error: org.freedesktop.DBus.Error.NoReply
Remote peer disconnected            ← the daemon exited
```

And the "safe" spelling is useless anyway — it returns `false` whether or not
recording works, because of this:

```cpp
bool StatsPlugin::isFeatureOperational(const QStringList &feature) const
{
    if (feature[0] == "isOTR") { … }
    return false;                    // everything else: always false
}
```

Reading the configuration file is both safe and authoritative. That is what the
fix does.

## The corrected definition

Recording is on when **all** of these hold:

| Where | Key | Requirement | Default when unset |
| --- | --- | --- | --- |
| `kactivitymanagerd-pluginsrc` / `[Plugin-org.kde.ActivityManager.Resources.Scoring]` | `what-to-remember` | ≠ 2 | 0 |
| same | `off-the-record-activities` | does **not** contain the current activity | empty |
| same | `enabled` | ≠ `false` (legacy; honoured for UI consistency only) | true |
| `kdeglobals` / `[RecentDocuments]` | `UseRecent` | ≠ `false` (drives `recently-used.xbel`) | true |

`what-to-remember == 1` is "only the listed applications": still recording, so
it counts as on, reported distinctly as `limited`.
