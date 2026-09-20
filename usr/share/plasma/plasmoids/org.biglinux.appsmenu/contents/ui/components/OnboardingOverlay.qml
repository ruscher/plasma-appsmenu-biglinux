/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    OnboardingOverlay — First-run welcome overlay with usage tips.
    Shows once on first menu open, then never again.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

Rectangle {
    id: root

    property bool shouldShow: !Plasmoid.configuration.onboardingCompleted

    visible: shouldShow
    color: Qt.rgba(0, 0, 0, 0.65)
    z: 1000

    Accessible.role: Accessible.Dialog
    Accessible.name: i18n("Welcome overlay, press Enter to dismiss")

    // Fade in
    opacity: 0
    NumberAnimation on opacity {
        id: fadeIn
        from: 0; to: 1
        duration: Kirigami.Units.longDuration
        easing.type: Easing.OutCubic
        running: root.shouldShow
    }

    // Fade out when dismissed
    NumberAnimation {
        id: fadeOut
        target: root
        property: "opacity"
        from: 1; to: 0
        duration: Kirigami.Units.longDuration
        easing.type: Easing.InCubic
        onFinished: {
            root.shouldShow = false
            Plasmoid.configuration.onboardingCompleted = true
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: fadeOut.restart()
    }

    // Content card
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.85, 360)
        height: cardLayout.implicitHeight + 2 * Kirigami.Units.gridUnit
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.highlightColor
        border.width: 1

        Accessible.role: Accessible.Pane
        Accessible.name: i18n("Welcome to BigLinux")

        ColumnLayout {
            id: cardLayout
            anchors {
                fill: parent
                margins: Kirigami.Units.gridUnit
            }
            spacing: Kirigami.Units.largeSpacing

            // Title
            PC3.Label {
                text: i18n("Welcome to BigLinux!")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing

                Accessible.role: Accessible.Heading
                Accessible.name: text
            }

            // Tip 1: Search
            RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: "search"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                PC3.Label {
                    text: i18n("Type to search anything")
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            // Tip 2: Favorites
            RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: "bookmark-new"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                PC3.Label {
                    text: i18n("Right-click to add favorites")
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            // Tip 3: Customize
            RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: "configure"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                PC3.Label {
                    text: i18n("Press the gear icon to customize")
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            // Dismiss button
            PC3.Button {
                text: i18n("Got it!")
                icon.name: "dialog-ok-apply"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                focus: true

                Accessible.role: Accessible.Button
                Accessible.name: i18n("Dismiss welcome overlay")

                onClicked: fadeOut.restart()

                Keys.onReturnPressed: fadeOut.restart()
                Keys.onEnterPressed: fadeOut.restart()
                Keys.onEscapePressed: fadeOut.restart()
            }
        }
    }

    // Keyboard: Escape or Enter dismisses
    Keys.onEscapePressed: fadeOut.restart()
    Keys.onReturnPressed: fadeOut.restart()
    Keys.onEnterPressed: fadeOut.restart()

    // Focus the dismiss button when shown
    onShouldShowChanged: {
        if (shouldShow) {
            card.forceActiveFocus()
        }
    }
}
