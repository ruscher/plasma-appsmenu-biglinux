/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Quick Links gadget — big icons for apps and sites; add/remove/edit.
    cfg: { links: [{ name, icon, target }] }
      target: http(s)://… or file://… (opened with the default handler)
              anything else is run as a command line (e.g. "konsole").
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.iconthemes as KIconThemes

Item {
    id: ql
    required property var host

    readonly property var defaults: [
        { name: i18n("Settings"),  icon: "systemsettings",           target: "systemsettings" },
        { name: i18n("Files"),     icon: "system-file-manager",      target: "dolphin" },
        { name: i18n("Terminal"),  icon: "utilities-terminal",       target: "konsole" },
        { name: i18n("Monitor"),   icon: "utilities-system-monitor", target: "plasma-systemmonitor" },
        { name: i18n("Big Store"), icon: "bigstore",                 target: "big-store" },
        { name: i18n("KDE.org"),   icon: "kde",                      target: "https://kde.org" },
    ]
    readonly property var links: host.cfg.links && host.cfg.links.length ? host.cfg.links : defaults

    Component.onCompleted: {
        host.accentColor = "#14b8a6"
        host.settingsComponent = settings
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }
    function activate(link) {
        const t = String(link.target || "").trim()
        if (!t.length) return
        if (/^(https?|file|mailto):/i.test(t)) {
            Qt.openUrlExternally(t)
        } else {
            runner.connectSource(t)
        }
        if (kickoff.hideOnWindowDeactivate) kickoff.expanded = false
    }

    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        readonly property int cols: Math.max(2, Math.floor(width / (Kirigami.Units.gridUnit * 4.2)))
        cellWidth: Math.floor(width / cols)
        cellHeight: Math.min(height / Math.max(1, Math.ceil(count / cols)), Kirigami.Units.gridUnit * 5)
        model: ql.links
        boundsBehavior: Flickable.StopAtBounds
        delegate: PC3.AbstractButton {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight
            hoverEnabled: true
            onClicked: ql.activate(modelData)
            Accessible.name: modelData.name
            Accessible.role: Accessible.Button
            PC3.ToolTip.text: modelData.target
            PC3.ToolTip.visible: hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            background: Rectangle {
                radius: Kirigami.Units.largeSpacing
                color: parent.hovered ? Qt.rgba(ql.host.accent.r, ql.host.accent.g, ql.host.accent.b, 0.16) : "transparent"
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }
            contentItem: ColumnLayout {
                spacing: 2
                Kirigami.Icon {
                    source: modelData.icon || "application-x-executable"
                    readonly property int sz: Math.min(Kirigami.Units.iconSizes.large, Math.round(Math.min(grid.cellWidth, grid.cellHeight) * 0.55))
                    Layout.preferredWidth: sz
                    Layout.preferredHeight: sz
                    Layout.alignment: Qt.AlignHCenter
                    scale: parent.parent.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                }
                PC3.Label {
                    text: modelData.name
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }
            scale: pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 80 } }
        }
    }

    // ── settings: link editor with icon picker ──
    Component {
        id: settings
        ColumnLayout {
            id: se
            property var host
            spacing: Kirigami.Units.largeSpacing
            readonly property var list: host.cfg.links && host.cfg.links.length ? host.cfg.links : ql.defaults
            function save(l) { host.setCfg("links", l) }
            property int iconRow: -1

            KIconThemes.IconDialog {
                id: iconDialog
                onIconNameChanged: {
                    if (se.iconRow >= 0 && iconName.length) {
                        const l = se.list.map(x => Object.assign({}, x)); l[se.iconRow].icon = iconName; se.save(l)
                    } else if (se.iconRow === -1 && iconName.length) {
                        newIcon.text = iconName
                    }
                }
            }

            PC3.Label { text: i18n("Links"); font.weight: Font.DemiBold }
            Repeater {
                model: se.list
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    PC3.ToolButton {
                        icon.name: modelData.icon || "application-x-executable"
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        onClicked: { se.iconRow = index; iconDialog.open() }
                        PC3.ToolTip.text: i18n("Change icon"); PC3.ToolTip.visible: hovered
                        Accessible.name: i18n("Change icon")
                    }
                    QQC2.TextField {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                        text: modelData.name
                        placeholderText: i18n("Name")
                        onEditingFinished: { const l = se.list.map(x => Object.assign({}, x)); l[index].name = text; se.save(l) }
                    }
                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: modelData.target
                        placeholderText: i18n("Command or URL")
                        onEditingFinished: { const l = se.list.map(x => Object.assign({}, x)); l[index].target = text.trim(); se.save(l) }
                    }
                    PC3.ToolButton {
                        icon.name: "go-up"
                        enabled: index > 0
                        onClicked: { const l = se.list.map(x => Object.assign({}, x)); const t = l[index - 1]; l[index - 1] = l[index]; l[index] = t; se.save(l) }
                        Accessible.name: i18n("Move up")
                    }
                    PC3.ToolButton {
                        icon.name: "list-remove"
                        onClicked: se.save(se.list.filter((x, i) => i !== index))
                        Accessible.name: i18n("Remove link")
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                PC3.ToolButton {
                    icon.name: newIcon.text || "list-add"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: { se.iconRow = -1; iconDialog.open() }
                    Accessible.name: i18n("Choose icon")
                }
                QQC2.TextField { id: newIcon; visible: false }
                QQC2.TextField { id: newName; Layout.preferredWidth: Kirigami.Units.gridUnit * 6; placeholderText: i18n("Name") }
                QQC2.TextField { id: newTarget; Layout.fillWidth: true; placeholderText: i18n("Command or URL") }
                PC3.Button {
                    icon.name: "list-add"; text: i18n("Add")
                    enabled: newName.text.trim().length > 0 && newTarget.text.trim().length > 0
                    onClicked: {
                        const l = se.list.map(x => Object.assign({}, x))
                        l.push({ name: newName.text.trim(), icon: newIcon.text || "application-x-executable", target: newTarget.text.trim() })
                        se.save(l); newName.text = ""; newTarget.text = ""; newIcon.text = ""
                    }
                }
            }
            PC3.Label {
                text: i18n("Use a URL (https://…) to open a site, or a command (e.g. konsole) to launch an app.")
                opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; wrapMode: Text.Wrap; Layout.fillWidth: true
            }
        }
    }
}
