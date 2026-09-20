/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Network gadget — live download/upload graph (KSystemStats network/all).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import ".." as G

Item {
    id: net
    required property var host
    readonly property int rate: 2000
    readonly property int historyLen: 45

    Sensors.Sensor { id: down; sensorId: "network/all/download"; enabled: net.host.active; updateRateLimit: net.rate }
    Sensors.Sensor { id: up;   sensorId: "network/all/upload";   enabled: net.host.active; updateRateLimit: net.rate }
    Sensors.Sensor { id: totalDown; sensorId: "network/all/totalDownload"; enabled: net.host.active && !net.host.compact; updateRateLimit: 10000 }

    property var downHist: []
    property var upHist: []

    Component.onCompleted: host.accent = "#8b5cf6"

    Timer {
        interval: net.rate
        running: net.host.active
        repeat: true
        onTriggered: {
            downHist = downHist.concat([Number(down.value) || 0]).slice(-net.historyLen)
            upHist = upHist.concat([Number(up.value) || 0]).slice(-net.historyLen)
        }
    }
    function speed(v) {
        const n = Number(v) || 0
        if (n >= 1024 * 1024) return (n / 1024 / 1024).toLocaleString(Qt.locale(), "f", 1) + " MB/s"
        if (n >= 1024) return Math.round(n / 1024) + " KB/s"
        return Math.round(n) + " B/s"
    }
    function size(v) {
        const n = Number(v) || 0
        if (n >= 1024 * 1024 * 1024) return (n / 1024 / 1024 / 1024).toLocaleString(Qt.locale(), "f", 2) + " GB"
        return (n / 1024 / 1024).toLocaleString(Qt.locale(), "f", 0) + " MB"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            component Stat : RowLayout {
                property string icon: ""
                property string value: ""
                property color tint: "white"
                spacing: 3
                Kirigami.Icon { source: icon; color: tint; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                PC3.Label { text: value; font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold; font.family: "monospace" }
            }
            Stat { icon: "arrow-down"; value: net.speed(down.value); tint: net.host.accent }
            Stat { icon: "arrow-up"; value: net.speed(up.value); tint: Kirigami.Theme.positiveTextColor }
            Item { Layout.fillWidth: true }
            PC3.Label {
                visible: !net.host.compact && Number(totalDown.value) > 0
                text: i18n("↓ %1 total", net.size(totalDown.value))
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9; opacity: 0.55
            }
        }
        G.Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            values: net.downHist
            values2: net.upHist
            color: net.host.accent
            color2: Kirigami.Theme.positiveTextColor
        }
    }
}
