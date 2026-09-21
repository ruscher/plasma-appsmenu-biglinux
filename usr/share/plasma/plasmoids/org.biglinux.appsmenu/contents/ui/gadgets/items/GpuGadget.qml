/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GPU Meter — usage, temperature, VRAM, power and clock of every GPU
    (KSystemStats sensors; works for AMD, Intel and NVIDIA — no sudo needed).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import ".." as G

Item {
    id: gpu
    required property var host
    readonly property int rate: 2000

    property var gpuIds: ["gpu/gpu0"]
    Sensors.SensorTreeModel { id: tree }
    function discover() {
        const out = []
        try {
            const root = tree.index(-1, -1)
            for (let i = 0; i < tree.rowCount(root); i++) {
                const cat = tree.index(i, 0, root)
                if (tree.canFetchMore(cat)) tree.fetchMore(cat)
                for (let j = 0; j < tree.rowCount(cat); j++) {
                    const dev = tree.index(j, 0, cat)
                    if (tree.canFetchMore(dev)) tree.fetchMore(dev)
                    for (let k = 0; k < tree.rowCount(dev); k++) {
                        const id = String(tree.data(tree.index(k, 0, dev), Sensors.SensorTreeModel.SensorId) || "")
                        const m = /^(gpu\/gpu\d+)\/usage$/.exec(id)
                        if (m && out.indexOf(m[1]) < 0) out.push(m[1])
                    }
                }
            }
        } catch (e) {}
        if (out.length && (out.length !== gpuIds.length || out.some((v, i) => v !== gpuIds[i]))) gpuIds = out.sort()
    }
    Connections { target: tree; function onRowsInserted() { rediscover.restart() } function onModelReset() { rediscover.restart() } }
    Timer { id: rediscover; interval: 500; onTriggered: gpu.discover() }
    Timer { interval: 1500; running: true; onTriggered: gpu.discover() }

    Component.onCompleted: host.accentColor = "#f43f5e"
    Binding { target: gpu.host; property: "subtitle"; value: gpu.gpuIds.length > 1 ? i18np("%1 GPU", "%1 GPUs", gpu.gpuIds.length) : "" }

    function gb(v) { return ((Number(v) || 0) / 1024 / 1024 / 1024).toLocaleString(Qt.locale(), "f", 1) }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        /*  Every card the system reports. A machine with three would have had
            one silently dropped by `slice(0, 2)`; the list scrolls instead. */
        ListView {
            id: cardList

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: gpu.gpuIds
            clip: true
            spacing: Kirigami.Units.largeSpacing
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            QQC2.ScrollBar.vertical: PC3.ScrollBar {
                policy: cardList.contentHeight > cardList.height ? QQC2.ScrollBar.AsNeeded
                                                                 : QQC2.ScrollBar.AlwaysOff
            }

            delegate: RowLayout {
                id: card
                required property string modelData
                required property int index
                width: cardList.width
                height: Math.max(implicitHeight, cardList.height / Math.max(1, cardList.count))
                spacing: Kirigami.Units.largeSpacing

                Sensors.Sensor { id: usage; sensorId: card.modelData + "/usage"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
                Sensors.Sensor { id: temp;  sensorId: card.modelData + "/temperature"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
                Sensors.Sensor { id: power; sensorId: card.modelData + "/power"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
                Sensors.Sensor { id: clock; sensorId: card.modelData + "/coreFrequency"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
                Sensors.Sensor { id: vused; sensorId: card.modelData + "/usedVram"; enabled: gpu.host.active; updateRateLimit: gpu.rate * 2 }
                Sensors.Sensor { id: vtotal; sensorId: card.modelData + "/totalVram"; enabled: true; updateRateLimit: 60000 }
                Sensors.Sensor { id: gname; sensorId: card.modelData + "/name"; enabled: true; updateRateLimit: 60000 }
                readonly property real use: Number(usage.value) || 0
                readonly property real vramFrac: Number(vtotal.value) > 0 ? (Number(vused.value) || 0) / Number(vtotal.value) : 0

                G.RingGauge {
                    readonly property int shown: gpu.host.compact ? 1 : Math.min(2, gpu.gpuIds.length)
                    Layout.preferredWidth: Math.min(gpu.height, gpu.host.compact ? gpu.width * 0.48 : Math.min(Kirigami.Units.gridUnit * 6.5, gpu.width / shown * 0.42))
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignVCenter
                    value: card.use / 100
                    color: card.use > 90 ? Kirigami.Theme.negativeTextColor : gpu.host.accent
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        PC3.Label {
                            text: Math.round(card.use) + "%"
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * (gpu.host.compact ? 1.4 : 1.6)
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        PC3.Label { text: i18nc("gpu label", "GPU %1", card.index); font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9; opacity: 0.55; Layout.alignment: Qt.AlignHCenter }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2
                    PC3.Label {
                        text: String(gname.value || "")
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    component Chip : RowLayout {
                        property string icon: ""
                        property string label: ""
                        visible: label.length > 0
                        spacing: 3
                        Kirigami.Icon { source: icon; Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.8; Layout.preferredHeight: Layout.preferredWidth; opacity: 0.7 }
                        PC3.Label { text: label; font.pointSize: Kirigami.Theme.smallFont.pointSize; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Chip { icon: "temperature-normal"; label: Number(temp.value) > 0 ? Math.round(Number(temp.value)) + " °C" : "" }
                    Chip { icon: "battery-charging-symbolic"; label: Number(power.value) > 0 ? Number(power.value).toLocaleString(Qt.locale(), "f", 0) + " W" : "" }
                    Chip { icon: "speedometer"; label: Number(clock.value) > 0 ? Math.round(Number(clock.value)) + " MHz" : "" }
                    // VRAM bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        visible: Number(vtotal.value) > 0
                        PC3.Label {
                            text: i18nc("vram used/total", "VRAM %1 / %2 GB", gpu.gb(vused.value), gpu.gb(vtotal.value))
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.7
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 5; radius: 2.5
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                            Rectangle {
                                width: parent.width * Math.min(1, card.vramFrac)
                                height: parent.height; radius: parent.radius
                                color: gpu.host.accent
                                Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
