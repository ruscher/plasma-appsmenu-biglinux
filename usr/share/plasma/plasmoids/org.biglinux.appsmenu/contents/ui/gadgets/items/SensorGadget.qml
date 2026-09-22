/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Sensor — every temperature the machine reports, as small thermometers
    with a plain-language status. Discovery is shared (SensorCatalog); this
    gadget subscribes only to the sensors it shows, and only while on screen.

    Thresholds: when KSystemStats carries the hardware's own critical limit
    (`max`), that limit is used and the lower bands are derived from it.
    Otherwise conservative defaults per kind of hardware apply — a 70 °C
    NVMe is not a 70 °C hard disk. Both are documented in
    docs/gadgets-stage2/08-sensor-gadget.md.

    cfg: { hidden: [ids the user turned off], shown: [default-hidden ids the
    user turned on] } — two lists so that new hardware appears by default
    and a sensor that is temporarily absent keeps its setting.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import ".." as G

Item {
    id: sensor
    required property var host

    readonly property bool compact: host.compact
    readonly property var all: G.SensorCatalog.temperatures
    readonly property var hidden: host.cfg.hidden || []
    readonly property var forcedOn: host.cfg.shown || []

    /*  Per-core readings are hidden by default: on AMD every core reports
        the package figure, sixteen identical rows; the average is shown
        instead. Anyone who wants the cores can turn them on.  */
    function defaultHidden(id) {
        return /^cpu\/cpu\d+\//.test(id) || /^cpu\/all\/(maximum|minimum)Temperature$/.test(id)
    }
    function isShown(id) {
        if (forcedOn.indexOf(id) !== -1) return true
        if (hidden.indexOf(id) !== -1) return false
        return !defaultHidden(id)
    }
    readonly property var shown: all.filter(s => isShown(s.id))
    readonly property var shownIds: shown.map(s => s.id)

    Component.onCompleted: {
        host.accentColor = "#f43f5e"
        host.settingsComponent = settings
    }

    // ── live values: one subscription for all shown sensors ──
    property var values: ({})
    Sensors.SensorDataModel {
        id: live
        sensors: sensor.shownIds
        enabled: sensor.host.active && sensor.shownIds.length > 0
        updateRateLimit: 2000
        onDataChanged: sensor.pull()
        onSensorsChanged: sensor.pull()
    }
    function pull() {
        const v = {}
        for (let c = 0; c < live.columnCount(); c++) {
            const idx = live.index(0, c)
            const id = String(live.data(idx, Sensors.SensorDataModel.SensorId) || "")
            const val = live.data(idx, Sensors.SensorDataModel.Value)
            if (id.length && val !== undefined && val !== null && !isNaN(Number(val))) {
                v[id] = Number(val)
            }
        }
        values = v
    }

    // ── thresholds ──
    /*  Per kind of hardware, in °C: below `cool` is cool, below `normal` is
        fine, below `warm` is moderately high, below `hot` is high, above it
        critical. The CPU band starts higher than the others because a
        desktop Ryzen or Core reports 65–75 °C under ordinary load, and
        their own limits (Tctl 95, TjMax 100) sit where `hot` does.  */
    readonly property var defaults: ({
        cpu:   { cool: 35, normal: 78, warm: 88, hot: 95 },
        gpu:   { cool: 35, normal: 65, warm: 80, hot: 95 },
        nvme:  { cool: 30, normal: 50, warm: 65, hot: 75 },
        hdd:   { cool: 25, normal: 40, warm: 50, hot: 60 },
        board: { cool: 30, normal: 45, warm: 60, hot: 75 }
    })
    function limits(s) {
        const d = defaults[s.category] || defaults.board
        if (s.max > 0) {
            /*  The hardware said where "too hot" is; the softer bands sit
                below it rather than at the generic defaults. */
            return { cool: d.cool, normal: Math.min(d.normal, s.max * 0.60), warm: Math.min(d.warm, s.max * 0.78), hot: s.max * 0.90, crit: s.max }
        }
        return { cool: d.cool, normal: d.normal, warm: d.warm, hot: d.hot, crit: d.hot + 10 }
    }
    /*  0 cold · 1 cool · 2 fine · 3 warm · 4 hot · 5 critical */
    function band(v, l) {
        if (v === undefined) return -1
        if (v < l.cool - 15) return 0
        if (v < l.cool) return 1
        if (v < l.normal) return 2
        if (v < l.warm) return 3
        if (v < l.hot) return 4
        return 5
    }
    readonly property var bandColours: ["#3b82f6", "#38bdf8", Kirigami.Theme.positiveTextColor, "#eab308", "#f97316", Kirigami.Theme.negativeTextColor]
    /*  Drawn as masks so the glyph takes the band colour rather than the
        theme's own status colouring.  */
    readonly property var bandIcons: ["temperature-cold-symbolic", "temperature-cold-symbolic", "temperature-normal-symbolic", "temperature-warm-symbolic", "dialog-warning-symbolic", "dialog-warning-symbolic"]
    function bandText(b) {
        switch (b) {
        case 0: return i18nc("@info temperature status", "Cold")
        case 1: return i18nc("@info temperature status", "Cool")
        case 2: return i18nc("@info temperature status", "Normal temperature")
        case 3: return i18nc("@info temperature status", "Warning: moderately high temperature")
        case 4: return i18nc("@info temperature status", "Caution: high temperature")
        case 5: return i18nc("@info temperature status", "Caution: extremely high temperature")
        }
        return ""
    }
    /*  The same verdicts cut down to what a 1x1 title bar can show.  */
    function shortBandText(b) {
        switch (b) {
        case 3: return i18nc("@info short temperature status", "Moderately high")
        case 4: return i18nc("@info short temperature status", "High temperature")
        case 5: return i18nc("@info short temperature status", "Extremely high")
        }
        return bandText(b)
    }
    function fraction(v, l) {
        const lo = l.cool - 20, hi = l.crit
        return Math.max(0.02, Math.min(1, (v - lo) / Math.max(1, hi - lo)))
    }
    function formatTemp(v) { return i18nc("@info temperature in Celsius", "%1°C", Number(v).toLocaleString(Qt.locale(), "f", 0)) }

    readonly property int worstBand: {
        let w = -1
        for (const s of shown) {
            const b = band(values[s.id], limits(s))
            if (b > w) w = b
        }
        return w
    }
    Binding {
        target: sensor.host
        property: "subtitle"
        value: !G.SensorCatalog.ready || sensor.shown.length === 0 || sensor.worstBand < 0 ? ""
             : sensor.worstBand <= 2 ? i18nc("@info overall temperature status", "Everything is fine!")
             : sensor.compact ? sensor.shortBandText(sensor.worstBand) : sensor.bandText(sensor.worstBand)
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: sensor.shown
        spacing: sensor.compact ? 1 : 2
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        reuseItems: true
        visible: sensor.shown.length > 0
        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }

        section.property: "group"
        section.criteria: ViewSection.FullString
        section.delegate: PC3.Label {
            required property string section
            width: list.width
            text: section
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            font.weight: Font.DemiBold
            opacity: 0.55
            elide: Text.ElideRight
            topPadding: sensor.compact ? 1 : 3
            Accessible.role: Accessible.Heading
        }

        delegate: Item {
            id: row
            required property var modelData
            readonly property var lim: sensor.limits(modelData)
            readonly property var value: sensor.values[modelData.id]
            readonly property int b: sensor.band(value, lim)
            readonly property color tone: b >= 0 ? sensor.bandColours[b] : Kirigami.Theme.disabledTextColor
            width: list.width
            height: sensor.compact ? Kirigami.Units.gridUnit * 1.45 : Kirigami.Units.gridUnit * 1.5

            /*  Two shapes from one layout: a single line when there is room,
                and on a 1x1 card the name and value above the bar, so the
                name gets the whole width instead of a third of it.  */
            GridLayout {
                anchors.fill: parent
                columns: sensor.compact ? 2 : 4
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: 1

                /*  The band glyph goes first when the row is a single line;
                    on a 1x1 card the band still shows in the bar colour, the
                    tooltip and the accessible name.  */
                Kirigami.Icon {
                    visible: !sensor.compact
                    source: row.b >= 0 ? sensor.bandIcons[row.b] : "temperature-normal-symbolic"
                    fallback: "temperature-normal"
                    isMask: true
                    color: row.tone
                    Layout.row: 0
                    Layout.column: 0
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PC3.Label {
                    text: row.modelData.shortName
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.row: 0
                    Layout.column: sensor.compact ? 0 : 1
                    Layout.fillWidth: sensor.compact
                    Layout.preferredWidth: sensor.compact ? -1 : row.width * 0.36
                    Layout.minimumWidth: 0
                }
                /*  The thermometer: a track and a fill in the band's colour. */
                Rectangle {
                    Layout.row: sensor.compact ? 1 : 0
                    Layout.column: sensor.compact ? 0 : 2
                    Layout.columnSpan: sensor.compact ? 2 : 1
                    Layout.fillWidth: true
                    Layout.preferredHeight: sensor.compact ? 4 : 7
                    radius: height / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                    Rectangle {
                        width: row.value === undefined ? 0 : parent.width * sensor.fraction(row.value, row.lim)
                        height: parent.height
                        radius: parent.radius
                        color: row.tone
                        Behavior on width { enabled: Kirigami.Units.longDuration > 0; NumberAnimation { duration: Kirigami.Units.longDuration } }
                    }
                }
                PC3.Label {
                    text: row.value === undefined ? "—" : sensor.formatTemp(row.value)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                    color: row.b >= 4 ? row.tone : Kirigami.Theme.textColor
                    Layout.row: 0
                    Layout.column: sensor.compact ? 1 : 3
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.3
                    horizontalAlignment: Text.AlignRight
                }
            }
            PC3.ToolTip.text: row.modelData.name + (row.b >= 0 ? "\n" + sensor.bandText(row.b) : "")
                + (row.modelData.max > 0 ? "\n" + i18nc("@info:tooltip", "Critical: %1", sensor.formatTemp(row.modelData.max)) : "")
            PC3.ToolTip.visible: rowHover.hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            HoverHandler { id: rowHover }
            Accessible.role: Accessible.ListItem
            Accessible.name: row.value === undefined
                ? row.modelData.name
                : i18nc("@info accessible sensor row: name, temperature, status", "%1, %2, %3", row.modelData.name, sensor.formatTemp(row.value), sensor.bandText(row.b))
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: G.SensorCatalog.ready && sensor.shown.length === 0
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: "temperature-normal-symbolic"
            fallback: "temperature-normal"
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.45
        }
        PC3.Label {
            text: sensor.all.length === 0 ? i18n("No temperature sensors detected") : i18n("All sensors are hidden. Choose some in the settings.")
            opacity: 0.7
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.fillWidth: true
        }
    }
    PC3.BusyIndicator {
        anchors.centerIn: parent
        running: !G.SensorCatalog.ready && sensor.host.active
        visible: running
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.smallSpacing
            PC3.Label { text: i18n("Show these sensors"); font.weight: Font.DemiBold }
            Repeater {
                model: sensor.all
                delegate: QQC2.CheckBox {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.group + " · " + modelData.shortName
                    checked: sensor.isShown(modelData.id)
                    onToggled: {
                        const hid = (host.cfg.hidden || []).filter(x => x !== modelData.id)
                        const on = (host.cfg.shown || []).filter(x => x !== modelData.id)
                        if (checked) { if (sensor.defaultHidden(modelData.id)) on.push(modelData.id) }
                        else { hid.push(modelData.id) }
                        host.saveCfg(Object.assign({}, host.cfg, { hidden: hid, shown: on }))
                    }
                }
            }
            PC3.Label {
                visible: sensor.all.length === 0
                text: i18n("No temperature sensors were found on this computer.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
            PC3.Label {
                text: i18n("Readings come from KSystemStats, the same source as System Monitor. Per-core CPU readings are off by default; they can be turned on above.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
        }
    }
}
