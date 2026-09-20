/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Battery gadget — charge ring, state and time remaining (powermanagement
    engine). Handles desktops without a battery gracefully.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import ".." as G

Item {
    id: bat
    required property var host

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
        interval: bat.host.active ? 10000 : 0
    }
    readonly property var battery: pm.data["Battery"] || {}
    readonly property bool hasBattery: battery["Has Battery"] === true
    readonly property int percent: Number(battery["Percent"]) || 0
    readonly property string chargeState: String(battery["State"] || "")
    readonly property bool charging: chargeState === "Charging"
    readonly property bool full: chargeState === "FullyCharged"
    readonly property real remainingMs: Number(battery["Remaining msec"]) || 0
    readonly property bool acPlugged: (pm.data["AC Adapter"] || {})["Plugged in"] === true

    Component.onCompleted: host.accent = "#84cc16"
    Binding { target: bat.host; property: "subtitle"; value: bat.hasBattery ? (bat.charging ? i18n("Charging") : (bat.full ? i18n("Full") : i18n("On battery"))) : "" }

    function remaining() {
        if (remainingMs <= 0) return ""
        const m = Math.round(remainingMs / 60000)
        const h = Math.floor(m / 60), mm = m % 60
        return h > 0 ? i18nc("time remaining", "%1h %2m", h, mm) : i18nc("time remaining", "%1m", mm)
    }
    readonly property color ringColor: percent <= 15 && !charging ? Kirigami.Theme.negativeTextColor : (percent <= 30 && !charging ? Kirigami.Theme.neutralTextColor : bat.host.accent)

    RowLayout {
        anchors.fill: parent
        visible: bat.hasBattery
        spacing: Kirigami.Units.largeSpacing
        G.RingGauge {
            Layout.preferredWidth: Math.min(parent.width * 0.5, parent.height)
            Layout.preferredHeight: Layout.preferredWidth
            value: bat.percent / 100
            color: bat.ringColor
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                PC3.Label {
                    text: bat.percent + "%"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }
                Kirigami.Icon {
                    visible: bat.charging
                    source: "battery-charging-symbolic"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.alignment: Qt.AlignHCenter
                    color: bat.ringColor
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            PC3.Label {
                text: bat.charging ? i18n("Charging") : (bat.full ? i18n("Fully charged") : i18n("Discharging"))
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.Label {
                visible: text.length > 0
                text: bat.remaining().length ? (bat.charging ? i18n("%1 to full", bat.remaining()) : i18n("%1 left", bat.remaining())) : ""
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            PC3.Label {
                text: bat.acPlugged ? i18n("Plugged in") : i18n("Unplugged")
                opacity: 0.55
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: !bat.hasBattery
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon { source: "battery-missing"; Layout.preferredWidth: Kirigami.Units.iconSizes.large; Layout.preferredHeight: Kirigami.Units.iconSizes.large; Layout.alignment: Qt.AlignHCenter; opacity: 0.45 }
        PC3.Label { text: i18n("No battery"); opacity: 0.7; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
        PC3.Label { text: bat.acPlugged ? i18n("Running on mains power") : ""; opacity: 0.5; font.pointSize: Kirigami.Theme.smallFont.pointSize; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
    }
}
