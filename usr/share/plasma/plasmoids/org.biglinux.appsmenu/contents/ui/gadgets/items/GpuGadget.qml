/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GPU Meter — usage, temperature, VRAM, power and clock of every GPU
    (KSystemStats sensors; works for AMD, Intel and NVIDIA — no sudo needed).

    The layout picks its own density from the height each card actually
    gets, not from a fixed idea of how many GPUs there are. One card keeps
    the roomy layout it always had; two on a machine with two GPUs fit
    completely, without scrolling, because the second density drops the
    clock line and puts temperature and power on one row; three or four
    tighten again into a single line of figures. Only when even the tightest
    layout does not fit does the list scroll — a rare eight-GPU box should
    not cost everyone else their comfortable layout.

    Cards are named by what the driver reports (`gpu/gpuN/name`), never by
    position: "gpu0 is the integrated one" is not true in general.
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

    property var gpuIds: []
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
    Timer { interval: 1200; running: true; onTriggered: gpu.discover() }

    Component.onCompleted: host.accentColor = "#f43f5e"
    Binding { target: gpu.host; property: "subtitle"; value: gpu.gpuIds.length > 1 ? i18np("%1 GPU", "%1 GPUs", gpu.gpuIds.length) : "" }

    function gb(v) { return ((Number(v) || 0) / 1024 / 1024 / 1024).toLocaleString(Qt.locale(), "f", 1) }

    /*  0 roomy · 1 compact · 2 dense. Chosen from the height one card gets
        when they all share the card evenly, so the same rule covers "two
        GPUs on a tall card" and "one GPU on a 1x1". */
    readonly property int count: Math.max(1, gpuIds.length)
    readonly property real slotHeight: (height - Kirigami.Units.largeSpacing * (count - 1)) / count
    readonly property int density: slotHeight >= Kirigami.Units.gridUnit * 7.5 ? 0
                                 : slotHeight >= Kirigami.Units.gridUnit * 4.0 ? 1 : 2
    /*  What a card needs at that density; below this the list scrolls. */
    readonly property real minCardHeight: density === 0 ? Kirigami.Units.gridUnit * 7.5
                                        : density === 1 ? Kirigami.Units.gridUnit * 4.0
                                        : Kirigami.Units.gridUnit * 2.6

    ListView {
        id: cardList
        anchors.fill: parent
        model: gpu.gpuIds
        clip: true
        spacing: Kirigami.Units.largeSpacing
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        visible: gpu.gpuIds.length > 0

        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            policy: cardList.contentHeight > cardList.height ? QQC2.ScrollBar.AsNeeded
                                                             : QQC2.ScrollBar.AlwaysOff
        }

        delegate: RowLayout {
            id: card
            required property string modelData
            required property int index

            width: cardList.width
            height: Math.max(gpu.minCardHeight, gpu.slotHeight)
            spacing: gpu.density === 0 ? Kirigami.Units.largeSpacing : Kirigami.Units.smallSpacing * 2

            Sensors.Sensor { id: usage; sensorId: card.modelData + "/usage"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
            Sensors.Sensor { id: temp;  sensorId: card.modelData + "/temperature"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
            Sensors.Sensor { id: power; sensorId: card.modelData + "/power"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
            /*  amdgpu answers `power` with nothing and reports the board's
                draw as `power1` (PPT) instead; Intel and NVIDIA fill the
                first one. Whichever has a figure is the figure. */
            Sensors.Sensor { id: powerAlt; sensorId: card.modelData + "/power1"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
            Sensors.Sensor { id: clock; sensorId: card.modelData + "/coreFrequency"; enabled: gpu.host.active; updateRateLimit: gpu.rate }
            Sensors.Sensor { id: vused; sensorId: card.modelData + "/usedVram"; enabled: gpu.host.active; updateRateLimit: gpu.rate * 2 }
            Sensors.Sensor { id: vtotal; sensorId: card.modelData + "/totalVram"; enabled: true; updateRateLimit: 60000 }
            Sensors.Sensor { id: gname; sensorId: card.modelData + "/name"; enabled: true; updateRateLimit: 60000 }

            readonly property real use: Number(usage.value) || 0
            readonly property real vramFrac: Number(vtotal.value) > 0 ? (Number(vused.value) || 0) / Number(vtotal.value) : 0
            readonly property string title: String(gname.value || "") .length
                ? String(gname.value) : i18nc("@label a graphics card whose name is not known yet", "GPU %1", card.index)
            readonly property string tempText: Number(temp.value) > 0 ? i18nc("@info temperature in Celsius", "%1°C", Math.round(Number(temp.value))) : ""
            readonly property real watts: Number(power.value) > 0 ? Number(power.value) : (Number(powerAlt.value) || 0)
            readonly property string powerText: watts > 0 ? i18nc("@info power draw in watts", "%1 W", watts.toLocaleString(Qt.locale(), "f", 0)) : ""
            readonly property string clockText: Number(clock.value) > 0 ? i18nc("@info clock frequency", "%1 MHz", Math.round(Number(clock.value))) : ""
            readonly property string vramText: Number(vtotal.value) > 0
                ? i18nc("vram used/total", "VRAM %1 / %2 GB", gpu.gb(vused.value), gpu.gb(vtotal.value)) : ""
            /*  Figures that do not have their own line at this density are
                still reachable, just not shouted. */
            readonly property string extras: [tempText, powerText, clockText, vramText].filter(t => t.length).join(" · ")

            G.RingGauge {
                readonly property real side: gpu.density === 0
                    ? Math.min(card.height, gpu.host.compact ? gpu.width * 0.48 : Math.min(Kirigami.Units.gridUnit * 6.5, gpu.width * 0.42))
                    : (gpu.density === 1 ? Kirigami.Units.gridUnit * 3.4 : Kirigami.Units.gridUnit * 2.4)
                Layout.preferredWidth: Math.min(side, card.height)
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter
                value: card.use / 100
                color: card.use > 90 ? Kirigami.Theme.negativeTextColor : gpu.host.accent

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    PC3.Label {
                        text: Math.round(card.use) + "%"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                            * (gpu.density === 0 ? (gpu.host.compact ? 1.4 : 1.6) : (gpu.density === 1 ? 1.0 : 0.85))
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignHCenter
                    }
                    /*  The card's own name is right beside it at every other
                        density; the ring only needs to say which one it is
                        when there is room to spare. */
                    PC3.Label {
                        visible: gpu.density === 0
                        text: i18nc("gpu label", "GPU %1", card.index)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                        opacity: 0.55
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: gpu.density === 2 ? 1 : 2

                PC3.Label {
                    text: card.title
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    maximumLineCount: gpu.density === 0 ? 2 : 1
                    wrapMode: gpu.density === 0 ? Text.Wrap : Text.NoWrap
                    Layout.fillWidth: true
                }

                component Chip : RowLayout {
                    property string icon: ""
                    property string label: ""
                    visible: label.length > 0
                    spacing: 3
                    Kirigami.Icon {
                        source: icon
                        isMask: true
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.8
                        Layout.preferredHeight: Layout.preferredWidth
                        opacity: 0.7
                    }
                    PC3.Label { text: label; font.pointSize: Kirigami.Theme.smallFont.pointSize; elide: Text.ElideRight; Layout.fillWidth: true }
                }

                // ── roomy: one line per figure ──
                Chip { visible: gpu.density === 0 && label.length > 0; icon: Qt.resolvedUrl("../icons/temperature-symbolic.svg"); label: card.tempText }
                Chip { visible: gpu.density === 0 && label.length > 0; icon: "flash-symbolic"; label: card.powerText }
                Chip { visible: gpu.density === 0 && label.length > 0; icon: "speedometer-symbolic"; label: card.clockText }

                // ── compact: temperature and power share a line ──
                PC3.Label {
                    visible: gpu.density === 1
                    text: [card.tempText, card.powerText, card.clockText].filter(t => t.length).join(" · ")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.85
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // ── dense: everything on one line ──
                PC3.Label {
                    visible: gpu.density === 2
                    text: card.extras
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                    opacity: 0.8
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // ── VRAM: its own label up to compact, bar at every density ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    visible: Number(vtotal.value) > 0
                    PC3.Label {
                        visible: gpu.density < 2
                        text: card.vramText
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                        opacity: 0.7
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: gpu.density === 2 ? 4 : 5
                        radius: height / 2
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                        Rectangle {
                            width: parent.width * Math.min(1, card.vramFrac)
                            height: parent.height; radius: parent.radius
                            color: gpu.host.accent
                            Behavior on width { enabled: Kirigami.Units.longDuration > 0; NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Item { visible: gpu.density === 0; Layout.fillHeight: true }
            }

            /*  Nothing is hidden silently: whatever the density leaves out
                is in here, with the card's full name. */
            PC3.ToolTip.text: card.title + (card.extras.length ? "\n" + card.extras : "")
            PC3.ToolTip.visible: cardHover.hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            HoverHandler { id: cardHover }

            Accessible.role: Accessible.ListItem
            Accessible.name: i18nc("@info accessible gpu row: name, usage, details", "%1, %2% used. %3",
                                   card.title, Math.round(card.use), card.extras)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.largeSpacing * 2
        visible: gpu.gpuIds.length === 0
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: Qt.resolvedUrl("../icons/gpu-symbolic.svg")
            isMask: true
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.45
        }
        PC3.Label {
            text: i18n("No graphics card reported")
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.fillWidth: true
        }
    }
}
