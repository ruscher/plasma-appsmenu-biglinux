/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetRegistry — catalogue of available Info gadgets.

    Each entry: id, name, description, icon, category, sizes (supported
    "colsxrows"), defaultSize, source (relative to gadgets/items/),
    online (needs network), multiple (may be added more than once), and an
    optional iconFallback.

    Icons are symbolic wherever a symbolic glyph exists, so the title bars
    and the Add dialog read as one family. Names were checked on disk: the
    BigLinux theme (bigicons-papient) declares only hicolor as a parent, but
    KIconLoader adds Breeze as an implicit fallback, so a Breeze-only name
    still renders; `iconFallback` covers a theme that has neither.
*/

pragma Singleton

import QtQuick 2.15

QtObject {
    id: registry

    readonly property var categories: [
        { id: "time",    name: i18nc("gadget category", "Time & Planning") },
        { id: "system",  name: i18nc("gadget category", "System") },
        { id: "online",  name: i18nc("gadget category", "Online") },
        { id: "tools",   name: i18nc("gadget category", "Tools & Fun") },
    ]

    readonly property var gadgets: [
        { id: "clock",        name: i18n("Clock"),           icon: "clock-symbolic",        iconFallback: "clock", category: "time",
          description: i18n("Analog or digital clock with date and seconds"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "ClockGadget.qml", online: false, multiple: true },
        { id: "calendar",     name: i18n("Calendar"),        icon: "office-calendar-symbolic", iconFallback: "view-calendar-symbolic", category: "time",
          description: i18n("Month view with today highlighted"),
          sizes: ["1x2", "2x2", "1x1"], defaultSize: "1x2", source: "CalendarGadget.qml", online: false, multiple: false },
        { id: "countdown",    name: i18n("Countdown"),       icon: "chronometer-symbolic",  iconFallback: "chronometer", category: "time",
          description: i18n("Days, hours and minutes until your events"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "CountdownGadget.qml", online: false, multiple: true },
        { id: "notes",        name: i18n("Notes"),           icon: "note-symbolic",         iconFallback: "note", category: "tools",
          description: i18n("Quick sticky notes, saved automatically"),
          sizes: ["1x1", "2x1", "1x2", "2x2"], defaultSize: "1x1", source: "NotesGadget.qml", online: false, multiple: true },
        { id: "weather",      name: i18n("Weather"),         icon: "weather-few-clouds-symbolic", iconFallback: "weather-few-clouds", category: "online",
          description: i18n("Current conditions and forecast (Open-Meteo, no API key)"),
          sizes: ["1x1", "2x1", "2x2"], defaultSize: "2x1", source: "WeatherGadget.qml", online: true, multiple: true },
        { id: "cpu",          name: i18n("CPU Meter"),       icon: "cpu-symbolic",          iconFallback: "cpu", category: "system",
          description: i18n("Usage of every core, frequency and temperature"),
          sizes: ["1x1", "2x1", "2x2"], defaultSize: "1x1", source: "CpuGadget.qml", online: false, multiple: false },
        { id: "gpu",          name: i18n("GPU Meter"),       icon: "cpu-symbolic",          iconFallback: "cpu", category: "system",
          description: i18n("Usage, temperature, VRAM and power of your graphics cards"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "GpuGadget.qml", online: false, multiple: false },
        { id: "memory",       name: i18n("Memory"),          icon: "memory-symbolic",       iconFallback: "memory", category: "system",
          description: i18n("RAM and swap usage"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "MemoryGadget.qml", online: false, multiple: false },
        { id: "sensors",      name: i18nc("@title gadget showing hardware temperatures", "Sensor"), icon: "temperature-normal-symbolic", iconFallback: "temperature-normal", category: "system",
          description: i18n("Temperatures of the CPU, GPU, drives and board"),
          sizes: ["1x1", "2x1", "1x2", "2x2"], defaultSize: "1x2", source: "SensorGadget.qml", online: false, multiple: false },
        { id: "battery",      name: i18n("Battery"),         icon: "battery-good-symbolic", iconFallback: "battery-good", category: "system",
          description: i18n("Charge level, state and time remaining"),
          sizes: ["1x1"], defaultSize: "1x1", source: "BatteryGadget.qml", online: false, multiple: false },
        { id: "drives",       name: i18n("Drive Info"),      icon: "drive-harddisk-symbolic", iconFallback: "drive-harddisk", category: "system",
          description: i18n("Capacity and free space of your partitions"),
          sizes: ["1x1", "2x1", "1x2"], defaultSize: "1x1", source: "DriveInfoGadget.qml", online: false, multiple: false },
        { id: "drivemonitor", name: i18n("Drive Monitor"),   icon: "drive-harddisk-symbolic", category: "system",
          description: i18n("Live read/write activity graph"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "DriveMonitorGadget.qml", online: false, multiple: false },
        { id: "network",      name: i18n("Network"),         icon: "network-wired-symbolic", iconFallback: "network-wired", category: "system",
          description: i18n("Live download/upload graph"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "NetworkGadget.qml", online: false, multiple: false },
        { id: "sysinfo",      name: i18n("System Info"),     icon: "computer-symbolic",     iconFallback: "computer", category: "system",
          description: i18n("Host, kernel, uptime, CPU and GPU"),
          sizes: ["1x1", "2x1"], defaultSize: "2x1", source: "SystemInfoGadget.qml", online: false, multiple: false },
        { id: "media",        name: i18n("Media Player"),    icon: "multimedia-player-symbolic", iconFallback: "multimedia-player", category: "tools",
          description: i18n("Now playing with controls (MPRIS)"),
          sizes: ["1x1", "2x1"], defaultSize: "2x1", source: "MediaGadget.qml", online: false, multiple: false },
        { id: "clipboard",    name: i18n("Clipboard"),       icon: "edit-paste-symbolic",   iconFallback: "edit-paste", category: "tools",
          description: i18n("Recent clipboard entries (Klipper)"),
          sizes: ["1x1", "2x1", "1x2"], defaultSize: "1x1", source: "ClipboardGadget.qml", online: false, multiple: false },
        { id: "quicklinks",   name: i18n("Quick Links"),     icon: "emblem-symbolic-link",   category: "tools",
          description: i18n("Your favorite apps and sites, one tap away"),
          sizes: ["1x1", "2x1", "2x2"], defaultSize: "1x1", source: "QuickLinksGadget.qml", online: false, multiple: true },
        { id: "rss",          name: i18n("News Feed"),       icon: "news-subscribe-symbolic", iconFallback: "news-subscribe", category: "online",
          description: i18n("Headlines with pictures from any RSS/Atom feed"),
          sizes: ["1x1", "2x1", "2x2", "1x2"], defaultSize: "2x1", source: "RssGadget.qml", online: true, multiple: true },
        { id: "currency",     name: i18n("Currency"),        icon: "view-currency-list-symbolic", iconFallback: "view-currency-list", category: "online",
          description: i18n("Exchange rates (European Central Bank via Frankfurter)"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "CurrencyGadget.qml", online: true, multiple: true },
        { id: "sports",       name: i18n("Live Scores"),     icon: "games-highscores-symbolic", iconFallback: "games-highscores", category: "online",
          description: i18n("Football, basketball and more — live scores and fixtures"),
          sizes: ["1x1", "2x1", "2x2"], defaultSize: "2x1", source: "SportsGadget.qml", online: true, multiple: true },
        { id: "quotes",       name: i18n("Quote of the Day"), icon: "format-text-blockquote-symbolic", iconFallback: "format-text-blockquote", category: "tools",
          description: i18n("A little inspiration, every day"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "QuotesGadget.qml", online: false, multiple: false },
        { id: "tips",         name: i18n("Tips"),            icon: "help-hint-symbolic",    iconFallback: "help-hint", category: "tools",
          description: i18n("Handy BigLinux and KDE tricks"),
          sizes: ["1x1", "2x1"], defaultSize: "1x1", source: "TipsGadget.qml", online: false, multiple: false },
        { id: "gallery",      name: i18n("Gallery"),         icon: "folder-pictures-symbolic", iconFallback: "folder-pictures", category: "tools",
          description: i18n("Slideshow of a folder of pictures"),
          sizes: ["1x1", "2x1", "2x2"], defaultSize: "1x1", source: "GalleryGadget.qml", online: false, multiple: true },
        /*  One entry for all five games. "puzzle" was the 2048-only gadget
            and is migrated to this on load, keeping its position and its high
            score. Every game has a compact layout, so 1x1 is offered.  */
        { id: "games",        name: i18n("Games"),           icon: "applications-games-symbolic", iconFallback: "applications-games", category: "tools",
          description: i18n("2048, Minesweeper, Sudoku, Flow Connect and Block Puzzle"),
          sizes: ["1x1", "1x2", "2x1", "2x2"], defaultSize: "1x1", source: "GamesGadget.qml", online: false, multiple: false },
    ]

    function byId(id) {
        for (let i = 0; i < gadgets.length; i++) {
            if (gadgets[i].id === id)
                return gadgets[i]
        }
        return null
    }

    // Layout used on first run / after "Reset". Sized for 3 columns.
    readonly property var defaultLayout: [
        { id: "clock",        size: "1x1" },
        { id: "weather",      size: "2x1" },
        { id: "calendar",     size: "1x2" },
        { id: "cpu",          size: "1x1" },
        { id: "gpu",          size: "1x1" },
        { id: "memory",       size: "1x1" },
        { id: "quicklinks",   size: "2x1" },
        { id: "drivemonitor", size: "1x1" },
        { id: "rss",          size: "2x1" },
        { id: "media",        size: "1x1" },
        { id: "notes",        size: "1x1" },
        { id: "drives",       size: "1x1" },
        { id: "quotes",       size: "1x1" },
        { id: "sysinfo",      size: "2x1" },
        { id: "countdown",    size: "1x1" },
        { id: "currency",     size: "1x1" },
        { id: "sports",       size: "2x1" },
        { id: "tips",         size: "1x1" },
        { id: "gallery",      size: "1x1" },
    ]
}
