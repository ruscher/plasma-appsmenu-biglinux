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

    property Item settingsItem: null
    function openFor(h) {
        host = h
        if (h && h.settingsComponent) {
            if (settingsItem) { settingsItem.destroy(); settingsItem = null }
            // createObject so `host` is set BEFORE any binding runs
            settingsItem = h.settingsComponent.createObject(settingsHolder, { "host": h })
            open()
        }
    }

    /*  A settings page may have something the user would lose by closing —
        the countdown editor holds an event that was typed but never added.
        Such a page defines `function requestClose(proceed)`: it either calls
        proceed() straight away, or puts its own question on screen and calls
        proceed() once the user has answered. Pages that define nothing close
        as they always did.

        Every route out of the dialog goes through tryClose(), which is why
        the automatic close policies are off: Escape and clicking outside are
        handled below so they cannot bypass the question.  */
    function tryClose() {
        if (settingsItem && typeof settingsItem.requestClose === "function") {
            settingsItem.requestClose(function() { dialog.close() })
            return
        }
        close()
    }

    modal: true
    dim: true
    focus: true
    closePolicy: QQC2.Popup.NoAutoClose
    Keys.onEscapePressed: event => { event.accepted = true; dialog.tryClose() }
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - Kirigami.Units.gridUnit * 3 : 500, Kirigami.Units.gridUnit * 30)
    height: Math.min(parent ? parent.height - Kirigami.Units.gridUnit * 2 : 400, contentItem.implicitHeight + topPadding + bottomPadding)
    padding: Kirigami.Units.largeSpacing

    onClosed: { if (settingsItem) { settingsItem.destroy(); settingsItem = null }; host = null }

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
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.45)
        TapHandler { onTapped: dialog.tryClose() }
    }

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
                onClicked: dialog.tryClose()
                Accessible.name: i18n("Close")
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(settingsHolder.implicitHeight, Kirigami.Units.gridUnit * 22)
            clip: true
            contentWidth: availableWidth

            Item {
                id: settingsHolder
                width: parent ? parent.width : 0
                implicitHeight: dialog.settingsItem ? dialog.settingsItem.implicitHeight : 0
                onWidthChanged: if (dialog.settingsItem) dialog.settingsItem.width = width
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PC3.Button {
                text: i18n("Done")
                icon.name: "dialog-ok-apply"
                onClicked: dialog.tryClose()
            }
        }
    }
}
