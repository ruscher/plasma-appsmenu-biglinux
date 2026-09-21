# 4. Quick Links — resolve applications instead of copying their details

## What was wrong

The gadget carried its own copy of every application's name, icon name and
command:

```qml
{ name: i18n("Big Store"), icon: "bigstore", target: "big-store" }
```

`bigstore` is not an icon. Big Store installs `big-store`
(`/usr/share/icons/hicolor/scalable/apps/big-store.svg`), so that tile drew an
empty gap — the reported symptom, and exactly what copying invites. Copies of
`Exec` are worse still: they lose the entry's field codes, working directory,
terminal flag and D-Bus activation, and they cannot tell whether the
application is installed at all.

## What it does now

A link states a **desktop id**; everything else is read from the desktop entry
at runtime by a new helper, `contents/tools/desktop-entry`, in the same spirit
as the existing `recent-activity` tool:

* `desktop-entry resolve <id>…` → one TSV line per id: `id, path, Name, Icon`.
  `Name` comes back translated, because KConfig honours the caller's locale and
  plasmashell runs under the session one.
* `desktop-entry launch <id>` → `gio launch <path>`, which applies the entry's
  own `Exec` and field codes.

The defaults are BigLinux's own tools, each with `alt` equivalents to try when
the first is missing, so a machine without KCalc still gets a calculator rather
than a gap. An id that resolves nowhere is **dropped from the grid**: no dead
button, which is what the brief asked for.

Backwards compatible: a `target` that is a URL still opens in the default
handler and anything else still runs as a command line, so existing user
configuration keeps working. The settings hint now tells users they can type an
application id and let the system supply the name and icon.

## Safety

Targets come from configuration and the `executable` data engine runs commands
**through a shell**, so ids are validated on both sides. The pattern admits
letters, digits, `. _ + -` and a single `/` (BigLinux ships
`bigcontrolcenter/biglinux-settings.desktop` inside a subdirectory) and nothing
else — no quote, space or shell metacharacter can appear — and `..` is rejected
explicitly. Ids are single-quoted anyway when the command is built.

Rejected as expected: `../../../etc/passwd`, `a;id.desktop`, `$(id).desktop`,
`../x.desktop`; `launch` on an invalid id exits 2, on a missing application 3.

The free-form command field stays a command field — that is its purpose — but
control characters are now refused, since they could smuggle a second command
past what the user believes they typed.

## Test (live, on the VM, defaults restored)

All ten tiles resolved, translated, with icon names taken from the entries:

| tile | icon | source |
|---|---|---|
| Central de Controle | `bigcontrolcenter` | `bigcontrolcenter.desktop` |
| Ajustes gerais | `biglinux-settings` | `bigcontrolcenter/biglinux-settings.desktop` |
| Temas do BigLinux | `big-theme-gui` | `bigcontrolcenter/big-themes-gui.desktop` |
| Terminal Ashy | `ashyterm` | `org.communitybig.ashyterm.desktop` |
| Big Store | **`big-store`** | `big-store.desktop` |
| Adicionar e Remover WebApps | `big-webapps` | `br.com.biglinux.webapps.desktop` |
| Atualizações de programas | `system-software-update` | `pamac-updates.desktop` |
| Calculadora | `org.gnome.Calculator` | **fallback** — `org.kde.kcalc.desktop` is not installed |
| Anotações | `kate` | `org.kde.kate.desktop` |
| Gerenciador arquivos | `org.kde.dolphin` | `org.kde.dolphin.desktop` |

`effectiveCount: 10`, `resolving: false`, and `org.kde.kcalc.desktop` is
correctly absent from the resolved set — the alternative took its place.

Launching was verified for real: `desktop-entry launch org.kde.kate.desktop`
started `/usr/bin/kate -b` (the `-b` comes from the entry, not from us), and the
process was cleaned up afterwards.

**NOT TESTED:** the tiles were not clicked with a pointer (Wayland blocks
synthetic input); the launch path was exercised through the same helper the
click handler calls.

---

# 5. News Feed / RSS — sources you can actually reach

## Default sources

Diolinux, OMG! Ubuntu and SempreUpdate were removed as asked. Phoronix and
DistroWatch remain, and kernel.org was added so the gadget still has enough
sources for the switcher to mean anything — remove it from the settings if it
is not wanted. All three were verified to answer and parse before shipping:

| source | HTTP | format | items |
|---|---|---|---|
| Phoronix | 200 | RSS 2.0 | 32 |
| DistroWatch | 200 | RDF | 11 |
| kernel.org | 200 | RSS 2.0 | 10 |

**No dead references.** Articles are cached per source URL into the plasmoid
config, so the three removed feeds would have kept their articles there
forever. `RssGadget.forgetRemovedFeeds()` now sweeps entries for sources no
longer configured, on load and whenever the list changes. This needed two small
additions to the shared cache API (`cacheKeys`, `cacheRemove`), which are
useful to any gadget.

## The source switcher

It was `model: rss.feeds.slice(0, rss.host.wide ? 5 : 3)` — the sources past
the cut were not merely off-screen, they did not exist as far as the UI was
concerned, and nothing could reach them.

New shared component `gadgets/GadgetTabStrip.qml`: chips keep their natural
width (squeezing would trade a hidden item for an unreadable one) and the strip
scrolls sideways by flick or drag, by wheel — vertical **or** horizontal, since
a mouse only has one axis and the user still means "move along the strip" — and
with a thin scrollbar shown only while it is needed. When everything fits, the
wheel handler is disabled so the page behind keeps scrolling normally. Article
content stays vertical, as required.

### Test (live, 8 configured sources)

```
feedCount 8   stripModelCount 8   stripOverflowing true   itemsLoaded 10
cacheKeysNow ["feed:…distrowatch…", "feed:…phoronix…"]
```

All eight reachable (none sliced away), overflow detected, and the three
seeded stale caches for the removed feeds were swept — **PASS**.

## Parser matrix

`lib/RssParser.js` was run against real and synthetic feeds:

| case | result |
|---|---|
| RSS 2.0 (Phoronix) | 10 items, dates, links, summaries |
| RSS 2.0 (kernel.org) | 10 items |
| RDF (DistroWatch) | 10 items |
| Atom (GitHub releases) | 10 items, 10 images |
| special characters | `Açúcar & Café`, CDATA, `&#233;`, `&lt;b&gt;`, `€¥£`, `&amp;` in a URL — all decoded |
| image in description HTML | extracted |
| no image | empty string, and the card falls back to a `news-subscribe` icon |
| very long title (600 chars) | parsed; the delegate wraps and elides at 3 lines |
| truncated / unclosed tags | partial items, no throw |
| empty body, plain text, HTML page | 0 items, no throw |
| maxItems | respected (5 of 50) |

One defect fixed: `parse()` logged a `TypeError` whenever the body was not XML
at all — an empty response, an HTML error page, a captive portal. That is an
ordinary outcome for a feed URL, so it now returns the empty result directly
instead of tripping its own catch.

Worth knowing: **none of the three default sources publishes images** (no
`media:content`, `media:thumbnail`, `enclosure` or `<img>` anywhere in their
feeds), so the picture cards show the fallback icon by design rather than by
failure.

**NOT TESTED:** wheel, trackpad and drag on the strip were not exercised by
real input — Wayland blocks synthetic input. Overflow detection and the full
model were verified from the running engine.

---

# 6. Drive Info — a count that tells the truth, and devices that come and go

## Why the header disagreed with the list

The gadget discovered volumes by walking the KSystemStats sensor tree for
`disk/<id>/total`, counted what it found, and then rendered only the rows whose
`total` sensor had produced a value (`visible: Number(total.value) > 0`).
Anything discovered but silent was counted and invisible — permanently.

Probing the live tree showed exactly what was being counted:

```
volumeIds = ["disk/(?!all).*", "disk/0b033158-d636-4006-b254-120be8ee5fc1", "disk/vda"]
```

The first entry is not a device. It is a **wildcard sensor whose id is
literally the string `disk/(?!all).*`**, and it matched the discovery pattern,
was counted, and of course never reported a size. Three counted, two drawn.
The other two are the same storage seen twice — the filesystem by UUID and the
physical disk.

## Which API

The brief asked for an evaluation rather than a guess, so both were probed side
by side on the same machine. Ground truth: one btrfs volume on `/dev/vda1`
(mounted at `/`, `/home`, `/var/log`, `/var/cache` — subvolumes of one
filesystem) and an optical disc.

| | KSystemStats | Solid (`hotplug` + `soliddevice`) |
|---|---|---|
| what it reported | 3 entries, one a wildcard string, one a duplicate | 2 devices, exactly the real ones |
| removability | not exposed | `Removable` |
| mounted state | inferred from a sensor arriving | `Accessible` |
| sizes | raw bytes, formatted by hand | `Free Space Text` / `Size Text`, already localised (`38,0 GiB`) |
| icon | guessed from the name | `Icon`, the same one the rest of the desktop uses |
| pseudo-filesystems | present | never appear |
| hotplug | only if the tree happens to emit `rowsInserted` | event driven by design |

Solid wins on every line, so the gadget was rewritten on it. Nothing parses
`lsblk`, nothing polls, and no byte arithmetic is left.

The count can no longer drift because the header counts the **same list** the
view renders: mounted storage volumes, then removable devices that are present
but not mounted (worth seeing precisely because they are there and
unavailable). An unmounted internal partition is not a drive the user is
looking for, so it stays out.

Rows are told apart without a legend: the system volume (`File Path == "/"`) is
badged *System* and sorted first, removable devices are badged *Removable*, and
the list scrolls vertically once there are more devices than fit.

## Hotplug test — a real device, attached to the running VM

The VM's kernel has neither `loop` nor `usb-storage`, and polkit refuses
`udisksctl` over SSH, so the device was hot-attached from the hypervisor with
`virsh attach-disk … --live` (a 128 MiB vfat image labelled `PROBEUSB`). No
persistent change was made to the domain, and the disk list is back to its
original two entries.

| stage | Solid sources | rows rendered | header |
|---|---|---|---|
| baseline | 2 | 2 | 2 volumes |
| disk attached, unmounted | **3** | 2 | 2 volumes |
| mounted | 3 | **3** | **3 volumes** |
| unmounted | 3 | 2 | 2 volumes |
| detached | **2** | 2 | 2 volumes |

Solid saw the device the moment it was attached, with no polling and no
restart, and the header agreed with the list at every step. The new volume
reported `127,7 MiB free of 127,7 MiB`.

Baseline detail, for the record:

```
Disco interno de 50,0 GiB (vda1)  /  System      38,0 GiB free of 50,0 GiB  24%
BIGLINUX_LIVE_KDE   /mnt/BIGLINUX_LIVE_KDE  Removable   0 B free of 5,1 GiB  100%
```

**NOT TESTED:** a real USB stick. The kernel in this image ships no
`usb-storage` driver, so the QEMU USB disk enumerated (`QEMU USB HARDDRIVE` in
dmesg) but never produced a block device; the virtio path was used instead,
which exercises the same Solid code.
