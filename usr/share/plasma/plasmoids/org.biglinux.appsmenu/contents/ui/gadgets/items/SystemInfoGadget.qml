/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    System Info — host, OS, kernel, Plasma, uptime, CPU, GPU, RAM (KSystemStats).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support 2.0 as P5Support

Item {
    id: si
    required property var host

    Sensors.Sensor { id: hostname; sensorId: "os/system/hostname"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: osName;   sensorId: "os/system/prettyName"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: osLogo;   sensorId: "os/system/logo"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: kernel;   sensorId: "os/kernel/prettyName"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: plasma;   sensorId: "os/plasma/plasmaVersion"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: wsys;     sensorId: "os/plasma/windowsystem"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: uptime;   sensorId: "os/system/uptime"; enabled: si.host.active; updateRateLimit: 30000 }
    // ksystemstats has no model-name sensor; read /proc/cpuinfo once
    P5Support.DataSource {
        id: cpuInfo
        engine: "executable"
        connectedSources: ["grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]
        interval: 0
    }
    readonly property string cpuModel: {
        const d = cpuInfo.data[cpuInfo.connectedSources[0]]
        return d && d.stdout ? String(d.stdout).trim() : ""
    }
    Sensors.Sensor { id: gpuName;  sensorId: "gpu/gpu0/name"; enabled: true; updateRateLimit: 60000 }
    Sensors.Sensor { id: ramTotal; sensorId: "memory/physical/total"; enabled: true; updateRateLimit: 60000 }

    Component.onCompleted: host.accent = "#64748b"
    Binding { target: si.host; property: "subtitle"; value: String(hostname.value || "") }

    function up(sec) {
        const s = Math.max(0, Math.floor(Number(sec) || 0))
        const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60)
        if (d > 0) return i18nc("uptime d h m", "%1d %2h %3m", d, h, m)
        if (h > 0) return i18nc("uptime h m", "%1h %2m", h, m)
        return i18nc("uptime m", "%1m", m)
    }
    function gb(v) { return ((Number(v) || 0) / 1024 / 1024 / 1024).toLocaleString(Qt.locale(), "f", 0) + " GB" }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            visible: !si.host.compact
            source: String(osLogo.value || "") || "computer"
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            Layout.alignment: Qt.AlignVCenter
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 1
            columnSpacing: Kirigami.Units.largeSpacing
            component K : PC3.Label { font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.55; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
            component V : PC3.Label { font.pointSize: Kirigami.Theme.smallFont.pointSize; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 1 }

            K { text: i18n("OS") }      V { text: String(osName.value || ""); font.weight: Font.DemiBold }
            K { text: i18n("Kernel") }  V { text: String(kernel.value || "") }
            K { text: i18n("Plasma") }  V { text: String(plasma.value || "") + (wsys.value ? " · " + String(wsys.value) : "") }
            K { text: i18n("Uptime") }  V { text: si.up(uptime.value) }
            K { text: i18n("CPU"); visible: !si.host.compact }   V { text: si.cpuModel; visible: !si.host.compact }
            K { text: i18n("GPU"); visible: !si.host.compact }   V { text: String(gpuName.value || ""); visible: !si.host.compact }
            K { text: i18n("RAM") }     V { text: si.gb(ramTotal.value) }
        }
    }
}
