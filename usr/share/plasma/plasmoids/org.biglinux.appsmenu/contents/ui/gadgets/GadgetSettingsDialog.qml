/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetSettingsDialog — hosts a gadget's own settings component
    (host.settingsComponent, which receives `host` and edits host.cfg).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

QQC2.Popup {
    id: dialog
    property var host: null

    function openFor(h) {
        host = h
        if (h && h.settingsComponent) {
            loader.sourceComponent = null
            loader.setSource("", {})
            loader.sourceComponent = h.settingsComponent
            open()
        }
    }

    modal: true
    dim: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - Kirigami.Units.gridUnit * 3 : 500, Kirigami.Units.gridUnit * 30)
    height: Math.min(parent ? parent.height - Kirigami.Units.gridUnit * 2 : 400, contentItem.implicitHeight + topPadding + bottomPadding)
    padding: Kirigami.Units.largeSpacing

    onClosed: { loader.sourceComponent = null; host = null }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Kirigami.Units.shortDuration } }

    background: Kirigami.ShadowedRectangle {
        color: Kirigami.Theme.backgroundColor
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
        radius: Kirigami.Units.largeSpacing * 1.5
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
        shadow.size: 32
        shadow.color: Qt.rgba(0, 0, 0, 0.5)
    }
    QQC2.Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: dialog.host && dialog.host.def ? dialog.host.def.icon : "configure"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            Kirigami.Heading {
                text: dialog.host ? i18n("Configure %1", dialog.host.title) : ""
                level: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.ToolButton {
                icon.name: "window-close"
                onClicked: dialog.close()
                Accessible.name: i18n("Close")
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(loader.item ? loader.item.implicitHeight : 0, Kirigami.Units.gridUnit * 22)
            clip: true
            contentWidth: availableWidth

            Loader {
                id: loader
                width: parent ? parent.width : 0
                onLoaded: {
                    if (item && dialog.host) {
                        if (item.hasOwnProperty("host")) item.host = dialog.host
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PC3.Button {
                text: i18n("Done")
                icon.name: "dialog-ok-apply"
                onClicked: dialog.close()
            }
        }
    }
}
