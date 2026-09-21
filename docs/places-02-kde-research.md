# Places · 02 — KDE research

Development notes. Nothing here is needed at runtime.

What each candidate technology solves, whether it is reachable from QML on
Plasma 6.7.4 / KF 6.29, and what was decided.

## Availability survey

There is **no** `org.kde.kio`, `org.kde.solid` or `org.kde.kglobalaccel` QML
module installed. Checked directly:

```
/usr/lib/qt6/qml/org/kde/  →  kio ✗   solid ✗   kglobalaccel ✗
/usr/lib/qt6/qml/org/kde/plasma/private/  →  kicker ✓ (+ battery, sessions, …)
```

Types exported by `org.kde.plasma.private.kicker`:

```
AppsModel  ComputerModel  ContainmentInterface  DashboardWindow  DragHelper
FunnelModel  KAStatsFavoritesModel  ProcessRunner  RecentUsageModel  RootModel
RunnerModel  SimpleFavoritesModel  SubMenu  SystemModel  SystemSettings
WheelInterceptor  WindowSystem
```

So anything not covered by Kicker has to come from Plasma5Support data engines
or be left out.

## KActivities / PlasmaActivitiesStats

**Solves:** which apps, files and folders the user actually uses, both by
recency and by frequency, scoped to the current activity.

**Reachable:** yes, through `Kicker.RecentUsageModel`, which builds a
`KActivities::Stats` query:

```cpp
UsedResources
  | (Recent ? RecentlyUsedFirst : HighScoredFirst)
  | Agent::any()
  | (OnlyDocs ? Type::files() : OnlyFolders ? Type::directories() : Type::any())
  | Activity::current()
```

**Decision:** use it for both Frequently Used and the three History
categories. `HighScoredFirst` is KDE's own frequency score, so **no custom
ranking formula is written** — the brief's optional
`usageFrequencyWeight + recencyWeight + KDEActivityScore` is unnecessary, and
inventing one would diverge from the rest of the desktop.

**Limitation:** upstream caps results (`Limit(15)` for apps, `Limit(30)` for
apps+docs). That is well within the 8–15 per section the brief asks for, so it
is not a problem.

## Kicker ComputerModel → KFilePlacesModel + Solid

**Solves:** system applications, the user's configured places, network/remote
entries, removable devices, and click-to-mount.

**Reachable:** yes — and importantly it is the *only* route to
`KFilePlacesModel` from QML here.

**Decision:** keep it as the backbone of Computer. Its `GroupRole` already
produces the Applications / Places / Remote / Devices headings the brief wants
(§13), rendered by the section delegate that already exists.

**Limitations (measured, not assumed):**

- fixed/internal devices are filtered out (`!FixedDeviceRole`);
- no capacity, no mounted state, no action list;
- `onSetupDone` swallows mount errors.

## Solid via the `hotplug` + `soliddevice` data engines

**Solves:** exactly the gaps above.

**Reachable:** yes. `plasma_engine_hotplug.so` and
`plasma_engine_soliddevice.so` ship with `plasma5support`, and
`soliddevice.operations` declares `mount`, `unmount` and `updateFreespace`.

Probed on this machine — the `hotplug` engine lists device UDIs, and each is a
`soliddevice` source. Real output for an internal volume:

```
Accessible        = true
Description       = root
Device            = /dev/sda2
Device Types      = Block,Storage Access,Storage Volume
File Path         = /mnt/root1
File System Type  = btrfs
Free Space        = 357055406080      Free Space Text = 332,5 GiB
Size              = 499942801408      Size Text       = 465,6 GiB
Hotpluggable      = false             Removable       = false
Icon              = drive-harddisk
Ignored           = false             In Use          = true
Label             = root
```

and a non-storage device is distinguishable:

```
Description  = Câmera
Device Types = Block,Camera
Icon         = camera-photo
```

That gives every field the brief asks for: mounted state (`Accessible`),
capacity (`Free Space` / `Size`), a correct Breeze icon, whether eject makes
sense (`Removable` / `Hotpluggable`), and **internal drives**, which
`ComputerModel` omits.

**Hotplug:** the engine is event-driven — sources appear and disappear as
devices are plugged in and out, so `sourcesChanged` is the update signal. No
timer, no polling, no `lsblk`/`udisksctl`.

**Decision:** build the Devices section on `hotplug` + `soliddevice`, and use
`serviceForSource(udi)` for mount/unmount. This is Plasma's own infrastructure,
so it needs no plugin of ours and no shell.

**Note on Plasma5Support:** these are Plasma5Support engines. The brief says not
to replace Plasma5Support blindly where it is still required — this is such a
case: there is no Plasma 6-native QML binding for Solid, and the project
already depends on `plasma5support` for its gadgets.

## KIO

**Solves:** opening local and remote URLs correctly.

**Reachable:** indirectly. `ComputerModel::trigger()` uses `KIO::OpenUrlJob`
internally, and `RecentUsageModel` entries open through the same Kicker path.

**Decision:** never construct file-manager command lines. Everything opens via
`model.trigger()`, which keeps KIO's handling of `smb://`, `sftp://`, `trash:/`
and friends. No manual remote access is implemented, and no shell is used to
open anything.

## KGlobalAccel — investigated and **rejected**

**Solves:** enumerating configured global shortcuts.

**Reachable:** only over D-Bus (`org.kde.kglobalaccel` `/kglobalaccel`); there
is no QML binding.

**Why it is not used.** Three independent reasons:

1. **There is no usage data.** The full method list was inspected; there is no
   count, statistic or invocation history of any kind:

   ```
   action  actionList  activateGlobalShortcutContext  allActionsForComponent
   allComponents  allMainComponents  blockGlobalShortcuts  defaultShortcut
   defaultShortcutKeys  doRegister  getComponent  getGlobalShortcutsByKey
   globalShortcutAvailable  globalShortcutsByKey  isGlobalShortcutAvailable
   setForeignShortcut  setForeignShortcutKeys  setInactive  setShortcut
   setShortcutKeys
   ```

   Listing shortcuts under "Frequently Used" would therefore be presenting an
   invented ranking, which the brief explicitly forbids (§12). The only honest
   alternative offered — counting invocations the menu itself can observe —
   would count almost nothing, because global shortcuts are by definition
   pressed *outside* the menu.

2. **No usable binding.** The interesting methods return `aas` and
   `a(ssssssaiai)`; `qdbus` cannot even print them without `--literal`. Reading
   them from QML would mean spawning an external process per query and parsing
   nested D-Bus structures by hand.

3. **Questionable value.** A shortcut is something you press, not something you
   browse a menu to find. §66 says not to add features merely to look
   sophisticated.

Monitoring the keyboard to obtain counts was never considered: the brief rules
it out, and it would be indefensible regardless.

**Conclusion:** no Shortcuts section. Documented here rather than silently
dropped.

## Recent Locations — investigated, folded in instead

The brief asks (§27) whether a separate "Recent Locations" is worth it.
`RecentUsageModel(OnlyFolders)` already returns *any* directory resource the
activity manager recorded, including non-`file://` KIO URLs, because the query
filters on `Type::directories()` rather than on the scheme. A separate category
would therefore show the same rows as History Folders minus the local ones —
more categories, no new information.

**Decision:** no separate category. Remote locations appear in History Folders
and Frequently Used → Folders when the user has actually opened them, and the
configured remote places stay in Computer → Remote via `KFilePlacesModel`.

## A C++ helper — investigated, not needed

The brief permits a small plugin if an essential API is not exposed (§49).
After the survey above, nothing essential is missing:

| Need | Covered by |
| --- | --- |
| Places / Network / removable devices | `Kicker.ComputerModel` (wraps KFilePlacesModel) |
| Fixed drives, capacity, mounted state | `soliddevice` data engine |
| Hotplug | `hotplug` data engine |
| Mount / unmount | `soliddevice.operations` service |
| Frequency, recency, activity scoping | `Kicker.RecentUsageModel` |

Adding a plugin would also change the package fundamentally: `pkgbuild/PKGBUILD`
currently installs a pure QML tree with `arch=any` and no compilation step, so
a plugin would introduce cmake/ECM build dependencies and an architecture
specific package for no functional gain.

**Decision:** no C++ helper. The project stays QML-only.
