/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Weather gadget (Open-Meteo). cfg: { auto: bool, query, lat, lon, name, unit }
    Caches the last forecast; when offline shows it with an offline badge.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import "../lib/WeatherOpenMeteo.js" as Provider
import "../lib/GadgetNet.js" as Net

Item {
    id: weather
    required property var host

    readonly property int refreshMs: 20 * 60 * 1000

    readonly property bool autoLocate: host.cfg.auto !== undefined ? host.cfg.auto : true
    readonly property string unit: host.cfg.unit === "f" ? "f" : "c"
    readonly property string queryText: (host.cfg.query || "").trim()

    /*  What decides *which* forecast to show: the chosen location and the
        unit. Everything else in cfg — the resolved coordinates and display
        name — is a result of a request, so writing it back must not start a
        new one. That is why the refresh trigger below compares this key
        instead of reacting to cfgChanged directly: GadgetHost emits
        cfgChanged twice for a single save (once locally, once through the
        model round trip), and the resolved coordinates add a third.  */
    readonly property string requestKey: (autoLocate ? "auto" : "city:" + queryText.toLowerCase()) + "|" + unit

    /*  requestKey of the request that is in flight or already on screen. */
    property string servedKey: ""
    /*  Bumped by every request. A reply carrying a stale id belongs to a
        request the user has already replaced, so it is dropped instead of
        overwriting newer data.  */
    property int requestId: 0
    property bool busy: false
    property var wx: null

    /*  A location that cannot be resolved never fills the cache, so without
        this the gadget would fire a fresh request every time it scrolls back
        into the viewport. Automatic refreshes keep a floor between attempts;
        an explicit refresh from the settings page is never delayed.  */
    readonly property int minRetryMs: 60 * 1000
    property double lastAttemptAt: 0

    function t(key) {
        // translatable condition names (keys come from the provider)
        const map = {
            "Clear sky": i18n("Clear sky"), "Mainly clear": i18n("Mainly clear"), "Partly cloudy": i18n("Partly cloudy"),
            "Overcast": i18n("Overcast"), "Fog": i18n("Fog"), "Drizzle": i18n("Drizzle"), "Rain": i18n("Rain"),
            "Snow": i18n("Snow"), "Rain showers": i18n("Rain showers"), "Snow showers": i18n("Snow showers"),
            "Thunderstorm": i18n("Thunderstorm"), "Thunderstorm with hail": i18n("Thunderstorm with hail"), "Unknown": i18n("Unknown")
        }
        return map[key] || key
    }

    Component.onCompleted: {
        host.accentColor = "#0ea5e9"
        host.settingsComponent = settings
        servedKey = requestKey
        const cached = cachedForecast()
        if (cached) {
            show(cached.v)
        }
        refreshIfStale()
    }

    Connections {
        target: weather.host
        function onActiveChanged() { if (weather.host.active) weather.refreshIfStale() }
        function onCfgChanged() { weather.handleCfgChanged() }
    }
    Timer {
        interval: weather.refreshMs
        running: weather.host.active
        repeat: true
        onTriggered: weather.refreshIfStale()
    }

    /*  The gadget cache is one JSON object persisted into the plasmoid config
        and it is never pruned, so the forecast lives in a single slot rather
        than one slot per city. The payload records the scope it was fetched
        for and that scope is checked on every read: a mismatch is a miss, so
        a Celsius forecast is never shown as Fahrenheit and Brasília's is
        never shown for São Paulo.  */
    function cachedForecast() {
        const e = host.cacheGet("forecast")
        if (!e || !e.v) {
            return null
        }
        const v = e.v
        if (v.scopeKey !== requestKey || v.unitKey !== unit) {
            return null
        }
        /*  For a manually chosen city the coordinates must also match the ones
            currently resolved, in case the city was re-resolved since.  */
        if (!autoLocate && host.cfg.lat !== undefined
                && !(sameCoord(v.lat, host.cfg.lat) && sameCoord(v.lon, host.cfg.lon))) {
            return null
        }
        return e
    }

    function sameCoord(a, b) {
        return typeof a === "number" && typeof b === "number" && Math.abs(a - b) < 0.0001
    }

    function refreshIfStale() {
        if (Net.cacheFresh(cachedForecast(), refreshMs)) {
            return
        }
        if (busy || Date.now() - lastAttemptAt < minRetryMs) {
            return
        }
        refresh(false)
    }

    /*  A new request always supersedes whatever is in flight — there is no
        "already busy, give up" guard. The previous version returned from the
        geocoding branch without ever clearing `busy`, and the `if (busy)
        return` at the top then rejected every later refresh, so the gadget
        span forever and never showed the city the user had typed.  */
    function refresh(force) {
        const id = ++requestId
        servedKey = requestKey
        lastAttemptAt = Date.now()

        if (!force) {
            const cached = cachedForecast()
            if (Net.cacheFresh(cached, refreshMs)) {
                show(cached.v)
                return
            }
        }

        busy = true
        host.loading = true
        host.clearError()

        const run = loc => Provider.forecast(loc.lat, loc.lon, unit, (err, fc) => finish(id, err, fc, loc))

        if (autoLocate) {
            const cachedLoc = host.cacheGet("iploc")
            if (Net.cacheFresh(cachedLoc, 6 * 60 * 60 * 1000)) {
                run(cachedLoc.v)
            } else {
                Provider.locateByIp((err, loc) => {
                    if (id !== requestId) return
                    if (err) { finish(id, err, null, null); return }
                    host.cacheSet("iploc", Net.cacheEntry(loc))
                    run(loc)
                })
            }
            return
        }

        if (!queryText.length) {
            finish(id, "nocity", null, null)
            return
        }

        const c = host.cfg
        if (c.lat !== undefined && c.lon !== undefined && c.resolvedFor === queryText) {
            run({ lat: c.lat, lon: c.lon, name: c.name || queryText })
            return
        }

        Provider.geocode(queryText, (err, loc) => {
            if (id !== requestId) return
            if (err) { finish(id, err, null, null); return }
            /*  Remember the resolution so the next open skips the geocoding
                round trip. requestKey does not depend on these fields, so
                this save does not restart the request: we carry straight on
                with the coordinates we just received.  */
            host.saveCfg(Object.assign({}, host.cfg, {
                lat: loc.lat, lon: loc.lon, name: loc.name, resolvedFor: queryText
            }))
            run(loc)
        })
    }

    /*  The single exit point of a request: every path that ends one, success
        or failure, comes through here, so `busy` and `host.loading` can never
        be left stuck on.  */
    function finish(id, err, fc, loc) {
        if (id !== requestId) {
            return  // superseded; the newer request owns the state
        }
        busy = false
        host.loading = false

        if (err === "nocity") {
            host.setError(i18n("Type a city name in the settings."))
            return
        }
        if (err === "notfound") {
            /*  A typo is the user's to fix and says nothing about the network,
                so it is reported even when an older forecast is on screen.  */
            host.setError(autoLocate ? i18n("Could not determine your location.")
                                     : i18n("City not found. Check the spelling in the settings."))
            return
        }
        if (err) {
            host.offline = true
            if (!wx) {
                host.setError(i18n("Could not load the weather (%1).", Net.describeError(err)))
            }
            return
        }

        host.offline = false
        fc.location = loc.name
        fc.scopeKey = servedKey
        host.cacheSet("forecast", Net.cacheEntry(fc))
        show(fc)
    }

    function show(fc) {
        wx = fc
        host.subtitle = fc.location || ""
        host.clearError()
    }

    /*  cfgChanged fires more than once per settings change, so react to what
        actually changed rather than to the signal.  */
    function handleCfgChanged() {
        if (requestKey !== servedKey) {
            refresh(true)
            return
        }
        /*  Same key, but the settings page cleared `resolvedFor`: the user
            re-applied the same city, which is an explicit retry. `busy`
            filters out the duplicate emissions of a single save, which all
            arrive before any network reply.  */
        if (!autoLocate && queryText.length && host.cfg.resolvedFor !== queryText && !busy) {
            refresh(true)
        }
    }

    // ── UI ──
    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        visible: weather.wx !== null

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Item {
                Layout.preferredWidth: weather.host.compact ? weather.width * 0.42 : Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Layout.preferredWidth
                Kirigami.Icon {
                    id: bigIcon
                    anchors.fill: parent
                    source: weather.wx ? weather.wx.icon : "weather-none-available"
                    // gentle float animation
                    SequentialAnimation on anchors.verticalCenterOffset {
                        running: weather.host.active && Kirigami.Units.longDuration > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: -3; duration: 1800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 3; duration: 1800; easing.type: Easing.InOutSine }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    spacing: 2
                    PC3.Label {
                        text: weather.wx && weather.wx.temp !== undefined ? String(weather.wx.temp) : "--"
                        font.pointSize: weather.host.compact ? Kirigami.Theme.defaultFont.pointSize * 2.6 : Kirigami.Theme.defaultFont.pointSize * 3
                        font.weight: Font.Light
                    }
                    PC3.Label {
                        text: weather.wx && weather.wx.unit ? weather.wx.unit : ""
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                        opacity: 0.7
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Kirigami.Units.smallSpacing
                    }
                }
                PC3.Label {
                    text: weather.wx && weather.wx.text ? weather.t(weather.wx.text) : ""
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PC3.Label {
                    text: weather.wx && weather.wx.hi !== null && weather.wx.hi !== undefined
                        ? i18nc("high/low temperature", "H %1°  L %2°", weather.wx.hi, weather.wx.lo) : ""
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                PC3.Label {
                    visible: !weather.host.compact
                    text: weather.wx && weather.wx.feels !== undefined ? i18n("Feels like %1° · %2% humidity · wind %3 %4", weather.wx.feels, weather.wx.humidity, weather.wx.wind, weather.wx.windUnit) : ""
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Forecast strip (wide / tall)
        RowLayout {
            visible: !!(!weather.host.compact && weather.wx && weather.wx.daily)
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Repeater {
                model: weather.wx && weather.wx.daily ? weather.wx.daily.slice(1, weather.host.tall ? 5 : 5) : []
                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    PC3.Label {
                        text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                    Kirigami.Icon {
                        source: modelData.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.alignment: Qt.AlignHCenter
                    }
                    PC3.Label {
                        text: modelData.hi + "° <font color='" + Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5) + "'>" + modelData.lo + "°</font>"
                        textFormat: Text.RichText
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // First-load placeholder
    ColumnLayout {
        anchors.centerIn: parent
        visible: weather.wx === null && weather.host.errorText.length === 0
        PC3.BusyIndicator { running: weather.busy; Layout.alignment: Qt.AlignHCenter }
        PC3.Label { text: i18n("Fetching weather…"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize }
    }

    // ── settings ──
    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.largeSpacing
            // RadioButtons in one FormLayout are siblings → they must be grouped
            // explicitly or "Fahrenheit" would uncheck the location choice.
            QQC2.ButtonGroup { id: locGroup }
            QQC2.ButtonGroup { id: unitGroup }
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.RadioButton {
                    id: autoRadio
                    QQC2.ButtonGroup.group: locGroup
                    Kirigami.FormData.label: i18n("Location:")
                    text: i18n("Detect from my internet connection (approximate)")
                    checked: host.cfg.auto !== undefined ? host.cfg.auto : true
                    onToggled: if (checked) host.setCfg("auto", true)
                }
                QQC2.RadioButton {
                    id: manualRadio
                    QQC2.ButtonGroup.group: locGroup
                    text: i18n("City:")
                    checked: host.cfg.auto === false
                    onToggled: if (checked) host.setCfg("auto", false)
                }
                RowLayout {
                    enabled: manualRadio.checked
                    QQC2.TextField {
                        id: cityField
                        Layout.fillWidth: true
                        placeholderText: i18n("e.g. São Paulo, Lisboa, Berlin")
                        text: host.cfg.query || ""
                        onAccepted: host.saveCfg(Object.assign({}, host.cfg, { auto: false, query: text, resolvedFor: "" }))
                    }
                    QQC2.Button {
                        text: i18n("Apply")
                        onClicked: host.saveCfg(Object.assign({}, host.cfg, { auto: false, query: cityField.text, resolvedFor: "" }))
                    }
                }
                PC3.Label {
                    visible: host.cfg.name && host.cfg.auto === false
                    text: i18n("Resolved: %1", host.cfg.name || "")
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                QQC2.RadioButton {
                    QQC2.ButtonGroup.group: unitGroup
                    Kirigami.FormData.label: i18n("Units:")
                    text: i18n("Celsius")
                    checked: (host.cfg.unit || "c") === "c"
                    onToggled: if (checked) host.setCfg("unit", "c")
                }
                QQC2.RadioButton {
                    QQC2.ButtonGroup.group: unitGroup
                    text: i18n("Fahrenheit")
                    checked: host.cfg.unit === "f"
                    onToggled: if (checked) host.setCfg("unit", "f")
                }
            }
            PC3.Label {
                text: i18n("Data by Open-Meteo.com (no account needed). Only your approximate location is sent.")
                opacity: 0.6
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
        }
    }
}
