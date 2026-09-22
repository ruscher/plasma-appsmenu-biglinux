/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Fans — every fan the machine reports, with its speed. A fan that turns
    is drawn turning; one at 0 RPM stands still.

    The spin is one shared angle advanced by a single timer at about 12
    frames a second, applied to each icon scaled by its speed, and it runs
    only while the card is on screen, only while some fan is actually
    turning, only if animations are on for the system, and only if the user
    has not switched it off. That keeps it far from the per-item 60 fps
    loops the edit mode used to have.

    Names are KSystemStats' own; nothing is guessed. The technical id is in
    the tooltip. cfg: { hidden: [ids], animate: bool }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import ".." as G

Item {
    id: fans
    required property var host

    readonly property bool compact: host.compact
    readonly property var all: G.SensorCatalog.fans
    readonly property var hidden: host.cfg.hidden || []
    readonly property bool animate: host.cfg.animate !== false
    readonly property var shown: all.filter(f => hidden.indexOf(f.id) === -1)
    readonly property var shownIds: shown.map(f => f.id)

    Component.onCompleted: {
        host.accentColor = "#0ea5e9"
        host.settingsComponent = settings
    }

    property var values: ({})
    Sensors.SensorDataModel {
        id: live
        sensors: fans.shownIds
        enabled: fans.host.active && fans.shownIds.length > 0
        updateRateLimit: 2000
        onDataChanged: fans.pull()
        onSensorsChanged: fans.pull()
    }
    function pull() {
        const v = {}
        for (let c = 0; c < live.columnCount(); c++) {
            const idx = live.index(0, c)
            const id = String(live.data(idx, Sensors.SensorDataModel.SensorId) || "")
            const val = live.data(idx, Sensors.SensorDataModel.Value)
            if (id.length && val !== undefined && val !== null && !isNaN(Number(val))) v[id] = Number(val)
        }
        values = v
    }
    function rpmOf(id) { const v = values[id]; return v === undefined ? -1 : Math.max(0, Math.round(v)) }
    readonly property int spinning: shown.filter(f => rpmOf(f.id) > 0).length

    Binding {
        target: fans.host
        property: "subtitle"
        value: !G.SensorCatalog.ready || fans.shown.length === 0 ? ""
             : i18ncp("@info:status how many fans are turning", "%1 fan turning", "%1 fans turning", fans.spinning)
    }

    // ── the one shared spin ──
    property real angle: 0
    Timer {
        interval: 80
        repeat: true
        running: fans.host.active && fans.animate && fans.spinning > 0 && Kirigami.Units.longDuration > 0
        onTriggered: fans.angle = (fans.angle + 22) % 360
    }
    /*  Speed shows as spin rate: a slow fan turns visibly slower, without
        pretending to be a tachometer. */
    function spinFactor(f) {
        const rpm = rpmOf(f.id)
        if (rpm <= 0) return 0
        const top = f.max > 0 ? f.max : 2000
        return 0.35 + 0.65 * Math.min(1, rpm / top)
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: fans.shown
        spacing: fans.compact ? 1 : 3
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        reuseItems: true
        visible: fans.shown.length > 0
        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }

        delegate: Item {
            id: row
            required property var modelData
            readonly property int rpm: fans.rpmOf(modelData.id)
            readonly property bool turning: rpm > 0
            width: list.width
            height: fans.compact ? Kirigami.Units.gridUnit * 1.35 : Kirigami.Units.gridUnit * 1.9

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: Qt.resolvedUrl("../icons/fan-symbolic.svg")
                    isMask: true
                    color: row.turning ? fans.host.accent : Kirigami.Theme.disabledTextColor
                    Layout.preferredWidth: fans.compact ? Kirigami.Units.iconSizes.small : Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    rotation: row.turning && fans.animate ? fans.angle * fans.spinFactor(row.modelData) : 0
                    Accessible.ignored: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0
                    PC3.Label {
                        text: row.modelData.shortName
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        visible: !fans.compact
                        text: row.modelData.group
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        opacity: 0.55
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                PC3.Label {
                    text: row.rpm < 0 ? "—"
                        : (row.turning ? i18nc("@info fan speed", "%1 RPM", row.rpm.toLocaleString(Qt.locale(), "f", 0))
                                       : i18nc("@info a fan that is not turning", "0 RPM"))
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.family: "monospace"
                    opacity: row.turning ? 1 : 0.55
                }
            }
            PC3.ToolTip.text: row.modelData.name + "\n" + row.modelData.id
            PC3.ToolTip.visible: rowHover.hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            HoverHandler { id: rowHover }
            Accessible.role: Accessible.ListItem
            Accessible.name: row.rpm < 0 ? row.modelData.name
                : (row.turning ? i18nc("@info accessible fan row", "%1, %2 RPM", row.modelData.name, row.rpm)
                               : i18nc("@info accessible fan row", "%1, stopped", row.modelData.name))
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: G.SensorCatalog.ready && fans.shown.length === 0
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: Qt.resolvedUrl("../icons/fan-symbolic.svg")
            isMask: true
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.45
        }
        PC3.Label {
            text: fans.all.length === 0 ? i18n("No fan sensors detected") : i18n("All fans are hidden. Choose some in the settings.")
            opacity: 0.7
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.fillWidth: true
        }
    }
    PC3.BusyIndicator {
        anchors.centerIn: parent
        running: !G.SensorCatalog.ready && fans.host.active
        visible: running
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.smallSpacing
            PC3.Label { text: i18n("Show detected fans"); font.weight: Font.DemiBold }
            Repeater {
                model: fans.all
                delegate: QQC2.CheckBox {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.group + " · " + modelData.shortName
                    checked: fans.hidden.indexOf(modelData.id) === -1
                    onToggled: {
                        const hid = (host.cfg.hidden || []).filter(x => x !== modelData.id)
                        if (!checked) hid.push(modelData.id)
                        host.setCfg("hidden", hid)
                    }
                }
            }
            PC3.Label {
                visible: fans.all.length === 0
                text: i18n("No fan sensors were found on this computer.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
            QQC2.CheckBox {
                text: i18n("Animate fan icons")
                checked: fans.animate
                onToggled: host.setCfg("animate", checked)
            }
        }
    }
}
