/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Notes gadget — sticky note with autosave. cfg: { text, color, fontSize }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: notes
    required property var host

    readonly property var palette: ({
        yellow: "#f59e0b", green: "#22c55e", blue: "#3b82f6", pink: "#ec4899", purple: "#a855f7", plain: Kirigami.Theme.textColor
    })
    readonly property string colorKey: host.cfg.color || "yellow"
    readonly property color paper: palette[colorKey] || palette.yellow

    Component.onCompleted: {
        host.accent = paper
        host.settingsComponent = settings
        area.text = host.cfg.text || ""
    }
    onPaperChanged: host.accent = paper

    Timer {
        id: saveTimer
        interval: 800
        onTriggered: notes.host.setCfg("text", area.text)
    }

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: Qt.rgba(notes.paper.r, notes.paper.g, notes.paper.b, 0.10)
        border.width: 1
        border.color: Qt.rgba(notes.paper.r, notes.paper.g, notes.paper.b, 0.25)
    }

    QQC2.ScrollView {
        anchors.fill: parent
        anchors.margins: 2
        clip: true

        QQC2.TextArea {
            id: area
            placeholderText: i18n("Write something…")
            wrapMode: TextEdit.Wrap
            font.pointSize: (notes.host.cfg.fontSize || Kirigami.Theme.defaultFont.pointSize)
            background: null
            selectByMouse: true
            persistentSelection: false
            onTextChanged: if (activeFocus) saveTimer.restart()
            Accessible.name: i18n("Note text")
        }
    }

    // Small actions on hover
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
        spacing: 2
        opacity: notes.host.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        PC3.ToolButton {
            icon.name: "edit-copy"
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            onClicked: { area.selectAll(); area.copy(); area.deselect() }
            PC3.ToolTip.text: i18n("Copy note")
            PC3.ToolTip.visible: hovered
            Accessible.name: i18n("Copy note")
        }
        PC3.ToolButton {
            icon.name: "edit-clear-all"
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            onClicked: { area.clear(); notes.host.setCfg("text", "") }
            PC3.ToolTip.text: i18n("Clear note")
            PC3.ToolTip.visible: hovered
            Accessible.name: i18n("Clear note")
        }
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.largeSpacing
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Row {
                    Kirigami.FormData.label: i18n("Color:")
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: ["yellow", "green", "blue", "pink", "purple", "plain"]
                        delegate: QQC2.AbstractButton {
                            required property string modelData
                            width: Kirigami.Units.iconSizes.medium
                            height: width
                            onClicked: host.setCfg("color", modelData)
                            Accessible.name: modelData
                            background: Rectangle {
                                radius: width / 2
                                color: notes.palette[modelData]
                                border.width: (host.cfg.color || "yellow") === modelData ? 3 : 1
                                border.color: (host.cfg.color || "yellow") === modelData ? Kirigami.Theme.textColor : Qt.rgba(0, 0, 0, 0.3)
                            }
                        }
                    }
                }
                QQC2.SpinBox {
                    Kirigami.FormData.label: i18n("Font size:")
                    from: 7; to: 24
                    value: host.cfg.fontSize || Kirigami.Theme.defaultFont.pointSize
                    onValueModified: host.setCfg("fontSize", value)
                }
            }
        }
    }
}
