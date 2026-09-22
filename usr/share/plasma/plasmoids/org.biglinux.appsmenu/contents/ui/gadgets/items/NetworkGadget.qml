/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Network gadget. Overview: download and upload as a legend with live
    values over a line chart (KSystemStats network/all, binary units —
    KiB/s, MiB/s — because the arithmetic is base 1024). Details: the
    connection that carries the default route, with its addresses, gateway
    and name servers, each with a copy button; that pane lives in
    network/NetworkDetails.qml and is loaded only while its tab is shown.

    A title action opens System Settings on the networking module through
    KCMLauncher, the same call Plasma's own network applet makes.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.kcmutils as KCMUtils
import ".." as G

Item {
    id: net
    required property var host
    readonly property int rate: 2000
    readonly property int historyLen: 45

    /*  0 = overview, 1 = details. Not persisted on purpose: the chart is
        what a glance at the card is for, the details are a visit.  */
    property int tab: 0

    Sensors.Sensor { id: down; sensorId: "network/all/download"; enabled: net.host.active; updateRateLimit: net.rate }
    Sensors.Sensor { id: up;   sensorId: "network/all/upload";   enabled: net.host.active; updateRateLimit: net.rate }
    Sensors.Sensor { id: totalDown; sensorId: "network/all/totalDownload"; enabled: net.host.active; updateRateLimit: 10000 }

    property var downHist: []
    property var upHist: []

    Component.onCompleted: {
        host.accentColor = "#8b5cf6"
        host.titleActions = [settingsAction]
    }
    QQC2.Action {
        id: settingsAction
        text: i18nc("@action:button", "Network settings")
        icon.name: "configure-symbolic"
        onTriggered: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
    }

    Binding {
        target: net.host
        property: "subtitle"
        value: Number(totalDown.value) > 0 ? i18nc("@info total downloaded since boot", "↓ %1", net.size(totalDown.value)) : ""
    }

    Timer {
        interval: net.rate
        running: net.host.active && net.tab === 0
        repeat: true
        onTriggered: {
            downHist = downHist.concat([Number(down.value) || 0]).slice(-net.historyLen)
            upHist = upHist.concat([Number(up.value) || 0]).slice(-net.historyLen)
        }
    }

    /*  Base-1024 throughout, and labelled as such: 1 KiB/s is 1024 B/s.  */
    function speed(v) {
        const n = Math.max(0, Number(v) || 0)
        if (n >= 1024 * 1024 * 1024) return i18nc("@info data rate", "%1 GiB/s", (n / 1073741824).toLocaleString(Qt.locale(), "f", 2))
        if (n >= 1024 * 1024) return i18nc("@info data rate", "%1 MiB/s", (n / 1048576).toLocaleString(Qt.locale(), "f", 1))
        if (n >= 1024) return i18nc("@info data rate", "%1 KiB/s", (n / 1024).toLocaleString(Qt.locale(), "f", n >= 10240 ? 0 : 1))
        return i18nc("@info data rate", "%1 B/s", Math.round(n))
    }
    function size(v) {
        const n = Math.max(0, Number(v) || 0)
        if (n >= 1024 * 1024 * 1024) return i18nc("@info data size", "%1 GiB", (n / 1073741824).toLocaleString(Qt.locale(), "f", 2))
        if (n >= 1024 * 1024) return i18nc("@info data size", "%1 MiB", (n / 1048576).toLocaleString(Qt.locale(), "f", 0))
        return i18nc("@info data size", "%1 KiB", (n / 1024).toLocaleString(Qt.locale(), "f", 0))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        G.GadgetTabStrip {
            Layout.fillWidth: true
            model: [
                { name: i18nc("@title:tab network throughput chart", "Overview") },
                { name: i18nc("@title:tab connection addresses and settings", "Details") }
            ]
            currentIndex: net.tab
            onActivated: index => net.tab = index
        }

        // ── Overview ──
        ColumnLayout {
            visible: net.tab === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            /*  Two lines, one per series, dot in the series colour so the
                legend and the chart cannot be read apart. Values are in a
                monospace column, so they do not jitter as digits change.  */
            component Stat : RowLayout {
                property string label: ""
                property string value: ""
                property color dot: "white"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: dot }
                PC3.Label { text: label; font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.65; Layout.fillWidth: true; elide: Text.ElideRight }
                PC3.Label { text: value; font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold; font.family: "monospace" }
            }
            Stat { label: i18nc("@label network throughput", "Download"); value: net.speed(down.value); dot: net.host.accent }
            Stat { label: i18nc("@label network throughput", "Upload");   value: net.speed(up.value);   dot: Kirigami.Theme.positiveTextColor }

            G.Sparkline {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 1.5
                values: net.downHist
                values2: net.upHist
                color: net.host.accent
                color2: Kirigami.Theme.positiveTextColor
                Accessible.role: Accessible.Graphic
                Accessible.name: i18n("Network throughput chart, download %1, upload %2", net.speed(down.value), net.speed(up.value))
            }
        }

        // ── Details (created only while shown) ──
        Loader {
            id: detailsLoader
            visible: net.tab === 1
            active: net.tab === 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: Qt.resolvedUrl("network/NetworkDetails.qml")
            onLoaded: { item.host = net.host; item.compact = Qt.binding(() => net.host.compact) }
        }
        PC3.Label {
            visible: net.tab === 1 && detailsLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: i18n("Connection details need Plasma's network module (plasma-nm).")
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 0.6
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}
