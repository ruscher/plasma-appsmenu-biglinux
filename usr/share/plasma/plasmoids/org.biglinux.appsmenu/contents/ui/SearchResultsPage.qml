/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    SearchResultsPage — Displays categorized search results
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.15 as T
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "components" as Components
import "delegates" as Delegates

EmptyPage {
    id: root

    objectName: "searchView"

    Accessible.name: i18n("Search results")
    Accessible.role: Accessible.Pane

    property var interceptedPosition: null

    T.StackView.onActivated: {
        kickoff.sideBar = null
        kickoff.contentArea = root
    }

    // Expose the internal view for keyboard forwarding
    readonly property alias view: searchList.view

    // Action for Enter key
    property Item action: searchList.currentItem

    contentItem: Components.AccessibleListView {
        id: searchList
        mainContentView: true
        focus: true

        // Forces the function be re-run every time runnerModel.count changes
        model: kickoff.runnerModel.count ? kickoff.runnerModel.modelForRow(0) : null

        delegate: Delegates.AppDelegate {
            width: view.availableWidth
            displayMode: "list"
            isSearchResult: true
        }

        activeFocusOnTab: true

        Accessible.name: i18n("Search results list")
        Accessible.role: Accessible.List

        Keys.onTabPressed: event => {
            if (kickoff.searchField) {
                kickoff.searchField.forceActiveFocus(Qt.TabFocusReason);
            }
        }
        Keys.onBacktabPressed: event => {
            if (kickoff.searchField) {
                kickoff.searchField.forceActiveFocus(Qt.BacktabFocusReason);
            }
        }

        Connections {
            target: blockHoverFocusHandler
            enabled: blockHoverFocusHandler.enabled && !root.interceptedPosition
            function onPointChanged() {
                root.interceptedPosition = blockHoverFocusHandler.point.position
            }
        }

        Connections {
            target: blockHoverFocusHandler
            enabled: blockHoverFocusHandler.enabled && root.interceptedPosition && root.parent && root.parent.hasOwnProperty("blockingHoverFocus") && root.parent.blockingHoverFocus
            function onPointChanged() {
                if (blockHoverFocusHandler.point.position === root.interceptedPosition) {
                    return;
                }
                root.parent.blockingHoverFocus = false
            }
        }

        HoverHandler {
            id: blockHoverFocusHandler
            enabled: root.parent !== null
                && !(root.parent.hasOwnProperty("busy") && root.parent.busy)
                && (!root.interceptedPosition || (root.parent && root.parent.hasOwnProperty("blockingHoverFocus") && root.parent.blockingHoverFocus))
        }

        // "No matches" placeholder
        Loader {
            anchors.centerIn: searchList.view
            width: searchList.view.width - (Kirigami.Units.gridUnit * 4)

            active: searchList.view.count === 0
            visible: active
            asynchronous: true

            sourceComponent: PlasmaExtras.PlaceholderMessage {
                id: emptyHint

                iconName: "edit-none"
                opacity: 0
                text: i18nc("@info:status", "No matches")

                Accessible.name: i18nc("@info:status", "No matches found for your search")
                Accessible.role: Accessible.StaticText

                Connections {
                    target: kickoff.runnerModel
                    function onQueryFinished() {
                        showAnimation.restart()
                    }
                }

                NumberAnimation {
                    id: showAnimation
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                    property: "opacity"
                    target: emptyHint
                    to: 1
                }
            }
        }
    }
}
