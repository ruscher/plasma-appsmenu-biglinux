/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Memory gadget — RAM ring + swap bar (KSystemStats sensors).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import ".." as G

Item {
    id: mem
    required property var host
    readonly property int rate: 3000

    Sensors.Sensor { id: used;   sensorId: "memory/physical/used";  enabled: mem.host.active; updateRateLimit: mem.rate }
    Sensors.Sensor { id: total;  sensorId: "memory/physical/total"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: pct;    sensorId: "memory/physical/usedPercent"; enabled: mem.host.active; updateRateLimit: mem.rate }
    Sensors.Sensor { id: sUsed;  sensorId: "memory/swap/used";  enabled: mem.host.active; updateRateLimit: mem.rate }
    Sensors.Sensor { id: sTotal; sensorId: "memory/swap/total"; enabled: true; updateRateLimit: 60000 }

    readonly property real usage: Number(pct.value) || 0
    readonly property real swapFrac: Number(sTotal.value) > 0 ? (Number(sUsed.value) || 0) / Number(sTotal.value) : 0

    Component.onCompleted: host.accent = "#3b82f6"
    function gb(v) { const n = Number(v) || 0; return (n / (1024 * 1024 * 1024)).toLocaleString(Qt.locale(), "f", 1) }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        G.RingGauge {
            Layout.preferredWidth: mem.host.compact ? Math.min(parent.width * 0.5, parent.height) : Math.min(parent.height, Kirigami.Units.gridUnit * 7)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            value: mem.usage / 100
            color: mem.usage > 90 ? Kirigami.Theme.negativeTextColor : mem.host.accent
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                PC3.Label {
                    text: Math.round(mem.usage) + "%"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (mem.host.compact ? 1.4 : 1.8)
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }
                PC3.Label { text: i18nc("ram label", "RAM"); font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9; opacity: 0.55; Layout.alignment: Qt.AlignHCenter }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: i18nc("used / total GB", "%1 / %2 GB", mem.gb(used.value), mem.gb(total.value))
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.Label {
                text: i18n("%1 GB free", mem.gb((Number(total.value) || 0) - (Number(used.value) || 0)))
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Item { Layout.fillHeight: true }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: Number(sTotal.value) > 0
                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label { text: i18nc("swap label", "Swap"); font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.7 }
                    Item { Layout.fillWidth: true }
                    PC3.Label { text: i18nc("used / total GB", "%1 / %2 GB", mem.gb(sUsed.value), mem.gb(sTotal.value)); font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.7 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 6; radius: 3
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                    Rectangle {
                        width: parent.width * Math.min(1, mem.swapFrac)
                        height: parent.height; radius: parent.radius
                        color: Kirigami.Theme.neutralTextColor
                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                    }
                }
            }
            PC3.Label {
                visible: Number(sTotal.value) <= 0
                text: i18n("No swap configured")
                opacity: 0.5
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }
}
