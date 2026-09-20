/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    InfoPage — Dashboard com métricas reais, clima, notícias e blocos independentes
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.15 as T
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support 2.0 as P5Support
import "components" as Components
import "singletons" as Singletons

EmptyPage {
    id: root
    objectName: "infoPage"

    // Componentes Internos
    component ConfigGear : PC3.ToolButton {
        icon.name: "configure-symbolic"; icon.width: 16; icon.height: 16; flat: true; opacity: 0.5
        // Plasma 6: open own config via Plasmoid.internalAction, guarded so a
        // missing action can never throw (the old kickoff.action() was Plasma 5).
        onClicked: {
            const a = Plasmoid.internalAction("configure")
            if (a) { a.trigger() }
        }
    }

    component MonitorBlock : Rectangle {
        property string title; property string icon; property string value; property string subValue: ""; property real progress: 0; property color progressColor
        height: 120; radius: 10; color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.4)
        border.width: 1; border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
        
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 4
            RowLayout {
                Kirigami.Icon { source: icon; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                PC3.Label { text: title; font.weight: Font.Bold; Layout.fillWidth: true }
                ConfigGear {}
            }
            PC3.Label { text: value; font.pointSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            PC3.Label { text: subValue; font: Kirigami.Theme.smallFont; opacity: 0.6; elide: Text.ElideRight; Layout.fillWidth: true; visible: text !== "" }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2; color: Qt.rgba(1,1,1,0.1)
                Rectangle { width: parent.width * Math.max(0, Math.min(1, progress)); height: 4; radius: 2; color: progressColor }
            }
        }
    }

    component InfoCard : Rectangle {
        property string title; property string icon
        default property alias cardContent: contentCol.data
        Layout.preferredHeight: contentCol.implicitHeight + 30; radius: 10
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.4)
        border.width: 1; border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
        ColumnLayout {
            id: contentCol; anchors.fill: parent; anchors.margins: 15; spacing: 10
            RowLayout {
                Kirigami.Icon { source: icon; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                PC3.Label { text: title; font.weight: Font.Bold; Layout.fillWidth: true }
                ConfigGear {}
            }
        }
    }

    component DetailRow : RowLayout {
        property string rowLabel; property string rowValue; property string rowIcon; property bool rowMultiLine: false
        Kirigami.Icon { source: rowIcon; Layout.preferredWidth: 16; Layout.preferredHeight: 16; opacity: 0.7 }
        PC3.Label { text: rowLabel; opacity: 0.6; Layout.preferredWidth: 80 }
        PC3.Label { text: rowValue; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; wrapMode: rowMultiLine ? Text.Wrap : Text.NoWrap; elide: rowMultiLine ? Text.ElideNone : Text.ElideMiddle; maximumLineCount: 3 }
    }

    component QuickLinkButton : PC3.AbstractButton {
        property string btnLabel; property string btnIcon; property string btnCmd
        width: (parent.width - 20) / 2; height: 40; hoverEnabled: true
        background: Rectangle { radius: 6; color: hovered ? Qt.rgba(1,1,1,0.1) : "transparent"; border.width: 1; border.color: Qt.rgba(1,1,1,0.05) }
        contentItem: RowLayout {
            spacing: 8; anchors.centerIn: parent
            Kirigami.Icon { source: btnIcon; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            PC3.Label { text: btnLabel; font: Kirigami.Theme.smallFont }
        }
        onClicked: execSource.run(btnCmd)
    }

    T.StackView.onActivated: {
        kickoff.sideBar = null
        kickoff.contentArea = root
    }

    // Datasources
    // Fire-and-forget runner: disconnect each source as soon as it finishes so
    // connected "executable" sources don't accumulate for the page's lifetime.
    P5Support.DataSource {
        id: execSource
        engine: "executable"
        onNewData: source => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }
    P5Support.DataSource { id: hostSource; engine: "executable"; connectedSources: ["hostname"]; interval: 0 }
    P5Support.DataSource { id: kernelSource; engine: "executable"; connectedSources: ["uname -sr"]; interval: 0 }
    P5Support.DataSource { id: shellSource; engine: "executable"; connectedSources: ["echo $SHELL && $SHELL --version | head -1"]; interval: 0 }
    P5Support.DataSource { id: cpuInfoSource; engine: "executable"; connectedSources: ["grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]; interval: 0 }
    P5Support.DataSource { id: moboSource; engine: "executable"; connectedSources: ["cat /sys/class/dmi/id/board_vendor 2>/dev/null | tr -d '\\n' && echo -n ' ' && cat /sys/class/dmi/id/board_name 2>/dev/null"]; interval: 0 }
    P5Support.DataSource { id: uptimeSource; engine: "executable"; connectedSources: ["uptime -p"]; interval: 60000 }
    P5Support.DataSource { id: memSource; engine: "executable"; connectedSources: ["free -b"]; interval: 3000 }
    P5Support.DataSource { id: diskSource; engine: "executable"; connectedSources: ["df -B1 /"]; interval: 30000 }
    P5Support.DataSource { id: gpuSource; engine: "executable"; connectedSources: ["lspci | grep -i 'vga\\|3d' | cut -d: -f3"]; interval: 0 }

    // Weather Source
    P5Support.DataSource { 
        id: weatherSource
        engine: "executable"
        connectedSources: ["curl -s 'wttr.in?format=%l:%c:%t:%h:%w'"]
        interval: 1800000 // 30 min
    }

    // RSS Source (Phoronix)
    P5Support.DataSource {
        id: phoronixSource
        engine: "executable"
        connectedSources: ["curl -s 'https://www.phoronix.com/rss.php' | grep -oPm3 '(?<=<title>)[^<]+' | tail -n +2"]
        interval: 3600000 // 1 hour
    }

    function getStdout(source) {
        if (!source || !source.connectedSources || source.connectedSources.length === 0) return "..."
        var src = source.connectedSources[0]
        if (source.data[src] && source.data[src]["stdout"]) return source.data[src]["stdout"].trim()
        return "..."
    }

    function formatGB(bytes) {
        var b = parseInt(bytes) || 0
        return (b / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    contentItem: Flickable {
        contentWidth: width
        contentHeight: mainCol.implicitHeight + 40
        clip: true
        PC3.ScrollBar.vertical: PC3.ScrollBar {}

        ColumnLayout {
            id: mainCol
            width: parent.width - 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Item { Layout.preferredHeight: 10 }

            // ─── BLOCO: HARDWARE ───
            GridLayout {
                Layout.fillWidth: true; columns: 2; rowSpacing: 15; columnSpacing: 15
                visible: Plasmoid.configuration.infoShowHardwareMonitor

                MonitorBlock {
                    Layout.fillWidth: true
                    title: "CPU"; icon: "cpu-symbolic"; value: "Active"; subValue: getStdout(cpuInfoSource); progressColor: "#43A047"
                }
                MonitorBlock {
                    Layout.fillWidth: true
                    title: "RAM"; icon: "memory-symbolic"; progressColor: "#1E88E5"
                    value: {
                        var out = getStdout(memSource).split("\n")
                        if (out.length > 1) {
                            var p = out[1].trim().split(/\s+/)
                            if (p.length >= 3) return formatGB(p[2]) + " / " + formatGB(p[1])
                        }
                        return "..."
                    }
                    progress: {
                        var out = getStdout(memSource).split("\n")
                        if (out.length > 1) {
                            var p = out[1].trim().split(/\s+/)
                            if (p.length >= 3) return parseInt(p[2]) / parseInt(p[1])
                        }
                        return 0
                    }
                }
                MonitorBlock {
                    Layout.fillWidth: true
                    title: "SWAP"; icon: "document-swap-symbolic"; progressColor: "#8E24AA"
                    value: {
                        var out = getStdout(memSource).split("\n")
                        if (out.length > 2) {
                            var p = out[2].trim().split(/\s+/)
                            if (p.length >= 3) return formatGB(p[2]) + " / " + formatGB(p[1])
                        }
                        return "0 GB"
                    }
                    progress: {
                        var out = getStdout(memSource).split("\n")
                        if (out.length > 2) {
                            var p = out[2].trim().split(/\s+/)
                            if (p.length >= 3 && parseInt(p[1]) > 0) return parseInt(p[2]) / parseInt(p[1])
                        }
                        return 0
                    }
                }
                MonitorBlock {
                    Layout.fillWidth: true
                    title: "DISK /"; icon: "drive-harddisk-symbolic"; progressColor: "#FB8C00"
                    value: {
                        var out = getStdout(diskSource).split("\n")
                        if (out.length > 1) {
                            var p = out[1].trim().split(/\s+/)
                            if (p.length >= 3) return formatGB(p[2]) + " / " + formatGB(p[1])
                        }
                        return "..."
                    }
                    progress: {
                        var out = getStdout(diskSource).split("\n")
                        if (out.length > 1) {
                            var p = out[1].trim().split(/\s+/)
                            if (p.length >= 3) return parseInt(p[2]) / parseInt(p[1])
                        }
                        return 0
                    }
                }
            }

            // ─── BLOCO: NEWS PHORONIX ───
            InfoCard {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.infoShowNews
                title: "Phoronix News"
                icon: "news-subscribe-symbolic"
                
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: getStdout(phoronixSource).split("\n")
                        delegate: PC3.ItemDelegate {
                            Layout.fillWidth: true
                            contentItem: PC3.Label {
                                text: "• " + modelData
                                elide: Text.ElideRight
                                font: Kirigami.Theme.smallFont
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                            }
                            onClicked: execSource.run("xdg-open https://www.phoronix.com")
                        }
                    }
                }
            }

            // ─── BLOCO: CALENDÁRIO & HORA ───
            InfoCard {
                Layout.fillWidth: true
                title: i18n("Date & Time")
                icon: "view-calendar"
                
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        PC3.Label {
                            Layout.fillWidth: true
                            text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy - HH:mm")
                            font.pointSize: 14; font.weight: Font.DemiBold
                        }
                        PC3.ToolButton {
                            icon.name: "edit-copy-symbolic"
                            PC3.ToolTip.visible: hovered
                            PC3.ToolTip.text: i18n("Copy full date/time")
                            onClicked: {
                                var txt = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")
                                // Reuse the shared runner instead of leaking a new
                                // DataSource object on every copy click.
                                execSource.run("printf '%s' '" + txt + "' | wl-copy 2>/dev/null || printf '%s' '" + txt + "' | xclip -selection clipboard")
                            }
                        }
                    }
                    
                    // Simple Calendar Grid (Fake KDE style)
                    GridLayout {
                        columns: 7; Layout.fillWidth: true
                        Repeater {
                            model: [i18n("S"), i18n("M"), i18n("T"), i18n("W"), i18n("T"), i18n("F"), i18n("S")]
                            delegate: PC3.Label { text: modelData; font.weight: Font.Bold; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; opacity: 0.5 }
                        }
                        Repeater {
                            model: 31
                            delegate: Rectangle {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                radius: 15
                                color: (index + 1) === new Date().getDate() ? Kirigami.Theme.highlightColor : "transparent"
                                PC3.Label {
                                    anchors.centerIn: parent
                                    text: index + 1
                                    color: (index + 1) === new Date().getDate() ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                }
                            }
                        }
                    }
                }
            }

            // ─── BLOCO: CLIMA ───
            InfoCard {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.infoShowWeather
                title: i18n("Weather")
                icon: "weather-few-clouds-symbolic"

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 12
                    property var weatherData: getStdout(weatherSource).split(":")
                    PC3.Label {
                        text: (parent.weatherData && parent.weatherData[0]) ? parent.weatherData[0] : i18n("Detecting location...")
                        font.weight: Font.Bold; font.pointSize: 13; Layout.alignment: Qt.AlignHCenter
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 20
                        PC3.Label { text: (parent.parent.weatherData && parent.parent.weatherData[1]) ? parent.parent.weatherData[1] : ""; font.pointSize: 32 }
                        PC3.Label { text: (parent.parent.weatherData && parent.parent.weatherData[2]) ? parent.parent.weatherData[2] : "--"; font.pointSize: 28; font.weight: Font.Light }
                    }
                }
            }

            // ─── BLOCO: SISTEMA ───
            InfoCard {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.infoShowSystemInfo
                title: i18n("System Details")
                icon: "computer-symbolic"
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8
                    DetailRow { rowLabel: "Hostname"; rowValue: getStdout(hostSource); rowIcon: "network-server" }
                    DetailRow { rowLabel: "Kernel"; rowValue: getStdout(kernelSource); rowIcon: "linux" }
                    DetailRow { rowLabel: "Shell"; rowValue: getStdout(shellSource); rowIcon: "utilities-terminal"; rowMultiLine: true }
                    DetailRow { rowLabel: "Uptime"; rowValue: getStdout(uptimeSource).replace("up ", ""); rowIcon: "clock" }
                }
            }

            // ─── BLOCO: LINKS RÁPIDOS ───
            InfoCard {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.infoShowQuickLinks
                title: i18n("Quick Links")
                icon: "emblem-symbolic-link"
                Flow {
                    Layout.fillWidth: true; spacing: 10
                    QuickLinkButton { btnLabel: "Config"; btnIcon: "systemsettings"; btnCmd: "systemsettings" }
                    QuickLinkButton { btnLabel: "Dolphin"; btnIcon: "system-file-manager"; btnCmd: "dolphin" }
                    QuickLinkButton { btnLabel: "Terminal"; btnIcon: "utilities-terminal"; btnCmd: "konsole" }
                    QuickLinkButton { btnLabel: "Monitor"; btnIcon: "utilities-system-monitor"; btnCmd: "plasma-systemmonitor" }
                }
            }
        }
    }
}
