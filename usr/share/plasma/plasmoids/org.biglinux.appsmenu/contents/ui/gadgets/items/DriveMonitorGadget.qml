/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Drive Monitor — live read/write throughput graph (KSystemStats disk/all).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import ".." as G

Item {
    id: dm
    required property var host
    readonly property int rate: 2000
    readonly property int historyLen: 45

    Sensors.Sensor { id: rd; sensorId: "disk/all/read";  enabled: dm.host.active; updateRateLimit: dm.rate }
    Sensors.Sensor { id: wr; sensorId: "disk/all/write"; enabled: dm.host.active; updateRateLimit: dm.rate }

    property var readHist: []
    property var writeHist: []

    Component.onCompleted: host.accentColor = "#f97316"

    Timer {
        interval: dm.rate
        running: dm.host.active
        repeat: true
        onTriggered: {
            const r = Number(rd.value) || 0, w = Number(wr.value) || 0
            readHist = readHist.concat([r]).slice(-dm.historyLen)
            writeHist = writeHist.concat([w]).slice(-dm.historyLen)
        }
    }
    function speed(v) {
        const n = Number(v) || 0
        if (n >= 1024 * 1024) return (n / 1024 / 1024).toLocaleString(Qt.locale(), "f", 1) + " MB/s"
        if (n >= 1024) return Math.round(n / 1024) + " KB/s"
        return Math.round(n) + " B/s"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            component Stat : RowLayout {
                property string label: ""
                property string value: ""
                property color dot: "white"
                spacing: 4
                Rectangle { width: 8; height: 8; radius: 4; color: dot }
                PC3.Label { text: label; font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.6 }
                PC3.Label { text: value; font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold; font.family: "monospace" }
            }
            Stat { label: i18nc("disk read", "Read"); value: dm.speed(rd.value); dot: dm.host.accent }
            Stat { label: i18nc("disk write", "Write"); value: dm.speed(wr.value); dot: Kirigami.Theme.highlightColor }
            Item { Layout.fillWidth: true }
        }
        G.Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            values: dm.readHist
            values2: dm.writeHist
            color: dm.host.accent
            color2: Kirigami.Theme.highlightColor
        }
    }
}
