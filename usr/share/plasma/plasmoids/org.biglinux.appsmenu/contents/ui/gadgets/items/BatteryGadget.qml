/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Battery Meter — a battery that fills with animated "liquid": level, state,
    autonomy, plug connected/disconnected. Desktops without a battery show
    mains power and the live power draw exposed by the sensors (GPU).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.ksysguard.sensors as Sensors

Item {
    id: bat
    required property var host

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
        interval: bat.host.active ? 5000 : 0
    }
    readonly property var battery: pm.data["Battery"] || {}
    readonly property bool hasBattery: battery["Has Battery"] === true
    readonly property int percent: Math.max(0, Math.min(100, Number(battery["Percent"]) || 0))
    readonly property string chargeState: String(battery["State"] || "")
    readonly property bool charging: chargeState === "Charging"
    readonly property bool full: chargeState === "FullyCharged" || (percent >= 100 && acPlugged)
    readonly property real remainingMs: Number(battery["Remaining msec"]) || 0
    readonly property bool acPlugged: (pm.data["AC Adapter"] || {})["Plugged in"] === true

    // Live power draw from the sensors (GPUs expose it; CPU package power is
    // not exported by ksystemstats on most systems).
    Sensors.Sensor { id: gpu0Power; sensorId: "gpu/gpu0/power"; enabled: bat.host.active && !bat.hasBattery; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpu1Power; sensorId: "gpu/gpu1/power"; enabled: bat.host.active && !bat.hasBattery; updateRateLimit: 2000 }
    readonly property real gpuWatts: (Number(gpu0Power.value) || 0) + (Number(gpu1Power.value) || 0)

    Component.onCompleted: host.accentColor = "#84cc16"
    Binding { target: bat.host; property: "subtitle"; value: bat.hasBattery ? (bat.charging ? i18n("Charging") : (bat.full ? i18n("Full") : i18n("On battery"))) : i18n("Mains power") }

    function remaining() {
        if (remainingMs <= 0) return ""
        const m = Math.round(remainingMs / 60000)
        const h = Math.floor(m / 60), mm = m % 60
        return h > 0 ? i18nc("time", "%1h %2min", h, mm) : i18nc("time", "%1 min", mm)
    }
    readonly property color liquid: percent <= 15 && !charging ? Kirigami.Theme.negativeTextColor
                                  : (percent <= 30 && !charging ? Kirigami.Theme.neutralTextColor : bat.host.accent)

    // ── with battery ──
    RowLayout {
        anchors.fill: parent
        visible: bat.hasBattery
        spacing: Kirigami.Units.largeSpacing

        // Battery body with liquid
        Item {
            id: body
            Layout.preferredWidth: Math.min(parent.width * 0.42, Kirigami.Units.gridUnit * 5)
            Layout.fillHeight: true
            readonly property real capH: 6
            readonly property real bw: Math.min(width, height * 0.55)
            readonly property real bh: Math.min(height - capH - 2, bw * 1.75)
            readonly property real bx: (width - bw) / 2
            readonly property real by: (height - bh - capH) / 2 + capH

            // cap
            Rectangle {
                x: body.bx + body.bw * 0.32; y: body.by - body.capH
                width: body.bw * 0.36; height: body.capH + 2
                radius: 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.35)
            }
            // shell
            Rectangle {
                id: shell
                x: body.bx; y: body.by; width: body.bw; height: body.bh
                radius: Math.max(6, body.bw * 0.14)
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                border.width: 2
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.35)
                clip: true

                // liquid with an animated wave on top
                Item {
                    id: liquidBox
                    anchors.fill: parent
                    anchors.margins: 3
                    property real level: bat.percent / 100
                    Behavior on level { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
                    property real phase: 0
                    NumberAnimation on phase {
                        running: bat.host.active && Kirigami.Units.longDuration > 0
                        loops: Animation.Infinite
                        from: 0; to: 2 * Math.PI; duration: bat.charging ? 1400 : 2600
                    }
                    // charging: level "breathes" upward to read as filling
                    property real breathe: 0
                    SequentialAnimation on breathe {
                        running: bat.charging && bat.host.active && Kirigami.Units.longDuration > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.035; duration: 1300; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.0; duration: 1300; easing.type: Easing.InOutSine }
                    }
                    readonly property real surfaceY: height * (1 - Math.min(1, level + (bat.charging ? breathe : 0)))
                    readonly property real amp: Math.max(2, height * 0.02)

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        ShapePath {
                            fillColor: bat.liquid
                            strokeColor: "transparent"
                            startX: 0; startY: liquidBox.surfaceY
                            PathCubic { x: liquidBox.width * 0.25; y: liquidBox.surfaceY; control1X: liquidBox.width * 0.08; control1Y: liquidBox.surfaceY - liquidBox.amp * Math.sin(liquidBox.phase); control2X: liquidBox.width * 0.17; control2Y: liquidBox.surfaceY + liquidBox.amp * Math.sin(liquidBox.phase) }
                            PathCubic { x: liquidBox.width * 0.5; y: liquidBox.surfaceY; control1X: liquidBox.width * 0.33; control1Y: liquidBox.surfaceY - liquidBox.amp * Math.sin(liquidBox.phase + 1.5); control2X: liquidBox.width * 0.42; control2Y: liquidBox.surfaceY + liquidBox.amp * Math.sin(liquidBox.phase + 1.5) }
                            PathCubic { x: liquidBox.width * 0.75; y: liquidBox.surfaceY; control1X: liquidBox.width * 0.58; control1Y: liquidBox.surfaceY - liquidBox.amp * Math.sin(liquidBox.phase + 3); control2X: liquidBox.width * 0.67; control2Y: liquidBox.surfaceY + liquidBox.amp * Math.sin(liquidBox.phase + 3) }
                            PathCubic { x: liquidBox.width; y: liquidBox.surfaceY; control1X: liquidBox.width * 0.83; control1Y: liquidBox.surfaceY - liquidBox.amp * Math.sin(liquidBox.phase + 4.5); control2X: liquidBox.width * 0.92; control2Y: liquidBox.surfaceY + liquidBox.amp * Math.sin(liquidBox.phase + 4.5) }
                            PathLine { x: liquidBox.width; y: liquidBox.height }
                            PathLine { x: 0; y: liquidBox.height }
                        }
                    }
                    // lighter highlight layer
                    Rectangle {
                        x: 0; y: liquidBox.surfaceY + 2; width: parent.width; height: Math.max(0, parent.height - y)
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }
                }
                // percent inside
                PC3.Label {
                    anchors.centerIn: parent
                    text: bat.percent + "%"
                    font.weight: Font.Bold
                    font.pointSize: Math.max(8, Math.min(Kirigami.Theme.defaultFont.pointSize * 1.6, body.bw * 0.22))
                    color: Kirigami.Theme.textColor
                    style: Text.Outline
                    styleColor: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.6)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                PC3.Label {
                    text: bat.acPlugged ? "🔌" : "🔋"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    opacity: bat.acPlugged ? 1 : 0.7
                }
                PC3.Label {
                    text: bat.acPlugged ? i18n("Plug connected") : i18n("Plug disconnected")
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            PC3.Label {
                text: bat.charging ? i18n("Charging") : (bat.full ? i18n("Fully charged") : i18n("Discharging"))
                opacity: 0.8
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            PC3.Label {
                visible: text.length > 0
                text: bat.remaining().length
                    ? (bat.charging ? i18n("%1 until full", bat.remaining()) : i18n("Autonomy: %1", bat.remaining()))
                    : (bat.full ? "" : i18n("Estimating autonomy…"))
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }

    // ── no battery: mains + live draw ──
    ColumnLayout {
        anchors.fill: parent
        visible: !bat.hasBattery
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            PC3.Label {
                text: "🔌"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.4
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label { text: i18n("Plugged into the mains"); font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                PC3.Label { text: i18n("No battery in this computer"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize }
            }
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            PC3.Label {
                text: bat.gpuWatts > 0 ? bat.gpuWatts.toLocaleString(Qt.locale(), "f", 0) : "—"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                font.weight: Font.Light
            }
            PC3.Label { text: "W"; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1; opacity: 0.7; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 6 }
            Item { Layout.fillWidth: true }
        }
        PC3.Label {
            text: bat.gpuWatts > 0 ? i18n("Live power draw (graphics cards)") : i18n("No power sensor available")
            opacity: 0.6
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
