# Places · 05 — Computer and Devices

Development notes. Nothing here is needed at runtime.

## Computer

Still `Kicker.ComputerModel`, which is the only route to `KFilePlacesModel`
from QML here. It is a `QConcatenateTablesProxyModel` over the Run Command
entry, the configured system applications, and a filtered `KFilePlacesModel`.

Its `data()` maps `Kicker::GroupRole` to `KFilePlacesModel::GroupRole` for
places and to `i18n("Applications")` for apps, so the headings are KDE's own
and already translated. Observed on this machine:

```
Aplicativos     Mostrar o KRunner · Configurações do sistema · Centro de informações
Locais          Início · Área de trabalho · Documentos · Shared · Downloads ·
                Música · Imagens · Vídeos · Lixeira
Remoto          Rede · Shared
```

Note "Shared" appearing in both groups: those are the user's own configured
places, read from `KFilePlacesModel`. No XDG path is assumed anywhere — the
folders shown are whatever the user's `user-dirs.dirs` and places file say.

## Devices — the part ComputerModel cannot do

`FilteredPlacesModel` drops fixed devices:

```cpp
return !m_placesModel->isHidden(index)
    && !m_placesModel->data(index, KFilePlacesModel::FixedDeviceRole).toBool();
```

and `ComputerModel::data()` returns `{}` for every role it does not
special-case, so there is no capacity, no mounted state and no action list.
`components/DeviceSection.qml` supplies exactly that, from Solid.

### Data path

```
hotplug engine      → the set of device UDIs, pushed on change
soliddevice engine  → per UDI: Accessible, Size, Free Space, Icon,
                      Removable, Device Types, File Path, Label, Ignored
its service         → mount / unmount operations
```

All three ship with `plasma5support`. No plugin of ours, no `lsblk`, no
`udisksctl`, no shell of any kind, and nothing needing root — mounting goes
through Solid/UDisks exactly as it does from Dolphin.

### Filtering

Only storage volumes are listed. The engine also reports cameras and portable
players, which are not places to open. Verified against the live machine:

```
SHOWN   root                  types=Block,Storage Access,Storage Volume  mounted=true   164,5 GiB free of 446,8 GiB  used=63%
skipped Câmera                types=Block,Camera                         mounted=false
SHOWN   root                  types=Block,Storage Access,Storage Volume  mounted=true   332,5 GiB free of 465,6 GiB  used=29%
SHOWN   root                  types=Block,Storage Access,Storage Volume  mounted=true   299,3 GiB free of 931,2 GiB  used=68%
SHOWN   root                  types=Block,Storage Access,Storage Volume  mounted=true   460,6 GiB free of 465,6 GiB  used=1%
SHOWN   Basic data partition  types=Block,Storage Access,Storage Volume  mounted=true    82,2 GiB free of 447,0 GiB  used=82%

6 hotplug sources → 5 shown
```

All five are `Removable=false`, i.e. **internal fixed drives** — precisely the
ones `ComputerModel` filters out. Devices marked `Ignored` by Solid are skipped
too.

### What a row shows

```
[icon]  Basic data partition
        ▓▓▓▓▓▓▓▓░░  82,2 GiB free of 447,0 GiB                    [⏏]
```

* icon — Solid's own (`drive-harddisk`, `drive-harddisk-root`, …), never guessed
* capacity — a thin bar plus `Free Space Text` / `Size Text`, both already
  formatted and localised by the engine, so no byte arithmetic happens in QML.
  The bar turns to the negative colour above 90 % used.
* mounted state — shown by dimming the icon rather than by a text label;
  capacity simply does not appear for an unmounted device
* the action button appears on hover/focus only, so the list stays calm

### Actions, only where they apply

| Condition | Button |
| --- | --- |
| mounted, `Removable` or optical | **Eject** (`media-eject`) |
| mounted, fixed | **Unmount** (`media-playback-stop`) |
| not mounted | no button — activating the row mounts it |

Solid decides; nothing is inferred from the device's name. An unmountable
device never offers Unmount, and a non-ejectable one never offers Eject.

### Clicking an unmounted device

```
click → runOperation(udi, "mount")
      → pendingOpenUdi remembers which device we asked for
      → the engine reports Accessible = true
      → the folder opens, once, for that device only
```

If the mount never completes, nothing opens and nothing is claimed — the row
simply stays unmounted. The device's `File Path` is handed to
`Qt.openUrlExternally`, so no command line is built from it.

## Hotplug

The `hotplug` engine is event driven: `onSourcesChanged` rebuilds the list when
a device appears or disappears. There is no timer in this file.

The rebuild compares the wanted UDI set against the current one and only
touches the `ListModel` when the set actually changed, so a routine free-space
update does not destroy and recreate every delegate.

## Known limitations

* **No eject distinct from unmount.** `soliddevice.operations` declares
  `mount`, `unmount` and `updateFreespace`. Eject is offered where Solid says
  the device is removable or optical, but it is carried out as `unmount`; a
  true tray-eject would need the `hotplug` engine's `invokeAction` with a Solid
  action predicate, which is not wired up here.
* **Mount errors are silent.** The service reports a result the section does
  not yet surface; a failed mount currently just leaves the device unmounted
  rather than explaining why. Worth adding.
* **No device context menu.** Mount/unmount are a button on the row; there is
  no right-click menu for devices, because `ComputerModel` exposes no action
  list for places and this section's rows are not Kicker model rows.
* **Encrypted volumes** are listed when Solid reports them as storage volumes,
  but there is no unlock-specific UI; activating one triggers the normal Solid
  setup, which is what raises the passphrase prompt.
