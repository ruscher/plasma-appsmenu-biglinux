/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    SearchResultsPage — the KRunner results, plus an optional "Software"
    section offering to install something that is not on the system yet.

    The results list is KRunner's own model and is shown exactly as KRunner
    orders it: Kicker's RunnerModel runs with mergeResults, so modelForRow(0)
    is a KRunner::ResultsModel and row 0 is the single merged model rather than
    "the first runner". Ranking and grouping therefore come from KRunner, and
    the category headings come free from the model's "group" role (see
    components/AccessibleListView.qml).

    The software suggestions live *below* the list and never mix into it, so a
    package can never outrank a real local result, and KRunner's model is left
    untouched.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.15 as T
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kitemmodels as KItemModels
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

    // Expose the internal view for keyboard forwarding, and the current item
    // so Header.onAccepted (Enter) can launch the top result.
    readonly property alias view: searchList.view
    readonly property alias currentItem: searchList.currentItem

    // Action for Enter key
    property Item action: searchList.currentItem

    readonly property string queryText: kickoff.searchField ? kickoff.searchField.text : ""

    readonly property var resultsModel: kickoff.runnerModel.count
        ? kickoff.runnerModel.modelForRow(0) : null

    // True when an installed application already matches. Software suggestions
    // stay hidden then, so the user never sees "Install Firefox" next to the
    // Firefox they already have.
    //
    // Detected through the untranslated favouriteId ("applications:<desktop
    // id>"), which RunnerMatchesModel fills in only for the services runner —
    // matching on the localised category name would break outside English.
    property bool hasInstalledAppMatch: false

    function refreshInstalledAppMatch() {
        const model = root.resultsModel
        if (!model || model.count === 0) {
            root.hasInstalledAppMatch = false
            return
        }
        const role = model.KItemModels.KRoleNames.role("favoriteId")
        const limit = Math.min(model.count, 25)
        for (let i = 0; i < limit; ++i) {
            const favoriteId = model.data(model.index(i, 0), role)
            if (favoriteId && String(favoriteId).indexOf("applications:") === 0) {
                root.hasInstalledAppMatch = true
                return
            }
        }
        root.hasInstalledAppMatch = false
    }

    Connections {
        target: kickoff.runnerModel
        function onQueryFinished() {
            root.refreshInstalledAppMatch()
        }
    }

    /* Shared instance from main.qml — see the comment there. The page only
       feeds it the current query and tells it when to stay quiet. */
    readonly property var softwareSearch: kickoff.softwareSearch

    Binding {
        target: kickoff.softwareSearch
        property: "query"
        value: root.queryText
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: kickoff.softwareSearch
        property: "suppressed"
        value: root.hasInstalledAppMatch
        restoreMode: Binding.RestoreBindingOrValue
    }

    contentItem: ColumnLayout {
        spacing: 0

        Components.AccessibleListView {
            id: searchList
            Layout.fillWidth: true
            Layout.fillHeight: true

            mainContentView: true
            focus: true
            emptyText: "" // this page renders its own "No matches" placeholder

            // Forces the function be re-run every time runnerModel.count changes
            model: root.resultsModel

            delegate: Delegates.AppDelegate {
                width: view.availableWidth
                displayMode: "list"
                isSearchResult: true
            }

            activeFocusOnTab: true

            Accessible.name: i18n("Search results list")
            Accessible.role: Accessible.List

            Keys.onTabPressed: event => {
                if (softwareList.count > 0) {
                    softwareList.itemAt(0).forceActiveFocus(Qt.TabFocusReason);
                } else if (kickoff.searchField) {
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
                    // root.parent can go null during a page transition; guard the deref.
                    if (root.parent && root.parent.hasOwnProperty("blockingHoverFocus")) {
                        root.parent.blockingHoverFocus = false
                    }
                }
            }

            HoverHandler {
                id: blockHoverFocusHandler
                enabled: root.parent !== null
                    && !(root.parent.hasOwnProperty("busy") && root.parent.busy)
                    && (!root.interceptedPosition || (root.parent && root.parent.hasOwnProperty("blockingHoverFocus") && root.parent.blockingHoverFocus))
            }

            // "No matches" placeholder. Only when there is nothing to offer at
            // all — with a software suggestion on screen the page is not empty.
            Loader {
                anchors.centerIn: searchList.view
                width: searchList.view.width - (Kirigami.Units.gridUnit * 4)

                active: searchList.view.count === 0 && softwareSection.rowCount === 0 && !softwareSearch.busy
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

        // ── Software available to install ──
        ColumnLayout {
            id: softwareSection

            readonly property int rowCount: softwareSearch.count

            Layout.fillWidth: true
            Layout.leftMargin: kickoff.backgroundMetrics.leftPadding
            Layout.rightMargin: kickoff.backgroundMetrics.rightPadding
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: 0

            visible: rowCount > 0

            Accessible.role: Accessible.Grouping
            Accessible.name: i18nc("@title:group software that can be installed", "Software")

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            PC3.Label {
                text: i18nc("@title:group software that can be installed", "Software")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                Accessible.role: Accessible.Heading
            }

            Repeater {
                id: softwareList
                model: softwareSearch.packages

                delegate: PC3.ItemDelegate {
                    id: softwareDelegate

                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 2.5
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: i18nc("@action:button %1 is a package name",
                                           "Install %1 with Pamac", modelData)
                    Accessible.description: i18n("Not installed. Opens Pamac so you can review and install it.")

                    PC3.ToolTip.text: i18n("Opens Pamac on this package. Nothing is installed until you confirm there.")
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "system-software-install"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            PC3.Label {
                                Layout.fillWidth: true
                                text: softwareDelegate.modelData
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                textFormat: Text.PlainText
                            }

                            PC3.Label {
                                Layout.fillWidth: true
                                // --repos is used for the lookup, so the origin
                                // is always the official repositories; AUR and
                                // Flatpak are deliberately not queried.
                                text: i18nc("@info:usage", "Not installed · Official repositories")
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                textFormat: Text.PlainText
                            }
                        }

                        PC3.Label {
                            text: i18nc("@action:button", "Install with Pamac")
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.highlightColor
                            visible: softwareDelegate.hovered || softwareDelegate.activeFocus
                            textFormat: Text.PlainText
                        }
                    }

                    onClicked: {
                        softwareSearch.openPackage(softwareDelegate.modelData)
                        if (kickoff.hideOnWindowDeactivate) {
                            kickoff.expanded = false
                        }
                    }

                    Keys.onTabPressed: event => {
                        if (softwareDelegate.index === softwareList.count - 1 && kickoff.searchField) {
                            kickoff.searchField.forceActiveFocus(Qt.TabFocusReason)
                        } else {
                            event.accepted = false
                        }
                    }
                }
            }
        }
    }
}
