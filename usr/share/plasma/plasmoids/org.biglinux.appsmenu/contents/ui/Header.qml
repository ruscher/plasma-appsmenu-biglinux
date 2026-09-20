/*
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQml 2.15
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kirigamiaddons.components as KirigamiComponents
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCM
import org.kde.config as KConfig
import org.kde.plasma.plasmoid
import Qt.labs.platform as Platform

import "components" as Components

PlasmaExtras.PlasmoidHeading {
    id: root

    property alias searchText: searchField.text
    property alias searchField: searchField
    property Item configureButton: null
    property Item avatar: avatar
    property real preferredNameAndIconWidth: 0

    contentHeight: headerColumn.implicitHeight

    leftPadding: 0
    rightPadding: 0
    topPadding: Math.round((background.margins.top - background.inset.top) / 2.0)
    bottomPadding: background.margins.bottom + Math.round((background.margins.bottom - background.inset.bottom) / 2.0)

    KCoreAddons.KUser {
        id: kuser
    }

    spacing: kickoff.backgroundMetrics.spacing

    function tabSetFocus(event, invertedTarget, normalTarget) {
        const reason = event.key === Qt.Key_Tab ? Qt.TabFocusReason : Qt.BacktabFocusReason
        if (kickoff.paneSwap) {
            invertedTarget.forceActiveFocus(reason)
        } else if (normalTarget !== undefined) {
            normalTarget.forceActiveFocus(reason)
        } else {
            event.accepted = false
        }
    }

    ColumnLayout {
        id: headerColumn
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // Row 1: Search field (ALWAYS VISIBLE - never hidden)
        PlasmaExtras.SearchField {
            id: searchField
            Layout.fillWidth: true
            Layout.leftMargin: kickoff.backgroundMetrics.leftPadding
            Layout.rightMargin: kickoff.backgroundMetrics.rightPadding
            focus: true

            placeholderText: i18n("Search applications, settings, and files...")

            Accessible.name: i18n("Search applications, settings, and files")
            Accessible.role: Accessible.EditableText

            Binding {
                target: kickoff
                property: "searchField"
                value: searchField
                restoreMode: Binding.RestoreNone
            }

            Connections {
                target: kickoff
                function onExpandedChanged() {
                    if (kickoff.expanded) {
                        searchField.clear()
                        searchField.forceActiveFocus(Qt.OtherFocusReason)
                    }
                }
            }

            onTextEdited: {
                searchField.forceActiveFocus(Qt.ShortcutFocusReason)
            }

            onAccepted: {
                if (kickoff.contentArea && kickoff.contentArea.currentItem) {
                    kickoff.contentArea.currentItem.forceActiveFocus(Qt.ShortcutFocusReason)
                    kickoff.contentArea.currentItem.action.trigger()
                }
            }

            Keys.priority: Keys.AfterItem
            Keys.forwardTo: kickoff.contentArea !== null && kickoff.contentArea.view !== undefined ? [kickoff.contentArea.view] : []
            Keys.onTabPressed: event => {
                avatar.forceActiveFocus(Qt.TabFocusReason)
            }
            Keys.onBacktabPressed: event => {
                // Loop to footer
                if (kickoff.footer) {
                    kickoff.footer.forceActiveFocus(Qt.BacktabFocusReason)
                }
            }
        }

        // Row 2: Avatar + user info + power buttons
        RowLayout {
            id: userRow
            Layout.fillWidth: true
            Layout.leftMargin: kickoff.backgroundMetrics.leftPadding
            Layout.rightMargin: kickoff.backgroundMetrics.rightPadding
            spacing: Kirigami.Units.smallSpacing

            // Avatar button — large, opens the user account settings
            KirigamiComponents.AvatarButton {
                id: avatar

                readonly property int avatarSize: Math.round(Kirigami.Units.gridUnit * 3)
                Layout.preferredWidth: avatarSize
                Layout.preferredHeight: avatarSize

                name: kuser.fullName || kuser.loginName
                source: kuser.faceIconUrl + "?timestamp=" + Date.now()

                Accessible.name: kuser.fullName || kuser.loginName
                Accessible.role: Accessible.Button
                Accessible.description: i18n("Open user account settings")

                PC3.ToolTip.text: i18n("User account: avatar, password…")
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

                // Hover feedback: subtle lift
                scale: hovered ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

                onClicked: {
                    KCM.KCMLauncher.openSystemSettings("kcm_users")
                    if (kickoff.hideOnWindowDeactivate) {
                        kickoff.expanded = false
                    }
                }

                Keys.onTabPressed: event => {
                    powerButtons.forceActiveFocus(Qt.TabFocusReason)
                }
                Keys.onBacktabPressed: event => {
                    searchField.forceActiveFocus(Qt.BacktabFocusReason)
                }
            }

            // User name and host
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PC3.Label {
                    Layout.fillWidth: true
                    text: kuser.fullName || kuser.loginName
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: kuser.loginName + "@" + kuser.host
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                    visible: kuser.fullName.length > 0
                }
            }

            // Power/session buttons
            Components.PowerMenu {
                id: powerButtons
                Layout.fillWidth: false
                shouldCollapseButtons: root.contentWidth + root.spacing + buttonImplicitWidth > root.width

                Keys.onTabPressed: event => {
                    // Forward focus to the content area
                    if (kickoff.contentArea) {
                        kickoff.contentArea.forceActiveFocus(Qt.TabFocusReason)
                    } else {
                        event.accepted = false
                    }
                }
            }
        }
    }
}
