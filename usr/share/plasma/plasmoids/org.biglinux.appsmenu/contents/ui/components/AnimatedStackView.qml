/*
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Templates 2.15 as T
import org.kde.kirigami 2.20 as Kirigami

T.StackView {
    id: root

    property bool reverseTransitions: false
    property bool movementTransitionsEnabled: true
    // "horizontal" or "vertical"
    property string orientation: "horizontal"

    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    clip: busy
    contentItem: currentItem

    Accessible.ignored: true

    popEnter: enterTransition
    popExit: exitTransition
    pushEnter: enterTransition
    pushExit: exitTransition
    replaceEnter: enterTransition
    replaceExit: exitTransition

    Transition {
        id: enterTransition
        NumberAnimation {
            property: root.orientation === "horizontal" ? "x" : "y"
            from: {
                const size = root.orientation === "horizontal" ? root.width : root.height;
                const direction = root.reverseTransitions ? -0.5 : 0.5;
                if (root.orientation === "horizontal") {
                    return direction * (root.mirrored ? -1 : 1) * -size;
                }
                return direction * -size;
            }
            to: 0
            duration: root.movementTransitionsEnabled ? Kirigami.Units.longDuration : 0
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }

    Transition {
        id: exitTransition
        NumberAnimation {
            property: root.orientation === "horizontal" ? "x" : "y"
            from: 0
            to: {
                const size = root.orientation === "horizontal" ? root.width : root.height;
                const direction = root.reverseTransitions ? -0.5 : 0.5;
                if (root.orientation === "horizontal") {
                    return direction * (root.mirrored ? -1 : 1) * size;
                }
                return direction * size;
            }
            duration: root.movementTransitionsEnabled ? Kirigami.Units.longDuration : 0
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }
}
