/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Drive Info — mounted volumes with used/free space (KSystemStats).
    Volumes are discovered from the sensor tree ("disk/<id>/total").
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors

Item {
    id: drives
    required property var host

    property var volumeIds: []    // "disk/<id>"

    Component.onCompleted: host.accentColor = "#f97316"
    Binding { target: drives.host; property: "subtitle"; value: drives.volumeIds.length ? i18np("%1 volume", "%1 volumes", drives.volumeIds.length) : "" }

    Sensors.SensorTreeModel { id: tree }
    // Walk root → category → device → leaf sensors; only leaves carry a
    // SensorId and the leaf level is loaded lazily (fetchMore).
    function discover() {
        const out = []
        const seen = {}
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
                        const m = /^(disk\/(?!all\/)[^/]+)\/total$/.exec(id)
                        if (m && !seen[m[1]]) { seen[m[1]] = true; out.push(m[1]) }
                    }
                }
            }
        } catch (e) {}
        if (out.length !== volumeIds.length || out.some((v, i) => v !== volumeIds[i])) volumeIds = out
    }
    Connections {
        target: tree
        function onRowsInserted() { rediscover.restart() }
        function onModelReset() { rediscover.restart() }
    }
    Timer { id: rediscover; interval: 600; onTriggered: drives.discover() }
    Timer { interval: 2000; running: true; repeat: false; onTriggered: drives.discover() }

    function gb(v) { const n = Number(v) || 0; return n >= 1024 * 1024 * 1024 * 1024 ? (n / 1024 / 1024 / 1024 / 1024).toLocaleString(Qt.locale(), "f", 2) + " TB" : (n / 1024 / 1024 / 1024).toLocaleString(Qt.locale(), "f", 1) + " GB" }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: Kirigami.Units.smallSpacing
        model: drives.volumeIds
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: row
            required property string modelData
            width: list.width
            readonly property bool isVolume: Number(total.value) > 0
            visible: isVolume
            height: isVolume ? col.implicitHeight + Kirigami.Units.smallSpacing : 0
            Sensors.Sensor { id: name; sensorId: row.modelData + "/name"; enabled: true; updateRateLimit: 60000 }
            Sensors.Sensor { id: total; sensorId: row.modelData + "/total"; enabled: drives.host.active; updateRateLimit: 30000 }
            Sensors.Sensor { id: used; sensorId: row.modelData + "/used"; enabled: drives.host.active; updateRateLimit: 30000 }
            Sensors.Sensor { id: free; sensorId: row.modelData + "/free"; enabled: drives.host.active; updateRateLimit: 30000 }
            readonly property real frac: Number(total.value) > 0 ? (Number(used.value) || 0) / Number(total.value) : 0
            ColumnLayout {
                id: col
                width: parent.width
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Icon {
                        source: String(name.value || "").indexOf("/") === 0 && String(name.value) === "/" ? "drive-harddisk-root" : "drive-harddisk"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.8
                    }
                    PC3.Label {
                        text: String(name.value || row.modelData.split("/")[1])
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: Math.round(row.frac * 100) + "%"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 6; radius: 3
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                    Rectangle {
                        width: parent.width * Math.min(1, row.frac)
                        height: parent.height; radius: parent.radius
                        color: row.frac > 0.9 ? Kirigami.Theme.negativeTextColor : (row.frac > 0.75 ? Kirigami.Theme.neutralTextColor : drives.host.accent)
                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                    }
                }
                PC3.Label {
                    text: i18n("%1 free of %2", drives.gb(free.value), drives.gb(total.value))
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.55
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: drives.volumeIds.length === 0
        PC3.BusyIndicator { running: visible; Layout.alignment: Qt.AlignHCenter }
        PC3.Label { text: i18n("Looking for drives…"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize }
    }
}
