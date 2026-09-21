# Info gadgets — architecture audit

Read before changing anything, as the mission requires. Everything here was
established by reading the code and by observing a real Plasma 6.7.4 / Qt
6.11.2 Wayland session on the lab VM, not by assumption.

## The pieces

```
contents/ui/InfoPage.qml          layout + cache persistence, owns the config
contents/ui/gadgets/
    GadgetRegistry.qml            catalogue + default layout
    GadgetGrid.qml                placement, drag, serialize()
    GadgetHost.qml                per-instance chrome: cfg, cache, loading, error
    GadgetGallery.qml             "add gadget" picker
    GadgetSettingsDialog.qml      per-gadget settings host
    lib/*.js                      shared providers (net, weather, sports, …)
    items/*Gadget.qml             24 gadgets
```

## Two framework behaviours that bite every gadget

### 1. `cfgChanged` fires more than once per save

`GadgetHost.saveCfg()` assigns `cfg` locally **and** hands the JSON to
`GadgetGrid.saveCfg()`, which writes it into `layoutModel`; that round-trips
back through `GadgetHost.cfgJson` → `onCfgJsonChanged` → `cfg = JSON.parse(…)`.
So one settings change emits `cfgChanged` **twice**, synchronously, before any
network reply can arrive.

A gadget that reacts to the signal itself therefore starts two requests per
change. The fix used here is to react to *what changed* — a derived key naming
the request — instead of to the signal. See `01-weather.md`.

### 2. The gadget cache is persisted, shared, and was never pruned

`InfoPage` keeps one JS object, serialised into
`Plasmoid.configuration.gadgetCache`. `host.cacheSet(k, v)` writes
`<instance uid>:k`; `host.sharedCacheSet(k, v)` writes `<gadget id>:k`.

Nothing ever removed an entry. On the lab VM the live config held **28 keys**,
including **seven** orphaned `weather-…` uids and **seven** orphaned
`currency-…` uids — every forecast and rate table the user had ever had, kept
forever because re-adding or resetting a gadget mints a new uid.

Fixed in `InfoPage.pruneCache()`: on load, drop every key whose prefix is
neither a live instance uid nor a live gadget id. The same VM config dropped
from 28 keys to 6.

## Testing without synthetic input

Wayland blocks synthetic input and `spectacle` core-dumps on this VM, so gadget
behaviour is driven through the plasmoid's own config and read back from it:

1. stop `plasma-plasmashell.service`
2. rewrite the gadget's `cfg` inside `gadgetLayout` (KConfig-escaped JSON)
3. set `rememberLastPage=true` + `lastTab=3` so the menu opens **on the Info
   page**, which is what instantiates the gadget
4. start plasmashell, `qdbus6 … activateLauncherMenu`, wait
5. stop plasmashell (flushes the config), read `gadgetLayout` + `gadgetCache`

For state that never reaches the config (`busy`, `host.loading`,
`host.errorText`) a temporary `Timer` is appended to the **deployed** copy that
XHR-PUTs a JSON snapshot to `/tmp`, with
`systemctl --user set-environment QML_XHR_ALLOW_FILE_WRITE=1`. Both the probe
and the override are removed afterwards.

Note `loginctl show-session` on the SSH session reports `Type=tty`: the session
type must be read from the plasmashell process itself
(`tr '\0' '\n' < /proc/$(pgrep -n plasmashell)/environ`), which confirmed
`XDG_SESSION_TYPE=wayland`.
