# BigLinux Application Launcher

`org.biglinux.appsmenu` is the application launcher of BigLinux for **KDE Plasma 6**. It started as a BigLinux adaptation of KDE Kickoff and now combines the familiar application menu with a compact desktop dashboard: four pages (Home, Apps, Places, Info), a unified search field, and 23 configurable gadgets.

![BigLinux Application Launcher](./screenshots/normal.jpg)

- **Plasmoid ID:** `org.biglinux.appsmenu`
- **Requires:** KDE Plasma 6.0 or newer (`X-Plasma-API-Minimum-Version: 6.0`)
- **Provides:** `org.kde.plasma.launchermenu` — it can replace Kickoff as the panel menu
- **Implementation:** QML only, no compilation step

---

## Table of contents

- [What the menu does](#what-the-menu-does)
- [Gadget catalogue](#gadget-catalogue)
- [Configuration](#configuration)
- [Installation](#installation)
  - [1. From the BigLinux repositories](#1-from-the-biglinux-repositories)
  - [2. Building the package with makepkg](#2-building-the-package-with-makepkg)
  - [3. Installing straight from the repository tree](#3-installing-straight-from-the-repository-tree)
  - [4. Per-user installation with kpackagetool6](#4-per-user-installation-with-kpackagetool6)
- [Applying the menu and restarting plasmashell](#applying-the-menu-and-restarting-plasmashell)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Privacy and offline use](#privacy-and-offline-use)
- [Architecture](#architecture)
- [History](#history)
- [Credits](#credits)
- [License](#license)

---

## What the menu does

### Header — always visible

- Search field covering applications, system settings, files and every other KRunner provider (`Search applications, settings, and files…`).
- User avatar with full name, opening the user account settings.
- Power and session actions (log out, reboot, shut down) integrated with the Plasma session, configurable in the footer.
- Full keyboard navigation: the search field, avatar, sidebar, content pane and tab bar form a single focus chain, with accessible names and descriptions on every control.

### Home

- Favorites, as a grid or a list.
- Recently used applications, files and folders, plus a *Frequently used* section.
- Every section is collapsible; the collapsed state is remembered per instance (`homeCollapsedSections`).
- Per-section limits for recent applications, files and folders.
- When the KDE activity history is off — *Recent Files* in System Settings, which is what feeds all of these sections — the page shows a centered **Turn on recent files** button that enables it and restarts `kactivitymanagerd`, plus a shortcut to the full settings page.

### Apps

- All installed applications, browsable by category in a sidebar.
- Grid or list layout, optional alphabetical sorting, optional *All Applications* category.
- Right-click actions: add/remove from favorites, add to panel or desktop, open in a new window, jump-list actions from the `.desktop` file.
- Drag and drop of applications out of the menu, onto the panel or desktop.

### Places

- **Computer** — system applications, mounted devices, disks and network locations.
- **History** — recently opened documents and folders.
- **Frequently Used** — the most used items.

### Info — the gadget dashboard

- A grid of cards you assemble yourself: 2, 3 or 4 columns.
- **Edit mode** — press *Edit* (or press and hold a card) to drag gadgets into a new order, resize them, configure them, or remove them.
- **Add** opens the gallery, grouped in four categories: Time & Planning, System, Online, Tools & Fun.
- Gadget sizes are `1x1`, `2x1`, `1x2` or `2x2`, depending on the gadget.
- Some gadgets can be added several times (multiple clocks, feeds, notes, quick-link panels…).
- The layout and the per-gadget settings are stored per plasmoid instance (`gadgetLayout`), and online results are cached with timestamps (`gadgetCache`) so the dashboard still shows data while offline.
- Each card is loaded in isolation: a gadget that fails to load cannot take the menu down.
- Gadget timers are paused while the menu is closed.

### Search

- Results grouped by category (can be turned off), with the same launch and context actions as the Apps page.

### First run

- A welcome overlay explains search, favorites, the four tabs and the Info gadgets. It is shown once per instance (`onboardingCompleted`).

---

## Gadget catalogue

| Gadget | Category | Sizes | Notes |
| --- | --- | --- | --- |
| Clock | Time & Planning | 1x1, 2x1 | Analog or digital clock with date and seconds; several instances allowed |
| Calendar | Time & Planning | 1x2, 2x2, 1x1 | Month view with Plasma event plugins, holiday regions, event dots and tooltips |
| Countdown | Time & Planning | 1x1, 2x1 | Days, hours and minutes until your events, with an alarm when the time is up |
| CPU Meter | System | 1x1, 2x1, 2x2 | Total usage ring, per-core bars, temperature and frequency |
| GPU Meter | System | 1x1, 2x1 | GPU usage from the `ksystemstats` sensors |
| Memory | System | 1x1, 2x1 | RAM and swap usage |
| Battery | System | 1x1 | Liquid-style charge indicator |
| Drive Info | System | 1x1, 2x1, 1x2 | Capacity and free space per disk |
| Drive Monitor | System | 1x1, 2x1 | Live read/write throughput |
| Network | System | 1x1, 2x1 | Interface throughput |
| System Info | System | 1x1, 2x1 | Hostname, kernel, shell, uptime and desktop version |
| Weather | Online | 1x1, 2x1, 2x2 | Current conditions and forecast (Open-Meteo, no API key) |
| News Feed | Online | 1x1, 2x1, 2x2, 1x2 | Headlines with pictures from any RSS/Atom feed; several instances allowed |
| Currency | Online | 1x1, 2x1 | Exchange rates (European Central Bank via Frankfurter) |
| Live Scores | Online | 1x1, 2x1, 2x2 | Football, basketball and more — live scores and fixtures (TheSportsDB) |
| Media Player | Tools & Fun | 1x1, 2x1 | Now playing with controls and cover art (MPRIS) |
| Clipboard | Tools & Fun | 1x1, 2x1, 1x2 | Recent clipboard entries (Klipper) |
| Notes | Tools & Fun | 1x1, 2x1, 1x2, 2x2 | Quick sticky notes, saved automatically; several instances allowed |
| Quick Links | Tools & Fun | 1x1, 2x1, 2x2 | Your favorite apps and sites, one tap away |
| Quote of the Day | Tools & Fun | 1x1, 2x1 | Built-in quotes, with an optional online source (ZenQuotes) |
| Tips | Tools & Fun | 1x1, 2x1 | Handy BigLinux and KDE tricks |
| Gallery | Tools & Fun | 1x1, 2x1, 2x2 | Slideshow of a folder of pictures; several instances allowed |
| 2048 | Tools & Fun | 1x1, 2x2 | Slide the tiles and reach 2048 |

The online gadgets (Weather, News Feed, Currency, Live Scores — and Quote of the Day when you enable its online source) use their configured public providers. They can be configured, disabled or removed and never block the rest of the launcher.

---

## Configuration

Right-click the panel icon → **Configure Application Launcher…**

| Group | Options |
| --- | --- |
| Appearance | Symbolic (monochrome) category icons, compact list items |
| Applications | *All Applications* category, alphabetical sorting, applications as grid/list, favorites as grid/list |
| Home | Show recent applications, recent files, recent folders, frequently used; maximum item count for each |

The Info dashboard is configured from the page itself (*Edit* / *Add*), not from this dialog.

Settings are stored per applet instance in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, under the applet’s `[Configuration][General]` group. Notable keys: `favorites`, `systemFavorites`, `rememberLastPage`, `lastTab`, `lastCategoryRow`, `gadgetColumns`, `gadgetLayout`, `gadgetCache`, `homeCollapsedSections`, `onboardingCompleted`. The full schema is in [`contents/config/main.xml`](usr/share/plasma/plasmoids/org.biglinux.appsmenu/contents/config/main.xml).

---

## Installation

### 1. From the BigLinux repositories

```bash
sudo pacman -Syu plasma-appsmenu-biglinux
```

### 2. Building the package with makepkg

The recipe in [`pkgbuild/PKGBUILD`](pkgbuild/PKGBUILD) clones the `main` branch itself, so you only need the recipe:

```bash
git clone https://github.com/ruscher/plasma-appsmenu-biglinux.git
cd plasma-appsmenu-biglinux/pkgbuild
makepkg -si
```

`makepkg -si` builds the package and installs it with all dependencies. To build without installing, use `makepkg -s` and then:

```bash
sudo pacman -U plasma-appsmenu-biglinux-*.pkg.tar.zst
```

### 3. Installing straight from the repository tree

The plasmoid is pure QML, so the `usr/` tree can be copied as it is (system-wide, all users):

```bash
git clone https://github.com/ruscher/plasma-appsmenu-biglinux.git
cd plasma-appsmenu-biglinux
sudo cp -a usr/. /usr/
sudo chmod -R a+rX /usr/share/plasma/plasmoids/org.biglinux.appsmenu
```

This bypasses the package manager: `pacman` will not track the files, and a later package update overwrites them.

### 4. Per-user installation with kpackagetool6

For testing without touching `/usr` (installs into `~/.local/share/plasma/plasmoids/`):

```bash
cd plasma-appsmenu-biglinux
kpackagetool6 --type Plasma/Applet --install usr/share/plasma/plasmoids/org.biglinux.appsmenu
```

Upgrade an existing user copy:

```bash
kpackagetool6 --type Plasma/Applet --upgrade usr/share/plasma/plasmoids/org.biglinux.appsmenu
```

---

## Applying the menu and restarting plasmashell

After any installation method, Plasma must reload its plugin cache and restart the shell.

**1. Refresh the KDE service and plasmoid caches:**

```bash
kbuildsycoca6 --noincremental
```

**2. Restart plasmashell.** Use the method that matches your session:

```bash
# Recommended on BigLinux / any systemd user session
systemctl --user restart plasma-plasmashell.service
```

```bash
# Classic replace (use only if plasmashell is NOT managed by systemd)
plasmashell --replace & disown
```

```bash
# Quit and start again
kquitapp6 plasmashell && kstart plasmashell
```

> On a systemd user session, `plasmashell --replace` leaves a shell process outside
> `plasma-plasmashell.service`, and the service may start a second one later. If you
> already did that, go back to a single managed shell with:
>
> ```bash
> pkill -f 'plasmashell --replace'
> systemctl --user restart plasma-plasmashell.service
> ```

**3. Put the launcher in the panel:**

- Right-click the panel → **Enter Edit Mode**.
- Right-click the current menu button (Kickoff) → **Show Alternatives…** → select **BigLinux Application Launcher**.
- Or, to add it as a new widget: **Add Widgets…** → search for *BigLinux Application Launcher* → drag it to the panel.
- Leave edit mode and, if you want, set the panel icon and label in **Configure Application Launcher…**.

**4. Confirm the applet is registered:**

```bash
kpackagetool6 --type Plasma/Applet --list | grep appsmenu
```

---

## Updating

```bash
sudo pacman -Syu plasma-appsmenu-biglinux
kbuildsycoca6 --noincremental
systemctl --user restart plasma-plasmashell.service
```

Your favorites, tab memory and Info gadget layout live in the applet configuration and survive updates.

---

## Uninstalling

```bash
# Package installation
sudo pacman -Rns plasma-appsmenu-biglinux

# Manual system-wide copy
sudo rm -rf /usr/share/plasma/plasmoids/org.biglinux.appsmenu

# Per-user copy
kpackagetool6 --type Plasma/Applet --remove org.biglinux.appsmenu

kbuildsycoca6 --noincremental
systemctl --user restart plasma-plasmashell.service
```

Switch the panel back to Kickoff (**Show Alternatives…**) before removing the package, otherwise the panel is left with an empty menu slot.

---

## Development

Run the plasmoid without installing it:

```bash
plasmoidviewer -a "$PWD/usr/share/plasma/plasmoids/org.biglinux.appsmenu"
```

For a larger test window:

```bash
plasmoidviewer -a "$PWD/usr/share/plasma/plasmoids/org.biglinux.appsmenu" --width 800 --height 600
```

Validate the active QML files:

```bash
qmllint -I usr/share/plasma/plasmoids/org.biglinux.appsmenu/contents/ui \
  $(rg --files usr/share/plasma/plasmoids/org.biglinux.appsmenu | rg '\.qml$' | rg -v '/Header\.qml$')
```

`Header.qml` and `contents/ui/code/tools.js` use legacy Plasma-specific syntax that the standalone `qmllint` shipped by some distributions cannot parse; they are covered by the runtime check above.

Validate the package metadata:

```bash
kpackagetool6 --appstream-metainfo usr/share/plasma/plasmoids/org.biglinux.appsmenu
```

Sync a working copy into the user plasmoid directory while iterating:

```bash
kpackagetool6 --type Plasma/Applet --upgrade usr/share/plasma/plasmoids/org.biglinux.appsmenu
systemctl --user restart plasma-plasmashell.service
```

New visible strings must go through `i18n()` / `i18nc()` / `i18np()`. Translations are handled by the GitHub workflow in [`.github/workflows/`](.github/workflows/).

---

## Troubleshooting

**Applications or categories look stale:**

```bash
kbuildsycoca6 --noincremental
systemctl --user restart plasma-plasmashell.service
```

**The launcher does not appear in *Add Widgets*:** confirm the files landed in `/usr/share/plasma/plasmoids/org.biglinux.appsmenu` (or `~/.local/share/plasma/plasmoids/`), that `metadata.json` is readable, then run `kbuildsycoca6 --noincremental` and restart the shell.

**Inspect runtime messages:**

```bash
journalctl --user -f -u plasma-plasmashell.service | grep -i appsmenu
```

**QML warnings are silent:** BigLinux ships a `QT_LOGGING_RULES` entry in `/etc/environment` that mutes QML output. To debug, run the plasmoid through `plasmoidviewer` with the rules cleared:

```bash
QT_LOGGING_RULES= plasmoidviewer -a "$PWD/usr/share/plasma/plasmoids/org.biglinux.appsmenu"
```

**Sensor gadgets (CPU, GPU, memory, drives, network) show no data:** make sure `ksystemstats` is installed and running:

```bash
systemctl --user status plasma-ksystemstats.service
```

When reporting a problem at <https://github.com/ruscher/plasma-appsmenu-biglinux/issues>, include the Plasma version (`plasmashell --version`), the page you were on, the steps to reproduce, and any QML or Plasma warnings.

---

## Privacy and offline use

The launcher works entirely offline. Only the online gadgets you add reach the network, each to its own public provider: Open-Meteo (weather, plus an IP-based location lookup when you do not set a city), Frankfurter (currency), TheSportsDB (live scores), the RSS/Atom feeds you configure, and ZenQuotes if you turn on the online source of the Quote of the Day gadget. No account, API key or telemetry is involved; responses are cached locally in the applet configuration.

---

## Architecture

The project is a package-only Plasma plasmoid. Runtime code lives in:

```text
usr/share/plasma/plasmoids/org.biglinux.appsmenu/
├── metadata.json
└── contents/
    ├── config/                 # Plasma configuration schema and page
    └── ui/
        ├── main.qml            # Plasmoid root, Kicker models, compact representation
        ├── FullRepresentation.qml
        ├── Header.qml          # search, avatar, actions
        ├── Footer.qml          # tabs and power/session buttons
        ├── HomePage.qml
        ├── AllAppsPage.qml
        ├── InfoPage.qml
        ├── SearchResultsPage.qml
        ├── components/         # accessible views, drag & drop, power menu, onboarding
        ├── delegates/          # application delegates
        ├── gadgets/            # dashboard grid, gallery, registry and gadget items
        └── singletons/         # shared menu metrics and actions
```

The launcher uses Qt Quick, Plasma Components 3, Kirigami, the Kicker models and Plasma 6 services. There is no C++, Python, GTK, Node or Meson build step. More detail — runtime flow, models and compatibility constraints — is in [`docs/architecture.md`](docs/architecture.md).

---

## History

The project follows the KDE Kickoff lineage and has been adapted for BigLinux since 2021. Recent work introduced the Home/Apps/Places/Info navigation, safer StackView lifecycle handling (fixing a plasmashell crash), accessible application delegates, tab and category memory, and the modular Info gadget dashboard — while preserving the existing Plasma launcher models and user configuration keys.

## Credits

The launcher includes code and design contributions from the KDE Kickoff project (Martin Gräßlin, Mikel Johnson and the KDE community) and from BigLinux contributors (Bruno Gonçalves, Rafael Ruscher). Project credits and contact details are kept in the package metadata together with the original upstream notices.

## License

GPL-2.0-or-later. See the SPDX notices in the source files and in `metadata.json`.
