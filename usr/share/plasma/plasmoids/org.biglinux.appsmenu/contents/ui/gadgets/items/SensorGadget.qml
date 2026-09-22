/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Sensor — every temperature the machine reports, grouped by the hardware
    it belongs to, each with the kind of device it is, its reading, a plain
    verdict and a bar. The visual language is Drive Info's: an icon, a name,
    a line of detail and a thin bar, so the two cards read as one product.

    Discovery is shared (SensorCatalog) and classifies by unit, never by
    name. Subscription goes through SensorSubscription, which is where the
    "no values until you open Configure" bug was fixed — see the note in
    that file.

    A sensor that has not answered yet keeps its row and says so. It is not
    removed, because "no reading this second" and "this hardware is gone"
    are different things and only the second should change the list.

    Thresholds: when KSystemStats carries the hardware's own critical limit
    (`max`), that limit is used and the lower bands are derived from it.
    Otherwise conservative defaults per kind of hardware apply — a 70 °C
    NVMe is not a 70 °C hard disk.

    cfg: { hidden: [ids the user turned off], shown: [default-hidden ids the
    user turned on] } — two lists so that new hardware appears by default
    and a sensor that is temporarily absent keeps its setting.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
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
    readonly property bool multipleGroups: {
        const g = {}
        for (const s of shown) g[s.group] = true
        return Object.keys(g).length > 1
    }

    Component.onCompleted: {
        host.accentColor = "#f43f5e"
        host.settingsComponent = settings
    }

    G.SensorSubscription {
        id: live
        ids: sensor.shownIds
        active: sensor.host.active
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
    /*  0 cold · 1 cool · 2 fine · 3 warm · 4 hot · 5 critical, −1 unknown */
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
    function bandText(b) {
        switch (b) {
        case 0: return i18nc("@info temperature status", "Cold")
        case 1: return i18nc("@info temperature status", "Cool")
        case 2: return i18nc("@info temperature status", "Normal temperature")
        case 3: return i18nc("@info temperature status", "Warning: moderately high temperature")
        case 4: return i18nc("@info temperature status", "Caution: high temperature")
        case 5: return i18nc("@info temperature status", "Caution: extremely high temperature")
        }
        return i18nc("@info a sensor that has not reported a reading yet", "Waiting for a reading")
    }
    /*  The same verdicts cut down to what a row or a 1x1 title bar shows. */
    function shortBandText(b) {
        switch (b) {
        case 0: return i18nc("@info short temperature status", "Cold")
        case 1: return i18nc("@info short temperature status", "Cool")
        case 2: return i18nc("@info short temperature status", "Normal")
        case 3: return i18nc("@info short temperature status", "Moderately high")
        case 4: return i18nc("@info short temperature status", "High temperature")
        case 5: return i18nc("@info short temperature status", "Extremely high")
        }
        return i18nc("@info a sensor that has not reported a reading yet", "No reading yet")
    }
    function fraction(v, l) {
        const lo = l.cool - 20, hi = l.crit
        return Math.max(0.02, Math.min(1, (v - lo) / Math.max(1, hi - lo)))
    }
    function formatTemp(v) { return i18nc("@info temperature in Celsius", "%1°C", Number(v).toLocaleString(Qt.locale(), "f", 0)) }

    readonly property int worstBand: {
        let w = -1
        for (const s of shown) {
            const b = band(live.values[s.id], limits(s))
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
        spacing: Kirigami.Units.smallSpacing
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        reuseItems: true
        visible: sensor.shown.length > 0

        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            id: bar
            policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }
        /*  The bar floats over the content, and these rows end in a
            right-aligned number; leave it room rather than let it sit on
            top of the reading. */
        readonly property real inset: bar.policy === QQC2.ScrollBar.AsNeeded ? Kirigami.Units.gridUnit * 0.7 : 0

        /*  Grouping only earns its line when there is more than one group. */
        section.property: sensor.multipleGroups ? "group" : ""
        section.criteria: ViewSection.FullString
        section.delegate: PC3.Label {
            required property string section
            width: list.width
            text: section
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            font.weight: Font.DemiBold
            opacity: 0.55
            elide: Text.ElideRight
            topPadding: sensor.compact ? 1 : Kirigami.Units.smallSpacing
            Accessible.role: Accessible.Heading
        }

        delegate: ColumnLayout {
            id: row
            required property var modelData
            readonly property var lim: sensor.limits(modelData)
            readonly property var value: live.values[modelData.id]
            readonly property bool waiting: value === undefined
            readonly property int b: sensor.band(value, lim)
            readonly property color tone: b >= 0 ? sensor.bandColours[b] : Kirigami.Theme.disabledTextColor

            width: list.width - list.inset
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: G.SensorCatalog.iconFor(row.modelData.category)
                    fallback: "computer-symbolic"
                    isMask: true
                    color: Kirigami.Theme.textColor
                    opacity: row.waiting ? 0.45 : 0.85
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }

                PC3.Label {
                    text: row.modelData.shortName
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                PC3.Label {
                    text: row.waiting ? "—" : sensor.formatTemp(row.value)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                    color: row.b >= 4 ? row.tone : Kirigami.Theme.textColor
                    opacity: row.waiting ? 0.5 : 1
                }
            }

            /*  The verdict in words, so colour is never the only channel.
                On a 1x1 card the row is two lines and this one is dropped;
                the tooltip and the accessible name still carry it. */
            PC3.Label {
                visible: !sensor.compact
                text: row.waiting ? i18nc("@info a sensor that has not reported a reading yet", "Waiting for a reading")
                                  : sensor.shortBandText(row.b)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Kirigami.Units.smallSpacing * 0.8)
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

                Rectangle {
                    width: row.waiting ? 0 : Math.max(2, parent.width * sensor.fraction(row.value, row.lim))
                    height: parent.height
                    radius: parent.radius
                    color: row.tone
                    Behavior on width { enabled: Kirigami.Units.longDuration > 0; NumberAnimation { duration: Kirigami.Units.longDuration } }
                }
            }

            PC3.ToolTip.text: row.modelData.name + "\n" + (row.waiting
                    ? i18nc("@info a sensor that has not reported a reading yet", "Waiting for a reading")
                    : sensor.bandText(row.b))
                + (row.modelData.max > 0 ? "\n" + i18nc("@info:tooltip", "Critical: %1", sensor.formatTemp(row.modelData.max)) : "")
            PC3.ToolTip.visible: rowHover.hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            HoverHandler { id: rowHover }

            Accessible.role: Accessible.ListItem
            Accessible.name: row.waiting
                ? i18nc("@info accessible sensor row with no reading", "%1, waiting for a reading", row.modelData.name)
                : i18nc("@info accessible sensor row: name, temperature, status", "%1, %2, %3", row.modelData.name, sensor.formatTemp(row.value), sensor.bandText(row.b))
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.largeSpacing * 2
        visible: G.SensorCatalog.ready && sensor.shown.length === 0
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: Qt.resolvedUrl("../icons/temperature-symbolic.svg")
            isMask: true
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.45
        }
        PC3.Label {
            text: sensor.all.length === 0
                ? i18n("No temperature sensors detected")
                : i18n("All sensors are hidden. Choose some in the settings.")
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
            PC3.Label { text: i18n("Show these temperatures"); font.weight: Font.DemiBold }
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
                        if (checked) {
                            if (sensor.defaultHidden(modelData.id)) on.push(modelData.id)
                        } else {
                            hid.push(modelData.id)
                        }
                        host.saveCfg(Object.assign({}, host.cfg, { hidden: hid, shown: on }))
                    }
                }
            }
            PC3.Label {
                visible: sensor.all.length === 0
                text: i18n("No temperature sensors were found on this computer.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
        }
    }
}
