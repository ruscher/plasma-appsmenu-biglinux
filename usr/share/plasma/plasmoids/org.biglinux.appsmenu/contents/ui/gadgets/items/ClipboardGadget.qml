/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Clipboard gadget — recent entries from Klipper (Plasma's clipboard).
    Privacy: contents can be masked (cfg.masked) and are never sent anywhere.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.clipboard as Clipboard

Item {
    id: clip
    required property var host

    readonly property bool masked: host.cfg.masked === true
    readonly property int maxRows: host.compact ? 5 : 10

    Clipboard.HistoryModel { id: history }

    Component.onCompleted: {
        host.accent = "#64748b"
        host.settingsComponent = settings
    }
    Binding { target: clip.host; property: "subtitle"; value: history.count > 0 ? i18np("%1 item", "%1 items", history.count) : "" }

    function preview(text, type) {
        if (type === 4) return i18n("[Image]")
        const s = String(text || "").replace(/\s+/g, " ").trim()
        if (clip.masked) return "•".repeat(Math.min(24, Math.max(6, s.length)))
        return s.length > 90 ? s.substring(0, 90) + "…" : s
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: history
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            delegate: PC3.ItemDelegate {
                id: row
                required property var model
                required property int index
                required property var uuid
                required property int type
                visible: index < clip.maxRows
                height: visible ? implicitHeight : 0
                width: list.width
                hoverEnabled: true
                onClicked: history.moveToTop(uuid)
                Accessible.name: clip.preview(model.display, type)
                PC3.ToolTip.text: i18n("Click to copy")
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: row.type === 4 ? "image-x-generic" : (row.type === 8 ? "link" : "text-x-generic")
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.6
                    }
                    PC3.Label {
                        text: clip.preview(row.model.display, row.type)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.family: clip.masked ? Kirigami.Theme.defaultFont.family : Kirigami.Theme.defaultFont.family
                        Layout.fillWidth: true
                    }
                    PC3.ToolButton {
                        icon.name: "edit-delete"
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                        opacity: row.hovered ? 1 : 0
                        onClicked: history.remove(row.uuid)
                        Accessible.name: i18n("Remove entry")
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: history.count > 0
            PC3.ToolButton {
                icon.name: clip.masked ? "view-visible" : "view-hidden"
                text: clip.masked ? i18n("Show") : i18n("Hide")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                onClicked: clip.host.setCfg("masked", !clip.masked)
                Accessible.name: clip.masked ? i18n("Show clipboard contents") : i18n("Hide clipboard contents")
            }
            Item { Layout.fillWidth: true }
            PC3.ToolButton {
                icon.name: "edit-clear-history"
                text: i18n("Clear")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                onClicked: confirmClear.open()
                Accessible.name: i18n("Clear clipboard history")
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: history.count === 0
        Kirigami.Icon { source: "edit-paste"; Layout.preferredWidth: Kirigami.Units.iconSizes.large; Layout.preferredHeight: Kirigami.Units.iconSizes.large; Layout.alignment: Qt.AlignHCenter; opacity: 0.45 }
        PC3.Label { text: i18n("Clipboard is empty"); opacity: 0.7; Layout.alignment: Qt.AlignHCenter }
    }

    QQC2.Popup {
        id: confirmClear
        parent: clip.host
        modal: true
        anchors.centerIn: parent
        padding: Kirigami.Units.largeSpacing
        background: Kirigami.ShadowedRectangle {
            color: Kirigami.Theme.backgroundColor
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false
            radius: Kirigami.Units.largeSpacing
            shadow.size: 20; shadow.color: Qt.rgba(0, 0, 0, 0.5)
        }
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            PC3.Label { text: i18n("Clear the whole clipboard history?"); wrapMode: Text.Wrap; Layout.maximumWidth: Kirigami.Units.gridUnit * 14 }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                PC3.Button { text: i18n("Cancel"); onClicked: confirmClear.close() }
                PC3.Button { text: i18n("Clear"); icon.name: "edit-clear-history"; onClicked: { history.clearHistory(); confirmClear.close() } }
            }
        }
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.CheckBox {
                    Kirigami.FormData.label: i18n("Privacy:")
                    text: i18n("Mask contents until I choose to show them")
                    checked: host.cfg.masked === true
                    onToggled: host.setCfg("masked", checked)
                }
            }
            PC3.Label {
                text: i18n("Entries come from Plasma's clipboard history (Klipper) and never leave this computer.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
        }
    }
}
