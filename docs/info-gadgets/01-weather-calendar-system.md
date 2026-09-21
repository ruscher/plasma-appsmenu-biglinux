# 1. Weather — manual city, °F, and the endless spinner

## Reported

Choosing a city by hand does nothing; switching to Fahrenheit does nothing;
the gadget spins forever.

## Root cause — one bug, all three symptoms

`WeatherGadget.refresh()` opened with `if (busy) return` and set
`busy = true`. The branch that resolves a typed city ended like this:

```qml
Provider.geocode(host.cfg.query, (err, loc) => {
    if (err) return done(err, null, null)
    const c = Object.assign({}, host.cfg, { lat: …, lon: …, resolvedFor: … })
    host.saveCfg(c)  // triggers onCfgChanged → will run with the cached coords
})
```

That comment was the bug. `saveCfg()` never cleared `busy`, and the
`onCfgChanged → refresh(true)` it was counting on hit `if (busy) return` and
returned immediately. So:

* the forecast for the typed city was **never requested**;
* `busy` and `host.loading` stayed `true` **forever** → the endless spinner;
* and because every later call also hit `if (busy) return`, the gadget was
  **dead for the rest of the session** — unit changes, city changes and the
  20-minute timer all did nothing.

The live VM config still carried the fingerprint: `cfg` held
`query: "São Paulo"`, `resolvedFor: "São Paulo"` and São Paulo's coordinates,
while the cached forecast was **Brasília**. The geocode had completed and been
saved; the forecast never followed.

A second defect compounded it: the forecast was cached under the single key
`"forecast"`, with no location and no unit in it, so a Celsius forecast for one
city could be shown as Fahrenheit for another.

## Fix — state management, not a workaround

`items/WeatherGadget.qml`:

* **One exit point.** Every path that ends a request goes through `finish()`,
  which clears `busy` and `host.loading`. The geocode branch no longer bounces
  through `saveCfg`: it saves the resolution for next time and then *continues
  straight to the forecast* with the coordinates it just received.
* **Requests supersede instead of being dropped.** `if (busy) return` is gone.
  Each request takes an id from a counter; a reply whose id is stale belongs to
  a request the user already replaced and is discarded, so a slow answer for
  the old city can never overwrite the new one.
* **React to what changed, not to the signal.** A derived `requestKey`
  (`"auto|c"`, `"city:são paulo|f"`, …) names the request. Writing resolved
  coordinates back to `cfg` does not change it, so it does not restart
  anything — and the framework's duplicate `cfgChanged` (see `00-audit.md`)
  collapses to one request. Re-applying the same city from the settings page
  clears `resolvedFor` and is honoured as an explicit retry.
* **Cache carries its own scope.** The entry stores `scopeKey`, `unitKey` and
  the coordinates, all re-checked on read. A mismatch is a miss, so no Celsius
  reading is ever relabelled as Fahrenheit and no city borrows another's
  forecast. It stays a single slot, because the cache is persisted into the
  plasmoid config and a key per city would grow without bound.
* **Retry floor.** A location that cannot be resolved never fills the cache, so
  the gadget would otherwise re-request every time it scrolled back into the
  viewport. Automatic refreshes now keep 60 s between attempts; an explicit
  refresh from the settings page is never delayed.

`lib/WeatherOpenMeteo.js`: `locateByIp()` fell back to **cleartext**
`http://ip-api.com`, which publishes the user's city to every hop on the path.
Its free tier offers no HTTPS, so it was replaced rather than upgraded. The
chain is now HTTPS-only and keyless — `ipwho.is`, `get.geojs.io`, `ipapi.co` —
tried in order with a 6 s timeout each. This mattered in practice: `ipapi.co`,
the previous *primary*, does not even resolve from this network, so every
automatic lookup had been going out in the clear.

## Tests

Logic, running the shipped functions in a harness that reproduces QML binding
semantics and the framework's double `cfgChanged`:

| Step | Before (HEAD) | After |
|---|---|---|
| auto start | ok | ok |
| manual "São Paulo" | **busy=true forever, only `geocode` sent** | `geocode` + `forecast`, busy cleared |
| switch to °F | **no request** | 1 request, 77 °F |
| invalid city | **no request** | error shown, previous reading kept |
| back to automatic | **no request** | 1 request |
| fresh cache | — | 0 requests |
| °F → °C | **no request** | refetched, no stale reuse |

End-to-end on the VM (Plasma 6.7.4, Wayland confirmed from the plasmashell
process), driven through the real config:

| Case | Result |
|---|---|
| manual São Paulo, °C, no saved coordinates | `scopeKey city:são paulo\|c`, 28 °C, coords −23.5475/−46.63611 — **PASS** |
| switch to °F with a Celsius entry cached | refetched, `city:são paulo\|f`, 82 °F — **PASS** |
| invalid city | last good reading kept, nothing cached — **PASS** |
| back to automatic | `auto\|c`, Brasília 31 °C — **PASS** |

Live QML state read from the running engine:

```
manual city   {"busy":false,"loading":false,"error":"","subtitle":"Lisboa, Distrito de Lisboa · PT","temp":31,"requestId":1}
invalid city  {"busy":false,"loading":false,"error":"City not found. Check the spelling in the settings.","requestId":1}
automatic     {"busy":false,"loading":false,"subtitle":"Brasilia, Federal District · BR","temp":31,"requestId":1}
```

`requestId: 1` is the point: one request per change, despite the framework
emitting `cfgChanged` twice. With the cache wiped, the label returned
(`Brasilia, Federal District`, unaccented) is `ipwho.is`'s own spelling,
confirming the new HTTPS chain really ran.

**NOT TESTED:** the settings dialog was driven through the config rather than
by clicking, because Wayland blocks synthetic input and `spectacle` core-dumps
on this VM. The radio buttons and the Apply button were not exercised by
pointer.

---

# 2. Calendar — a clear icon and a real "Today" button

## Icon

`view-calendar` is an *action* glyph, not a calendar. Rather than guess a
replacement, the names were checked against the theme the system actually uses
(`bigicons-papient`):

| name | present |
|---|---|
| `view-calendar` | yes (actions) |
| `office-calendar` | **yes (apps)** — chosen |
| `calendar` | yes (apps) |
| `calendar-symbolic` | no |
| `go-jump-today` | yes (actions) — used for the button |

One finding matters beyond this gadget: **`bigicons-papient` declares
`Inherits=hicolor` only**, with no Breeze underneath. A name the theme does not
carry therefore renders as an empty gap rather than falling back to something.
`Kirigami.Icon.fallback` is now set explicitly wherever a registry icon is
drawn (`GadgetTitleBar`, `GadgetGallery`).

## The button

Returning to the current month existed, but only as an undocumented click on
the month label — nobody finds that. It is now a real button beside the gadget
title.

It is **not** special-cased in the shared header. `GadgetHost` gained a
`titleActions` list and `GadgetTitleBar` renders whatever a gadget puts there
as tool buttons, so any gadget can publish one without the shared component
knowing anything about calendars:

```qml
Component.onCompleted: host.titleActions = [todayAction]

QQC2.Action {
    id: todayAction
    text: i18nc("@action:button jump the calendar back to the current day", "Today")
    icon.name: "go-jump-today"
    onTriggered: cal.goToToday()
}
```

`goToToday()` re-reads `today` before calling `resetToToday()`, because the
gadget may have been open across midnight and would otherwise return to
yesterday's month. Everything that highlights the current day is bound to
`today`, so the selection follows on its own.

### Test (live, on the VM)

```
{"titleActions":1,"actionText":"Today","actionIcon":"go-jump-today",
 "startMonth":"2026-09","afterNavigating":"2026-06","afterToday":"2026-09",
 "currentMonth":"2026-09","backToCurrent":true}
```

Navigated three months back, pressed the action, landed back on the current
month — **PASS**.

---

# 3. GPU Meter — position and icon

`GadgetRegistry.defaultLayout` listed `gpu` **last**, far from its siblings.
It now sits between them: `clock, weather, calendar, cpu, gpu, memory, …`.

The icon was `"gpu"`, and there is no such icon: a search of every installed
theme found no `gpu.svg` or `gpu.png` anywhere, and since the theme inherits
only hicolor there is nothing to fall back to — so the tile drew a blank. It
now uses `"cpu"`, as asked, which is present
(`bigicons-papient/…/devices/cpu.svg`). No monitoring code was touched.
