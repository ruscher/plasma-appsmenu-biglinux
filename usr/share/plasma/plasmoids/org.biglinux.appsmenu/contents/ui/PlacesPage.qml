/*
    SPDX-FileCopyrightText: 2026 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    PlacesPage — "continue where you left off".

    Five categories, Frequently Used first:

        Frequently Used   apps, folders and files the user actually reaches for
        Computer          system apps, places, network, and storage devices
        History Apps      recently used applications
        History Files     recently used files
        History Folders   recently used folders

    Everything on this page is real data from KDE:

      * Frequently Used and the three histories are Kicker RecentUsageModels.
        `ordering: Popular` is the activity manager's HighScoredFirst, and the
        query is already scoped to Activity::current(), so the ranking is KDE's
        own and follows the current activity without anything here re-sorting.
      * Computer is Kicker's ComputerModel, which wraps KFilePlacesModel and
        already reports Applications / Places / Remote groups; the section
        headings come from that `group` role.
      * Devices come from the Solid data engines (see components/DeviceSection).

    Previously this page lived inline in FullRepresentation.qml as a sidebar
    plus one list whose model was picked by index. It moved out here because it
    now has real structure, and because keeping FullRepresentation focused on
    the StackView keeps the crash-prone part small.
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
import "singletons" as Singletons

EmptyPage {
    id: root

    objectName: "placesPage"

    Accessible.role: Accessible.Pane
    Accessible.name: i18n("Places")

    /* Category indices, named so the switch statements read as prose. */
    readonly property int categoryFrequent: 0
    readonly property int categoryComputer: 1
    readonly property int categoryHistoryApps: 2
    readonly property int categoryHistoryFiles: 3
    readonly property int categoryHistoryFolders: 4

    /* Which category is showing. This property is the authority; the sidebar's
       own currentIndex only mirrors it.

       It cannot be derived from categorySidebar.currentIndex, because
       AccessibleListView's inner ListView carries
       `currentIndex: count > 0 ? 0 : -1`. That binding is evaluated lazily, so
       it can still be holding -1 after the model is full and then snap back to
       0 seconds later, overwriting any selection made in between. Keeping the
       category here, and filling the sidebar model up front (see below) so the
       binding settles exactly once, avoids fighting it.

       Frequently Used is always the entry point, as the brief requires — the
       last visited category is deliberately not restored. */
    property int currentCategory: categoryFrequent

    /* Re-assert after AppDelegate's action writes view.currentIndex directly,
       which breaks the declarative binding on the sidebar. */
    onCurrentCategoryChanged: categorySidebar.currentIndex = currentCategory

    /* Which of the single-model categories is showing, if any. */
    readonly property var historyModel: {
        switch (root.currentCategory) {
        case root.categoryHistoryApps: return kickoff.recentUsageModel
        case root.categoryHistoryFiles: return kickoff.recentDocsModel
        case root.categoryHistoryFolders: return kickoff.recentFoldersModel
        default: return null
        }
    }

    readonly property bool showingHistory: root.currentCategory >= root.categoryHistoryApps

    /* Everything except Computer depends on the activity history being on. */
    readonly property bool needsActivityHistory: root.currentCategory !== root.categoryComputer

    T.StackView.onActivated: {
        kickoff.sideBar = categorySidebar
        kickoff.contentArea = root
    }

    /* Header.onAccepted (Enter in the search field) and the keyboard forwarding
       both expect these from whatever page is current. */
    readonly property Item view: historyList.view
    readonly property Item currentItem: historyList.currentItem

    Components.RecentActivityTracking {
        id: recentActivity
    }

    Connections {
        target: kickoff
        function onExpandedChanged() {
            if (kickoff.expanded) {
                recentActivity.refresh()
            }
        }
    }

    /* Note: the category is deliberately NOT reset here.
       FullRepresentation replaces the stack item every time Places is opened,
       so a fresh PlacesPage is built with currentCategory already at
       categoryFrequent — that is what makes Frequently Used the entry point.
       Resetting on kickoff.expandedChanged as well was actively harmful:
       `expanded` was observed re-firing `true` while the menu was already
       open, which threw the user back to Frequently Used mid-session. */

    function categoryLabel(key) {
        switch (key) {
        case "frequent":       return i18nc("@title Places category", "Frequently Used")
        case "computer":       return i18nc("@title Places category", "Computer")
        case "historyApps":    return i18nc("@title Places category", "History Apps")
        case "historyFiles":   return i18nc("@title Places category", "History Files")
        case "historyFolders": return i18nc("@title Places category", "History Folders")
        default:               return ""
        }
    }

    function categoryIcon(key) {
        switch (key) {
        case "frequent": return "starred-symbolic"
        case "computer":
            return (Singletons.MenuSingleton.powerManagement.data["PowerDevil"]
                && Singletons.MenuSingleton.powerManagement.data["PowerDevil"]["Is Lid Present"])
                ? "computer-laptop" : "computer"
        case "historyApps":    return "applications-all"
        case "historyFiles":   return "document-open-recent"
        case "historyFolders": return "folder-open-recent"
        default:               return ""
        }
    }

    function activateCategory(index) {
        if (index < 0 || index > root.categoryHistoryFolders) {
            return
        }
        root.currentCategory = index
    }

    contentItem: RowLayout {
        spacing: 0

        // ── Category sidebar ──
        // A plain ListView rather than Components.AccessibleListView: that
        // component's inner view carries `currentIndex: count > 0 ? 0 : -1`,
        // which it re-asserts at moments outside our control. It was observed
        // snapping the selection back to Frequently Used seconds after a
        // category was chosen, when an unrelated relayout (the device list
        // filling in) re-evaluated it. Owning the selection outright here is
        // simpler than fighting that, and this sidebar needs none of what
        // AccessibleListView adds — no sections, no empty state, five rows.
        ListView {
            id: categorySidebar

            Layout.preferredWidth: kickoff.fullRepresentationItem
                ? kickoff.fullRepresentationItem.preferredSideBarWidth + kickoff.backgroundMetrics.leftPadding
                : Singletons.MenuSingleton.gridCellSize * 2
            Layout.fillHeight: true

            clip: true
            interactive: height < contentHeight
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            keyNavigationWraps: false
            reuseItems: false
            leftMargin: kickoff.backgroundMetrics.leftPadding
            currentIndex: root.currentCategory

            readonly property real availableWidth: width - leftMargin - rightMargin
            /* AppDelegate consults these before letting a hover take focus. */
            property bool movedWithKeyboard: false
            property bool movedWithWheel: false

            Accessible.role: Accessible.PageTabList
            Accessible.name: i18n("Places categories")

            highlightMoveDuration: 0
            highlightResizeDuration: 0
            highlight: PlasmaExtras.Highlight {
                active: categorySidebar.activeFocus
            }

            /* ListElements rather than appends in Component.onCompleted, so the
               row count is final before the view binds to the model.
               ListElement cannot hold an i18n() call, so rows carry stable keys
               and the labels are resolved in the delegate. */
            model: ListModel {
                id: placesCategoryModel
                ListElement { key: "frequent" }
                ListElement { key: "computer" }
                ListElement { key: "historyApps" }
                ListElement { key: "historyFiles" }
                ListElement { key: "historyFolders" }
            }

            delegate: Delegates.AppDelegate {
                width: categorySidebar.availableWidth
                text: root.categoryLabel(model.key)
                decoration: root.categoryIcon(model.key)
                isCategoryListItem: true
                displayMode: "list"
                hoverEnabled: true
                onClicked: root.activateCategory(index)
            }

            Keys.onUpPressed: event => {
                if (root.currentCategory > 0) {
                    categorySidebar.movedWithKeyboard = true
                    root.activateCategory(root.currentCategory - 1)
                }
            }
            Keys.onDownPressed: event => {
                if (root.currentCategory < root.categoryHistoryFolders) {
                    categorySidebar.movedWithKeyboard = true
                    root.activateCategory(root.currentCategory + 1)
                }
            }
            Keys.onRightPressed: event => contentArea.focusContent()
            Keys.onReturnPressed: event => contentArea.focusContent()
            Keys.onEnterPressed: event => contentArea.focusContent()
        }

        // ── Content ──
        Item {
            id: contentArea

            Layout.fillWidth: true
            Layout.fillHeight: true

            function focusContent() {
                if (root.needsActivityHistory && !recentActivity.tracking) {
                    enableHistoryButton.forceActiveFocus(Qt.TabFocusReason)
                } else if (root.currentCategory === root.categoryFrequent) {
                    frequentView.focusFirstSection()
                } else if (root.currentCategory === root.categoryComputer) {
                    computerView.focusFirstSection()
                } else {
                    historyList.forceActiveFocus(Qt.TabFocusReason)
                }
            }

            // ── The activity history is off ──
            // Every category except Computer is empty without it, so say so and
            // offer the fix rather than showing five blank lists.
            Loader {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 22)
                active: root.needsActivityHistory && !recentActivity.tracking
                visible: active
                z: 2

                sourceComponent: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "view-history"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                        opacity: 0.8
                    }

                    PC3.Label {
                        Layout.fillWidth: true
                        text: i18n("Recent activity is turned off")
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        Accessible.role: Accessible.Heading
                    }

                    PC3.Label {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        text: i18n("Enable activity history to see recently and frequently used apps, files, and folders.")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    PC3.Button {
                        id: enableHistoryButton
                        Layout.alignment: Qt.AlignHCenter
                        icon.name: "view-history"
                        text: recentActivity.busy ? i18n("Turning on…") : i18n("Turn On")
                        enabled: !recentActivity.busy
                        activeFocusOnTab: true

                        Accessible.role: Accessible.Button
                        Accessible.name: text
                        Accessible.description: i18n("Enable the KDE activity history that records recently used applications, files and folders")

                        onClicked: recentActivity.enable()
                    }

                    PC3.Button {
                        Layout.alignment: Qt.AlignHCenter
                        flat: true
                        text: i18n("Activity History Settings")
                        activeFocusOnTab: true

                        Accessible.role: Accessible.Button
                        Accessible.name: text

                        onClicked: recentActivity.openSettings()
                    }
                }
            }

            // ── Frequently Used ──
            Flickable {
                id: frequentView

                anchors.fill: parent
                visible: root.currentCategory === root.categoryFrequent
                    && recentActivity.tracking
                enabled: visible
                clip: true
                contentWidth: width
                contentHeight: frequentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                PC3.ScrollBar.vertical: PC3.ScrollBar {}

                function focusFirstSection() {
                    if (frequentApps.focusFirst()) return
                    if (frequentFolders.focusFirst()) return
                    frequentFiles.focusFirst()
                }

                ColumnLayout {
                    id: frequentColumn
                    width: frequentView.width
                    spacing: Kirigami.Units.smallSpacing

                    Components.ActivitySection {
                        id: frequentApps
                        Layout.fillWidth: true
                        title: i18nc("@title:group", "Applications")
                        iconName: "applications-all"
                        model: kickoff.frequentAppsModel
                        onFocusPreviousRequested: categorySidebar.forceActiveFocus(Qt.BacktabFocusReason)
                        onFocusNextRequested: {
                            if (!frequentFolders.focusFirst()) frequentFiles.focusFirst()
                        }
                    }

                    Components.ActivitySection {
                        id: frequentFolders
                        Layout.fillWidth: true
                        title: i18nc("@title:group", "Folders")
                        iconName: "folder"
                        model: kickoff.frequentFoldersModel
                        onFocusPreviousRequested: {
                            if (!frequentApps.focusLast()) categorySidebar.forceActiveFocus(Qt.BacktabFocusReason)
                        }
                        onFocusNextRequested: frequentFiles.focusFirst()
                    }

                    Components.ActivitySection {
                        id: frequentFiles
                        Layout.fillWidth: true
                        title: i18nc("@title:group", "Files")
                        iconName: "document-multiple"
                        model: kickoff.frequentDocsModel
                        onFocusPreviousRequested: {
                            if (!frequentFolders.focusLast()) frequentApps.focusLast()
                        }
                    }

                    // Nothing recorded yet — history is on, but new.
                    Loader {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.gridUnit * 2
                        active: frequentApps.count === 0 && frequentFolders.count === 0
                            && frequentFiles.count === 0
                        visible: active
                        sourceComponent: PlasmaExtras.PlaceholderMessage {
                            iconName: "starred-symbolic"
                            text: i18nc("@info:status", "Nothing here yet")
                            explanation: i18n("Applications, files and folders you use often will appear here.")
                            Accessible.role: Accessible.StaticText
                        }
                    }

                    Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
                }
            }

            // ── Computer ──
            Flickable {
                id: computerView

                anchors.fill: parent
                visible: root.currentCategory === root.categoryComputer
                enabled: visible
                clip: true
                contentWidth: width
                contentHeight: computerColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                PC3.ScrollBar.vertical: PC3.ScrollBar {}

                function focusFirstSection() {
                    if (computerList.count > 0) {
                        computerList.currentIndex = 0
                        computerList.forceActiveFocus(Qt.TabFocusReason)
                        return
                    }
                    deviceSection.focusFirst()
                }

                ColumnLayout {
                    id: computerColumn
                    width: computerView.width
                    spacing: Kirigami.Units.smallSpacing

                    /* ComputerModel already groups itself into Applications /
                       Places / Remote, so this keeps the section delegate. */
                    ListView {
                        id: computerList

                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight

                        interactive: false
                        reuseItems: true
                        keyNavigationEnabled: false
                        keyNavigationWraps: false
                        currentIndex: -1
                        model: kickoff.computerModel

                        readonly property real availableWidth: width - leftMargin - rightMargin
                        property bool movedWithKeyboard: false
                        property bool movedWithWheel: false

                        Accessible.role: Accessible.List
                        Accessible.name: i18n("Computer")

                        delegate: Delegates.AppDelegate {
                            width: computerList.availableWidth
                            displayMode: "list"
                        }

                        section {
                            property: "group"
                            criteria: ViewSection.FullString
                            delegate: RowLayout {
                                width: computerList.availableWidth
                                height: Singletons.MenuSingleton.compactListDelegateHeight
                                PC3.Label {
                                    Layout.leftMargin: Kirigami.Units.smallSpacing
                                    text: section
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.disabledTextColor
                                    Accessible.role: Accessible.Heading
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }

                        Keys.onUpPressed: event => {
                            if (computerList.currentIndex > 0) {
                                computerList.currentIndex--
                                if (computerList.currentItem) computerList.currentItem.forceActiveFocus(Qt.BacktabFocusReason)
                            } else {
                                categorySidebar.forceActiveFocus(Qt.BacktabFocusReason)
                            }
                        }
                        Keys.onDownPressed: event => {
                            if (computerList.currentIndex < computerList.count - 1) {
                                computerList.currentIndex++
                                if (computerList.currentItem) computerList.currentItem.forceActiveFocus(Qt.TabFocusReason)
                            } else {
                                deviceSection.focusFirst()
                            }
                        }
                        Keys.onLeftPressed: event => categorySidebar.forceActiveFocus(Qt.BacktabFocusReason)
                    }

                    Components.DeviceSection {
                        id: deviceSection
                        Layout.fillWidth: true
                        onFocusPreviousRequested: {
                            if (computerList.count > 0) {
                                computerList.currentIndex = computerList.count - 1
                                computerList.forceActiveFocus(Qt.BacktabFocusReason)
                            } else {
                                categorySidebar.forceActiveFocus(Qt.BacktabFocusReason)
                            }
                        }
                    }

                    Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
                }
            }

            // ── History Apps / Files / Folders ──
            Components.AccessibleListView {
                id: historyList

                anchors.fill: parent
                visible: root.showingHistory && recentActivity.tracking
                enabled: visible

                mainContentView: true
                model: root.historyModel
                emptyText: {
                    switch (root.currentCategory) {
                    case root.categoryHistoryApps:
                        return i18nc("@info:status", "No recently used applications yet")
                    case root.categoryHistoryFiles:
                        return i18nc("@info:status", "No recently used files yet")
                    case root.categoryHistoryFolders:
                        return i18nc("@info:status", "No recently used folders yet")
                    default:
                        return ""
                    }
                }

                emptyIconName: {
                    switch (root.currentCategory) {
                    case root.categoryHistoryApps: return "applications-all"
                    case root.categoryHistoryFiles: return "document-open-recent"
                    case root.categoryHistoryFolders: return "folder-open-recent"
                    default: return "edit-none"
                    }
                }

                Accessible.role: Accessible.List

                Keys.onLeftPressed: event => categorySidebar.forceActiveFocus(Qt.BacktabFocusReason)
            }
        }
    }
}
