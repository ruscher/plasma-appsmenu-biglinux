/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Fans — every fan the machine reports, with its speed. A fan that turns
    is drawn turning; one at 0 RPM stands still; one that has not answered
    yet says so instead of pretending to be stopped.

    Which fans exist is decided by the sensor's unit (RPM), never by its
    name — see SensorCatalog. Values come through SensorSubscription, which
    is where the "no values until you open Configure" bug was fixed.

    The spin is one shared angle advanced by a single timer at about twelve
    frames a second, applied to each icon scaled by its speed, and it runs
    only while the card is on screen, only while some fan is actually
    turning, only if animations are on for the system, and only if the user
    has not switched it off. That keeps it far from the per-item 60 fps
    loops the edit mode used to have.

    Names are KSystemStats' own; nothing is guessed. cfg: { hidden: [ids],
    animate: bool }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
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
    readonly property bool multipleGroups: {
        const g = {}
        for (const f of shown) g[f.group] = true
        return Object.keys(g).length > 1
    }

    Component.onCompleted: {
        host.accentColor = "#0ea5e9"
        host.settingsComponent = settings
    }

    G.SensorSubscription {
        id: live
        ids: fans.shownIds
        active: fans.host.active
    }

    /*  −1 means "no reading yet", which is not the same as a fan that is
        stopped; 0 is a real, useful answer. */
    function rpmOf(id) {
        const v = live.values[id]
        return v === undefined ? -1 : Math.max(0, Math.round(v))
    }
    readonly property int spinning: shown.filter(f => rpmOf(f.id) > 0).length
    readonly property int reading: shown.filter(f => rpmOf(f.id) >= 0).length

    Binding {
        target: fans.host
        property: "subtitle"
        value: !G.SensorCatalog.ready || fans.shown.length === 0 ? ""
             : fans.reading === 0 ? i18nc("@info:status no fan has reported a speed yet", "Waiting for readings")
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
    function fraction(f) {
        const rpm = rpmOf(f.id)
        const top = f.max > 0 ? f.max : 2000
        return rpm <= 0 ? 0 : Math.max(0.02, Math.min(1, rpm / top))
    }
    function rpmText(rpm) {
        return rpm < 0 ? "—"
             : rpm === 0 ? i18nc("@info a fan that is not turning", "0 RPM")
             : i18nc("@info fan speed", "%1 RPM", rpm.toLocaleString(Qt.locale(), "f", 0))
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: fans.shown
        spacing: Kirigami.Units.smallSpacing
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        reuseItems: true
        visible: fans.shown.length > 0

        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            id: bar
            policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }
        /*  The bar floats over the content, and these rows end in a
            right-aligned number; leave it room rather than let it sit on
            top of the reading. */
        readonly property real inset: bar.policy === QQC2.ScrollBar.AsNeeded ? Kirigami.Units.gridUnit * 0.7 : 0

        section.property: fans.multipleGroups ? "group" : ""
        section.criteria: ViewSection.FullString
        section.delegate: PC3.Label {
            required property string section
            width: list.width
            text: section
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            font.weight: Font.DemiBold
            opacity: 0.55
            elide: Text.ElideRight
            topPadding: fans.compact ? 1 : Kirigami.Units.smallSpacing
            Accessible.role: Accessible.Heading
        }

        delegate: ColumnLayout {
            id: row
            required property var modelData
            readonly property int rpm: fans.rpmOf(modelData.id)
            readonly property bool turning: rpm > 0
            readonly property bool waiting: rpm < 0

            width: list.width - list.inset
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: Qt.resolvedUrl("../icons/fan-symbolic.svg")
                    isMask: true
                    color: row.turning ? fans.host.accent : Kirigami.Theme.textColor
                    opacity: row.turning ? 1 : (row.waiting ? 0.4 : 0.6)
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    rotation: row.turning && fans.animate ? fans.angle * fans.spinFactor(row.modelData) : 0
                    Accessible.ignored: true
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
                    text: fans.rpmText(row.rpm)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                    opacity: row.turning ? 1 : 0.6
                }
            }

            /*  Where the fan is, in words — the card it belongs to, or the
                chip that reports it. */
            PC3.Label {
                visible: !fans.compact
                text: row.waiting
                    ? i18nc("@info a fan that has not reported a speed yet", "Waiting for a reading")
                    : row.modelData.group
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            /*  Only when the hardware says what full speed is; otherwise a
                bar would be inventing a scale. */
            Rectangle {
                visible: row.modelData.max > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Kirigami.Units.smallSpacing * 0.8)
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

                Rectangle {
                    width: row.turning ? Math.max(2, parent.width * fans.fraction(row.modelData)) : 0
                    height: parent.height
                    radius: parent.radius
                    color: fans.host.accent
                    Behavior on width { enabled: Kirigami.Units.longDuration > 0; NumberAnimation { duration: Kirigami.Units.longDuration } }
                }
            }

            PC3.ToolTip.text: row.modelData.name + "\n" + row.modelData.id
                + (row.modelData.max > 0 ? "\n" + i18nc("@info:tooltip the speed the hardware reports as its maximum", "Maximum: %1", fans.rpmText(row.modelData.max)) : "")
            PC3.ToolTip.visible: rowHover.hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            HoverHandler { id: rowHover }

            Accessible.role: Accessible.ListItem
            Accessible.name: row.waiting
                ? i18nc("@info accessible fan row with no reading", "%1, waiting for a reading", row.modelData.name)
                : (row.turning ? i18nc("@info accessible fan row", "%1, %2 RPM", row.modelData.name, row.rpm)
                               : i18nc("@info accessible fan row", "%1, stopped", row.modelData.name))
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.largeSpacing * 2
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
                text: i18n("No fan sensors were found on this computer. Motherboard fans need a driver for the board's sensor chip, which this system does not load.")
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
