/*
    SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQml 2.15
import org.kde.plasma.plasmoid 2.0
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
    property alias section: view.section
    property alias highlight: view.highlight
    property alias view: view

    property bool mainContentView: false
    property bool hasSectionView: false

    // Empty state shown when the model has no rows (main content only).
    // Set to "" to disable (sidebars, search page with its own placeholder).
    property string emptyText: mainContentView ? i18nc("@info:status", "No applications here yet") : ""

    signal showSectionViewRequested(string sectionName)

    clip: view.height < view.contentHeight

    Loader {
        parent: root
        anchors.centerIn: parent
        width: parent ? parent.width - Kirigami.Units.gridUnit * 4 : 0
        z: 1
        active: view.count === 0 && root.emptyText.length > 0
        visible: active
        asynchronous: true
        sourceComponent: PlasmaExtras.PlaceholderMessage {
            iconName: "edit-none"
            text: root.emptyText
            Accessible.role: Accessible.StaticText
        }
    }

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

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth,
                            implicitHeaderWidth2,
                            implicitFooterWidth2)

    leftPadding: verticalScrollBar.visible && root.mirrored ? verticalScrollBar.implicitWidth : 0
    rightPadding: verticalScrollBar.visible && !root.mirrored ? verticalScrollBar.implicitWidth : 0

    contentItem: ListView {
        id: view

        readonly property real availableWidth: width - leftMargin - rightMargin
        readonly property real availableHeight: height - topMargin - bottomMargin
        property bool movedWithKeyboard: false
        property bool movedWithWheel: false

        Accessible.role: Accessible.List
        Accessible.name: i18n("Application list")

        implicitWidth: {
            let totalMargins = leftMargin + rightMargin
            if (mainContentView) {
                if (kickoff.mayHaveGridWithScrollBar) {
                    totalMargins += verticalScrollBar.implicitWidth
                }
                return Singletons.MenuSingleton.gridCellSize * kickoff.minimumGridRowCount + totalMargins
            }
            return contentWidth + totalMargins
        }
        implicitHeight: {
            let h = Singletons.MenuSingleton.gridCellSize * kickoff.minimumGridRowCount
            if (Plasmoid.configuration.favoritesDisplay !== 0 && Plasmoid.configuration.applicationsDisplay !== 0) {
                h = Math.floor(h / kickoff.listDelegateHeight) * kickoff.listDelegateHeight
            }
            return h + topMargin + bottomMargin
        }

        leftMargin: kickoff.backgroundMetrics.leftPadding
        rightMargin: kickoff.backgroundMetrics.rightPadding

        currentIndex: count > 0 ? 0 : -1
        focus: true
        interactive: height < contentHeight
        pixelAligned: true
        reuseItems: true
        cacheBuffer: kickoff.listDelegateHeight * 4
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        keyNavigationWraps: false

        highlightResizeDuration: 0
        highlightMoveDuration: 0
        highlight: PlasmaExtras.Highlight {
            z: root.currentItem && root.currentItem.Drag.active ? 3 : 0
            // Coerce: a non-AppDelegate currentItem (e.g. sidebar ItemDelegate) has no isPressed
            pressed: !!view.currentItem && view.currentItem.isPressed === true && view.currentItem.isCategoryListItem !== true
            // searchField is null until Header binds it; guard so this stays bool
            active: view.activeFocus
                || (kickoff.contentArea === root
                    && !!kickoff.searchField && kickoff.searchField.activeFocus)
        }

        delegate: Delegates.AppDelegate {
            width: view.availableWidth
            displayMode: "list"
        }

        section {
            property: "group"
            criteria: ViewSection.FullString
            delegate: PC3.AbstractButton {
                width: view.availableWidth
                height: Singletons.MenuSingleton.compactListDelegateHeight
                Accessible.role: Accessible.Heading
                Accessible.name: section

                PC3.Label {
                    id: contentLabel
                    anchors.left: parent.left
                    width: section.length === 1
                        ? Singletons.MenuSingleton.compactListDelegateContentHeight + leftPadding + rightPadding
                        : parent.width
                    height: parent.height
                    leftPadding: view.effectiveLayoutDirection === Qt.LeftToRight
                        ? Singletons.MenuSingleton.listItemMetrics.margins.left : 0
                    rightPadding: view.effectiveLayoutDirection === Qt.RightToLeft
                        ? Singletons.MenuSingleton.listItemMetrics.margins.right : 0
                    horizontalAlignment: section.length === 1 ? Text.AlignHCenter : Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    font.pixelSize: Singletons.MenuSingleton.compactListDelegateContentHeight
                    enabled: hoverHandler.hovered
                    text: section.length === 1 ? section.toUpperCase() : section
                    textFormat: Text.PlainText
                }

                HoverHandler {
                    id: hoverHandler
                    enabled: root.hasSectionView
                    cursorShape: enabled ? Qt.PointingHandCursor : undefined
                }

                onClicked: root.showSectionViewRequested(contentLabel.text)
            }
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
            let atFirst = currentIndex === 0
            let atLast = currentIndex === count - 1
            if (count > 1) {
                switch (event.key) {
                    case Qt.Key_Up: if (!atFirst) {
                        decrementCurrentIndex()
                        if (currentItem.isSeparator) { decrementCurrentIndex(); }
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } break
                    case Qt.Key_Down: if (!atLast) {
                        incrementCurrentIndex()
                        if (currentItem.isSeparator) { incrementCurrentIndex(); }
                        focusCurrentItem(event, Qt.TabFocusReason)
                    } break
                    case Qt.Key_Home: if (!atFirst) {
                        currentIndex = 0
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } break
                    case Qt.Key_End: if (!atLast) {
                        currentIndex = count - 1
                        focusCurrentItem(event, Qt.TabFocusReason)
                    } break
                    case Qt.Key_PageUp: if (!atFirst) {
                        targetY = targetY - height + 1
                        targetIndex = indexAt(targetX, targetY)
                        while (targetIndex === -1) { targetY += 1; targetIndex = indexAt(targetX, targetY); }
                        currentIndex = Math.max(targetIndex, 0)
                        focusCurrentItem(event, Qt.BacktabFocusReason)
                    } break
                    case Qt.Key_PageDown: if (!atLast) {
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
