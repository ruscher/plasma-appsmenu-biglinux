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
    readonly property string unit: host.cfg.unit || "c"
    property var wx: null
    property bool busy: false

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
        host.accent = "#0ea5e9"
        host.settingsComponent = settings
        const cached = host.cacheGet("forecast")
        if (cached && cached.v) { wx = cached.v; host.subtitle = wx.location || "" }
        refreshIfStale()
    }

    Connections {
        target: weather.host
        function onActiveChanged() { if (weather.host.active) weather.refreshIfStale() }
        function onCfgChanged() { weather.refresh(true) }
    }
    Timer {
        interval: weather.refreshMs
        running: weather.host.active
        repeat: true
        onTriggered: weather.refreshIfStale()
    }

    function refreshIfStale() {
        const cached = host.cacheGet("forecast")
        if (!Net.cacheFresh(cached, refreshMs)) refresh(false)
    }
    function refresh(force) {
        if (busy) return
        busy = true; host.loading = true; host.clearError()
        const done = (err, fc, loc) => {
            busy = false; host.loading = false
            if (err) {
                host.offline = true
                if (!wx) host.setError(err === "notfound" ? i18n("Location not found. Check the settings.") : i18n("Could not load the weather (%1).", Net.describeError(err)))
                return
            }
            host.offline = false
            fc.location = loc.name
            wx = fc
            host.subtitle = loc.name
            host.cacheSet("forecast", Net.cacheEntry(fc))
        }
        const run = loc => Provider.forecast(loc.lat, loc.lon, unit, (err, fc) => done(err, fc, loc))
        if (!autoLocate && host.cfg.query && host.cfg.query.length) {
            if (host.cfg.lat !== undefined && host.cfg.lon !== undefined && host.cfg.resolvedFor === host.cfg.query) {
                run({ lat: host.cfg.lat, lon: host.cfg.lon, name: host.cfg.name || host.cfg.query })
            } else {
                Provider.geocode(host.cfg.query, (err, loc) => {
                    if (err) return done(err, null, null)
                    const c = Object.assign({}, host.cfg, { lat: loc.lat, lon: loc.lon, name: loc.name, resolvedFor: host.cfg.query })
                    host.saveCfg(c)  // triggers onCfgChanged → will run with the cached coords
                })
            }
        } else {
            const cachedLoc = host.cacheGet("iploc")
            if (Net.cacheFresh(cachedLoc, 6 * 60 * 60 * 1000)) run(cachedLoc.v)
            else Provider.locateByIp((err, loc) => {
                if (err) return done(err, null, null)
                host.cacheSet("iploc", Net.cacheEntry(loc))
                run(loc)
            })
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
