/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQml 2.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.ksvg 1.0 as KSvg
import org.kde.kirigami 2.20 as Kirigami
import "../singletons" as Singletons
import "../delegates" as Delegates
import ".."

EmptyPage {
    id: root
    property alias model: view.model
    property alias count: view.count
    property alias currentIndex: view.currentIndex
    property alias currentItem: view.currentItem
    property alias delegate: view.delegate
    property alias blockTargetWheel: wheelHandler.blockTargetWheel
    property alias view: view

    clip: view.height < view.contentHeight

    header: MouseArea {
        implicitHeight: Singletons.MenuSingleton.listItemMetrics.margins.top
        hoverEnabled: true
        onEntered: {
            if (containsMouse) {
                let targetIndex = view.indexAt(mouseX + view.contentX, view.contentY)
                if (targetIndex >= 0) {
                    view.currentIndex = targetIndex
                    view.forceActiveFocus(Qt.MouseFocusReason)
                }
            }
        }
    }

    footer: MouseArea {
        implicitHeight: Singletons.MenuSingleton.listItemMetrics.margins.bottom
        hoverEnabled: true
        onEntered: {
            if (containsMouse) {
                let targetIndex = view.indexAt(mouseX + view.contentX, view.height + view.contentY - 1)
                if (targetIndex >= 0) {
                    view.currentIndex = targetIndex
                    view.forceActiveFocus(Qt.MouseFocusReason)
                }
            }
        }
    }

    GridView {
        id: view
        readonly property real availableWidth: width - leftMargin - rightMargin
        readonly property real availableHeight: height - topMargin - bottomMargin
        readonly property int columns: Math.floor(availableWidth / cellWidth)
        readonly property int rows: Math.floor(availableHeight / cellHeight)
        property bool movedWithKeyboard: false
        property bool movedWithWheel: false

        height: parent.height
        anchors.horizontalCenter: kickoff.mayHaveGridWithScrollBar ? undefined : parent.horizontalCenter
        anchors.horizontalCenterOffset: {
            if (kickoff.mayHaveGridWithScrollBar) {
                return root.mirrored ? verticalScrollBar.implicitWidth / 2 : -verticalScrollBar.implicitWidth / 2
            }
            return 0
        }
        width: Math.min(parent.width, Math.floor((parent.width - leftMargin - rightMargin - (kickoff.mayHaveGridWithScrollBar ? verticalScrollBar.implicitWidth : 0)) / cellWidth) * cellWidth + leftMargin + rightMargin)

        Accessible.role: Accessible.Table
        Accessible.name: i18n("Application grid")
        Accessible.description: i18n("Grid with %1 rows, %2 columns", rows, columns)

        implicitWidth: {
            let w = view.cellWidth * 2 + leftMargin + rightMargin + 2
            if (kickoff.mayHaveGridWithScrollBar) {
                w += verticalScrollBar.implicitWidth
            }
            return w
        }
        implicitHeight: view.cellHeight * kickoff.minimumGridRowCount + topMargin + bottomMargin

        cellHeight: Singletons.MenuSingleton.gridCellSize
        cellWidth: Singletons.MenuSingleton.gridCellSize * 1.8

        currentIndex: count > 0 ? 0 : -1
        focus: true
        interactive: height < contentHeight
        pixelAligned: true
        reuseItems: true
        cacheBuffer: cellHeight * 2
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        keyNavigationWraps: false

        highlightMoveDuration: 0
        highlight: PlasmaExtras.Highlight {
            z: root.currentItem && root.currentItem.Drag.active ? 3 : 0
            pressed: view.currentItem && view.currentItem.isPressed
            active: view.activeFocus
                || (kickoff.contentArea === root
                    && kickoff.searchField.activeFocus)
            width: view.cellWidth
            height: view.cellHeight
        }

        delegate: Delegates.AppDelegate {
            width: view.cellWidth
            displayMode: "grid"
            Accessible.role: Accessible.MenuItem
        }

        move: normalTransition
        moveDisplaced: normalTransition

        Transition {
            id: normalTransition
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                properties: "x, y"
                easing.type: Easing.OutCubic
            }
        }

        PC3.ScrollBar.vertical: PC3.ScrollBar {
            id: verticalScrollBar
            parent: root
            z: 2
            height: root.height
            anchors.right: parent.right
        }

        Kirigami.WheelHandler {
            id: wheelHandler
            target: view
            filterMouseEvents: true
            horizontalStepSize: 20 * Qt.styleHints.wheelScrollLines
            verticalStepSize: 20 * Qt.styleHints.wheelScrollLines

            onWheel: wheel => {
                view.movedWithWheel = true
                view.movedWithKeyboard = false
                movedWithWheelTimer.restart()
            }
        }

        Connections {
            target: kickoff
            function onExpandedChanged() {
                if (kickoff.expanded) {
                    view.currentIndex = 0
                    view.positionViewAtBeginning()
                }
            }
        }

        Timer {
            id: movedWithKeyboardTimer
            interval: 200
            onTriggered: view.movedWithKeyboard = false
        }

        Timer {
            id: movedWithWheelTimer
            interval: 200
            onTriggered: view.movedWithWheel = false
        }

        function focusCurrentItem(event, focusReason) {
            currentItem.forceActiveFocus(focusReason)
            event.accepted = true
        }

        Keys.onMenuPressed: event => {
            if (currentItem !== null) {
                currentItem.forceActiveFocus(Qt.ShortcutFocusReason)
                currentItem.openActionMenu()
            }
        }

        Keys.onPressed: event => {
            let targetX = currentItem ? currentItem.x : contentX
            let targetY = currentItem ? currentItem.y : contentY
            let targetIndex = currentIndex
            const atLeft = currentIndex % columns === (Qt.application.layoutDirection == Qt.RightToLeft ? columns - 1 : 0)
            const isLeading = currentIndex % columns === 0
            let atTop = currentIndex < columns
            const atRight = currentIndex % columns === (Qt.application.layoutDirection == Qt.RightToLeft ? 0 : columns - 1)
            const isTrailing = currentIndex % columns === columns - 1
            let atBottom = currentIndex >= count - columns

            if (count > 1) {
                switch (event.key) {
                    case Qt.Key_Left: if (!atLeft && !kickoff.searchField.activeFocus) {
                        moveCurrentIndexLeft()
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } break
                    case Qt.Key_Up: if (!atTop) {
                        moveCurrentIndexUp()
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } break
                    case Qt.Key_Right: if (!atRight && !kickoff.searchField.activeFocus) {
                        moveCurrentIndexRight()
                        focusCurrentItem(event, Qt.TabFocusReason)
                    } break
                    case Qt.Key_Down: if (!atBottom) {
                        moveCurrentIndexDown()
                        focusCurrentItem(event, Qt.TabFocusReason)
                    } break
                    case Qt.Key_Home: if (event.modifiers === Qt.ControlModifier && currentIndex !== 0) {
                        currentIndex = 0
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } else if (!isLeading) {
                        targetIndex -= currentIndex % columns
                        currentIndex = Math.max(targetIndex, 0)
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } break
                    case Qt.Key_End: if (event.modifiers === Qt.ControlModifier && currentIndex !== count - 1) {
                        currentIndex = count - 1
                        focusCurrentItem(event, Qt.TabFocusReason)
                    } else if (!isTrailing) {
                        targetIndex += columns - 1 - (currentIndex % columns)
                        currentIndex = Math.min(targetIndex, count - 1)
                        focusCurrentItem(event, Qt.TabFocusReason)
                    } break
                    case Qt.Key_PageUp: if (!atTop) {
                        targetY = targetY - height + 1
                        targetIndex = indexAt(targetX, targetY)
                        while (targetIndex === -1) { targetY += 1; targetIndex = indexAt(targetX, targetY); }
                        currentIndex = Math.max(targetIndex, 0)
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } break
                    case Qt.Key_PageDown: if (!atBottom) {
                        targetY = targetY + height - 1
                        targetIndex = indexAt(targetX, targetY)
                        while (targetIndex === -1) { targetY -= 1; targetIndex = indexAt(targetX, targetY); }
                        currentIndex = Math.min(targetIndex, count - 1)
                        focusCurrentItem(event, Qt.TabFocusReason)
                    } break
                }
            }
            movedWithKeyboard = event.accepted
            if (movedWithKeyboard) { movedWithKeyboardTimer.restart(); }
        }
    }
}
