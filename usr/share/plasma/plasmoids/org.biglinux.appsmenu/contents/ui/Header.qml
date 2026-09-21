/*
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    Header — a single row: identity · search · session actions.

        [avatar] [name/host]   [ search ]   [logout][reboot][shutdown][⋮]

    The search field shares the row with the user's identity instead of owning
    a full row of its own. While the user is actually searching, the avatar and
    the name/host block collapse away and the field takes the space they leave,
    so the query and its results get the width they need.

    "Actually searching" deliberately excludes the focus the field is given when
    the menu opens (Qt.OtherFocusReason): the user should see their avatar on a
    freshly opened menu and still be able to type straight away. A click, a Tab,
    or any typed text expands it.
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

    /* True while the user is searching on purpose. Drives the expansion.

       Deliberately NOT inferred from searchField.focusReason. The field is
       focused as soon as the menu opens so the user can type straight away,
       and the reason Qt then reports for that focus depends on how the popup's
       focus chain resolves rather than on anything the user did — measured as
       BacktabFocusReason on X11 even though the field is focused
       programmatically with OtherFocusReason, which left the header stuck in
       its expanded state with the avatar hidden.

       Intent is therefore tracked explicitly: typing expands it (text is the
       intent), and so does tapping the field or tabbing into it from the
       avatar. Same behaviour on X11 and Wayland, no focus-reason guesswork. */
    property bool searchEngaged: false
    readonly property bool searchActive: searchField.text.length > 0 || root.searchEngaged

    contentHeight: headerRow.implicitHeight

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

    // Kirigami's durations already scale with the desktop's animation-speed
    // setting and collapse to zero when animations are switched off, so honouring
    // "reduce animations" needs nothing more than using them.
    readonly property int collapseDuration: Kirigami.Units.shortDuration

    RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.leftMargin: kickoff.backgroundMetrics.leftPadding
        anchors.rightMargin: kickoff.backgroundMetrics.rightPadding
        spacing: Kirigami.Units.smallSpacing

        // ── Avatar — collapses while searching ──
        KirigamiComponents.AvatarButton {
            id: avatar

            readonly property int avatarSize: Math.round(Kirigami.Units.gridUnit * 2.5)

            Layout.preferredWidth: root.searchActive ? 0 : avatarSize
            Layout.preferredHeight: avatarSize
            Layout.alignment: Qt.AlignVCenter
            opacity: root.searchActive ? 0 : 1
            visible: Layout.preferredWidth > 0
            // Nothing should be able to tab into a collapsed control.
            enabled: !root.searchActive
            activeFocusOnTab: !root.searchActive

            name: kuser.fullName || kuser.loginName
            source: kuser.faceIconUrl + "?timestamp=" + Date.now()

            Accessible.name: kuser.fullName || kuser.loginName
            Accessible.role: Accessible.Button
            Accessible.description: i18n("Open user account settings")

            PC3.ToolTip.text: i18n("User account: avatar, password…")
            PC3.ToolTip.visible: hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

            scale: hovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: root.collapseDuration; easing.type: Easing.OutCubic } }
            Behavior on Layout.preferredWidth { NumberAnimation { duration: root.collapseDuration; easing.type: Easing.OutCubic } }

            onClicked: {
                KCM.KCMLauncher.openSystemSettings("kcm_users")
                if (kickoff.hideOnWindowDeactivate) {
                    kickoff.expanded = false
                }
            }

            Keys.onTabPressed: event => {
                root.searchEngaged = true
                searchField.forceActiveFocus(Qt.TabFocusReason)
            }
            Keys.onBacktabPressed: event => {
                if (kickoff.footer) {
                    kickoff.footer.forceActiveFocus(Qt.BacktabFocusReason)
                }
            }
        }

        // ── Name and host — collapses with the avatar ──
        ColumnLayout {
            id: identityBlock
            spacing: 0
            clip: true

            Layout.fillWidth: false
            // maximumWidth alone drives the collapse: deriving a preferredWidth
            // from this layout's own implicitWidth would feed back into it.
            Layout.maximumWidth: root.searchActive ? 0 : Math.round(root.width / 3)
            Layout.alignment: Qt.AlignVCenter
            opacity: root.searchActive ? 0 : 1
            visible: Layout.maximumWidth > 0

            Behavior on opacity { NumberAnimation { duration: root.collapseDuration; easing.type: Easing.OutCubic } }
            Behavior on Layout.maximumWidth { NumberAnimation { duration: root.collapseDuration; easing.type: Easing.OutCubic } }

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

        // ── Search — takes whatever the identity block gives up ──
        PlasmaExtras.SearchField {
            id: searchField

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            focus: true

            // Short when idle so the row stays calm; the full sentence appears
            // once the field has the width to show it without truncation.
            placeholderText: root.searchActive
                ? i18n("Search apps, files, settings, calculations…")
                : i18n("Search…")

            Accessible.name: i18n("Search")
            Accessible.description: i18n("Search applications, files, settings and more. Also does calculations and unit conversions.")
            Accessible.role: Accessible.EditableText

            /* DragThreshold so this never takes the grab away from text
               selection; it only records that the user reached for the field. */
            TapHandler {
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.DragThreshold
                onTapped: root.searchEngaged = true
            }

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
                        root.searchEngaged = false
                        // Focused so the user can type immediately; the header
                        // still rests until they actually engage (searchActive).
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

            // Escape clears the query first; a second Escape (with the field
            // already empty) falls through and closes the menu.
            Keys.onEscapePressed: event => {
                if (searchField.text.length > 0) {
                    searchField.clear()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            Keys.priority: Keys.AfterItem
            Keys.forwardTo: kickoff.contentArea !== null && kickoff.contentArea.view !== undefined ? [kickoff.contentArea.view] : []
            Keys.onTabPressed: event => {
                powerButtons.forceActiveFocus(Qt.TabFocusReason)
            }
            Keys.onBacktabPressed: event => {
                if (root.searchActive || !avatar.visible) {
                    // Avatar is collapsed: skip it and loop to the footer.
                    if (kickoff.footer) {
                        kickoff.footer.forceActiveFocus(Qt.BacktabFocusReason)
                    }
                } else {
                    avatar.forceActiveFocus(Qt.BacktabFocusReason)
                }
            }
        }

        // ── Session actions, then the Options kebab ──
        Components.PowerMenu {
            id: powerButtons
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignVCenter
            // Plain width threshold on purpose: deriving this from the
            // buttons' own implicitWidth would loop, since their visibility
            // depends on this very flag.
            shouldCollapseButtons: root.width < Kirigami.Units.gridUnit * 26

            Keys.onTabPressed: event => {
                if (kickoff.contentArea) {
                    kickoff.contentArea.forceActiveFocus(Qt.TabFocusReason)
                } else {
                    event.accepted = false
                }
            }
        }
    }
}
