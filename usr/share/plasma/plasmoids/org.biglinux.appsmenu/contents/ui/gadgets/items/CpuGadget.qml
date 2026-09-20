/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    All-CPU Meter — total usage ring, per-core bars, temperature, frequency.
    Data: KSystemStats sensors (no shell). Paused when the gadget is inactive.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support 2.0 as P5Support
import ".." as G

Item {
    id: cpu
    required property var host
    readonly property int rate: 2000

    Sensors.Sensor { id: total; sensorId: "cpu/all/usage"; enabled: cpu.host.active; updateRateLimit: cpu.rate }
    Sensors.Sensor { id: temp;  sensorId: "cpu/all/averageTemperature"; enabled: cpu.host.active; updateRateLimit: cpu.rate }
    Sensors.Sensor { id: freq;  sensorId: "cpu/all/averageFrequency"; enabled: cpu.host.active; updateRateLimit: cpu.rate }
    Sensors.Sensor { id: count; sensorId: "cpu/all/coreCount"; enabled: true; updateRateLimit: 60000 }
    // ksystemstats has no model-name sensor ("cpu0/name" is just "Core 1"):
    // read it once from /proc/cpuinfo.
    P5Support.DataSource {
        id: cpuInfo
        engine: "executable"
        connectedSources: ["grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]
        interval: 0
    }
    readonly property string modelName: {
        const d = cpuInfo.data[cpuInfo.connectedSources[0]]
        return d && d.stdout ? String(d.stdout).trim() : ""
    }

    // Logical CPUs: count "cpu/cpuN" nodes in the sensor tree (cpuCount is
    // sockets, coreCount is physical cores). Falls back to coreCount.
    property int discovered: 0
    readonly property int cores: discovered > 0 ? discovered : Math.max(0, Math.min(128, Math.round(Number(count.value) || 0)))
    Sensors.SensorTreeModel { id: tree }
    function discover() {
        let n = 0
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
                        if (/^cpu\/cpu\d+\/usage$/.test(id)) n++
                    }
                }
            }
        } catch (e) {}
        if (n > 0 && n !== discovered) discovered = Math.min(128, n)
    }
    Connections { target: tree; function onRowsInserted() { rediscover.restart() } function onModelReset() { rediscover.restart() } }
    Timer { id: rediscover; interval: 500; onTriggered: cpu.discover() }
    Timer { interval: 1500; running: true; onTriggered: cpu.discover() }
    readonly property real usage: Number(total.value) || 0
    readonly property color gaugeColor: usage > 85 ? Kirigami.Theme.negativeTextColor : (usage > 60 ? Kirigami.Theme.neutralTextColor : cpu.host.accent)

    Component.onCompleted: host.accent = "#22c55e"
    Binding { target: cpu.host; property: "subtitle"; value: cpu.cores > 0 ? i18np("%1 thread", "%1 threads", cpu.cores) : "" }

    // per-core sensors
    Repeater {
        id: coreSensors
        model: cpu.cores
        // Repeater delegates must be Items; the sensor lives inside
        delegate: Item {
            required property int index
            readonly property real value: Number(s.value) || 0
            Sensors.Sensor {
                id: s
                sensorId: "cpu/cpu" + index + "/usage"
                enabled: cpu.host.active
                updateRateLimit: cpu.rate
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // Ring
        G.RingGauge {
            Layout.preferredWidth: cpu.host.compact ? Math.min(parent.width * 0.5, parent.height) : Math.min(parent.height, Kirigami.Units.gridUnit * 7)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            value: cpu.usage / 100
            color: cpu.gaugeColor
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                PC3.Label {
                    text: Math.round(cpu.usage) + "%"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (cpu.host.compact ? 1.4 : 1.8)
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
                PC3.Label {
                    text: i18nc("cpu label under percentage", "CPU")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.55
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            // temp / freq chips (stacked when compact so they never overflow)
            GridLayout {
                Layout.fillWidth: true
                columns: cpu.host.compact ? 1 : 2
                rowSpacing: 2
                columnSpacing: Kirigami.Units.smallSpacing
                component Chip : Rectangle {
                    property string icon: ""
                    property string text: ""
                    visible: text.length > 0
                    implicitWidth: chipRow.implicitWidth + Kirigami.Units.smallSpacing * 2
                    implicitHeight: chipRow.implicitHeight + 4
                    radius: height / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 3
                        Kirigami.Icon { source: icon; Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.8; Layout.preferredHeight: Layout.preferredWidth; opacity: 0.7 }
                        PC3.Label { text: parent.parent.text; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                    }
                }
                Chip { icon: "temperature-normal"; text: temp.value !== undefined && Number(temp.value) > 0 ? Math.round(Number(temp.value)) + " °C" : "" }
                Chip { icon: "speedometer"; text: freq.value !== undefined && Number(freq.value) > 0 ? (Number(freq.value) >= 1000 ? (Number(freq.value) / 1000).toFixed(2) + " GHz" : Math.round(Number(freq.value)) + " MHz") : "" }
            }

            // per-core bars (wide/tall only)
            GridLayout {
                visible: !cpu.host.compact
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: cpu.host.tall ? 2 : Math.max(2, Math.ceil(cpu.cores / 4))
                rowSpacing: 2
                columnSpacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: cpu.cores
                    delegate: RowLayout {
                        required property int index
                        readonly property real v: coreSensors.itemAt(index) ? coreSensors.itemAt(index).value : 0
                        Layout.fillWidth: true
                        spacing: 3
                        PC3.Label { text: index; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8; opacity: 0.5; Layout.preferredWidth: Kirigami.Units.gridUnit * 0.9; horizontalAlignment: Text.AlignRight }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 5; radius: 2.5
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                            Rectangle {
                                width: parent.width * Math.min(1, parent.parent.v / 100)
                                height: parent.height; radius: parent.radius
                                color: parent.parent.v > 85 ? Kirigami.Theme.negativeTextColor : cpu.host.accent
                                Behavior on width { NumberAnimation { duration: cpu.rate * 0.6; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
            // compact: mini core dots
            Flow {
                visible: cpu.host.compact
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    model: cpu.host.compact ? cpu.cores : 0
                    delegate: Rectangle {
                        required property int index
                        width: 7; height: 7; radius: 2
                        readonly property real v: coreSensors.itemAt(index) ? coreSensors.itemAt(index).value : 0
                        color: Qt.rgba(cpu.host.accent.r, cpu.host.accent.g, cpu.host.accent.b, 0.15 + 0.85 * Math.min(1, v / 100))
                        Behavior on color { ColorAnimation { duration: 600 } }
                    }
                }
            }
            PC3.Label {
                visible: !cpu.host.compact
                text: cpu.modelName
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                opacity: 0.5
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
