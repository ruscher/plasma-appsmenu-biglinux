# Recent Files & Locations — 01 · Environment and reproduction

All findings below come from a live BigLinux test VM, reached over SSH. No
credentials are recorded here.

## The machine

| | |
| --- | --- |
| Distribution | BigLinux (based on Manjaro), `ID=biglinux`, rolling |
| Host | `ruscer-standardpc` |
| Plasma | `plasmashell 6.7.4` |
| Frameworks | `kio 6.29.0`, `baloo 6.29.0` |
| Activities | `kactivitymanagerd 6.7.4-1`, `plasma-activities 6.7.4-1`, `plasma-activities-stats 6.7.4-1` |
| Session | **Wayland** (`loginctl` session 11, `Type=wayland`, seat0) |

`kf6-config` and `qtpaths6` are not installed on this image; versions were taken
from `pacman -Q` instead.

## State as found (before any change)

`~/.config/kactivitymanagerd-pluginsrc`:

```ini
[Plugin-org.kde.ActivityManager.Resources.Scoring]
enabled=true
keep-history-for=1
off-the-record-activities=82dd571b-19a5-41da-b9fa-e65d403c625b
what-to-remember=0
```

The single activity on the machine:

```
CurrentActivity = 82dd571b-19a5-41da-b9fa-e65d403c625b   ("Default")
ListActivities  = 82dd571b-19a5-41da-b9fa-e65d403c625b
```

**The one and only activity was listed as off-the-record.**

Other files:

- `~/.config/kioslaverc` — **did not exist**, so `FilesEnabled` and
  `LocationsEnabled` were unset.
- `~/.config/kdeglobals` — no `[RecentDocuments]` group, so `UseRecent` unset.
- `~/.config/kactivitymanagerdrc` — contains a legacy
  `[Plugins] org.kde.ActivityManager.ResourceScoringEnabled=false`.
- `~/.local/share/recently-used.xbel` — 16 bookmarks, recently modified.
- `~/.local/share/user-places.xbel` — has `recentlyused:/files` and
  `recentlyused:/locations`, `GroupState-RecentlySaved-IsHidden=false`.

Services and daemons were all healthy:

```
systemctl --user is-active plasma-kactivitymanagerd.service  → active
/usr/lib/kactivitymanagerd    running
/usr/lib/kf6/baloo_file       running
balooctl6 status              → "Baloo File Indexer is running", 686 files indexed
```

## The reproduction

The scoring database is the ground truth for whether anything is being
recorded:

```
$ sqlite3 ~/.local/share/kactivitymanagerd/resources/database \
    'SELECT COUNT(*) FROM ResourceEvent;'
0
$ sqlite3 ... 'SELECT COUNT(*) FROM ResourceScoreCache;'
0
```

Zero rows, on a machine in daily use, with the service active and Baloo
indexing happily. `ResourceInfo` had 38 rows — metadata only, written by a
different path — which is why the database did not look obviously empty.

### Why the menu hid its button

`RecentActivityTracking.qml` decided the feature was on when
`enabled != false && what-to-remember != 2`. Both held, so the menu concluded
"tracking = true", hid the call to action, and rendered four permanently empty
models.

### Why the settings switch read OFF

`recentFiles.sh check` required `what-to-remember == 0 && UseRecent == "true"
&& FilesEnabled == "true"`. `UseRecent` and `FilesEnabled` were unset, so the
switch reported `false` — while the menu reported the opposite. It also emitted
three shell errors before answering:

```
./usability/recentFiles.sh: line 8: local: can only be used in a function
./usability/recentFiles.sh: line 11: local: can only be used in a function
./usability/recentFiles.sh: line 14: local: can only be used in a function
false
```

That disagreement — menu says on, settings says off, nothing works — is the bug
as users experienced it.

## Test material

```
~/Documents/biglinux-recent-test-01.txt
~/Documents/biglinux-recent-test-02.txt
~/Downloads/biglinux-recent-test-03.txt
~/biglinux-recent-testdir/
```

Note that the scoring plugin's default `url-filters` ignore `/tmp/*` and
hidden files, so test data must live outside `/tmp` to be recorded at all.

## Backups taken before touching anything

```
~/recent-files-backup-20260921-093903/
  kactivitymanagerd-pluginsrc  kdeglobals
  recently-used.xbel           user-places.xbel
  database                     (the scoring database)
```
