/*
    SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick 2.15
import QtQuick.Templates 2.15 as T
import QtQuick.Layouts 1.15
import QtQml 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PC3

import "components" as Components
import "delegates" as Delegates
import "singletons" as Singletons

EmptyPage {
    id: root

    leftPadding: -kickoff.backgroundMetrics.leftPadding
    rightPadding: -kickoff.backgroundMetrics.rightPadding
    topPadding: 0
    bottomPadding: -kickoff.backgroundMetrics.bottomPadding
    readonly property var appletInterface: kickoff

    Layout.minimumWidth: implicitWidth
    Layout.maximumWidth: Kirigami.Units.gridUnit * 80
    Layout.minimumHeight: implicitHeight
    Layout.maximumHeight: Kirigami.Units.gridUnit * 40
    Layout.preferredWidth: Math.max(implicitWidth, width)
    Layout.preferredHeight: Math.max(implicitHeight, height)

    property bool blockingHoverFocus: false
    property Item allAppsPageItem: null

    // Latest tab requested while a page transition is still animating. Applied
    // once the StackView stops being busy, so we never call replace() mid-
    // transition (that destroys items still referenced by the running animation,
    // causing a use-after-free crash inside libQt6Quick / plasmashell).
    property int pendingTabIndex: -1
    // Set when the user typed a query while a transition was still running.
    property bool pendingSearch: false

    // Tab to show when the menu opens: the last used one (persisted) or Home.
    readonly property int initialTab: Plasmoid.configuration.rememberLastPage
        ? Math.max(0, Math.min(3, Plasmoid.configuration.lastTab)) : 0
    readonly property var tabObjectNames: ["homePage", "allAppsPage", "placesPage", "infoPage"]
    function componentForTab(i) {
        return [homePageComponent, allAppsPageComponent, placesPageComponent, infoPageComponent][i] ?? homePageComponent
    }

    readonly property real preferredSideBarWidth: {
        if (allAppsPageItem && allAppsPageItem.sideBarItem) {
            return allAppsPageItem.sideBarItem.implicitWidth
        }
        return Singletons.MenuSingleton.gridCellSize * 2
    }

    // ── HEADER (always on top) ──
    header: Header {
        id: header
        Binding {
            target: kickoff
            property: "header"
            value: header
            restoreMode: Binding.RestoreBinding
        }
    }

    // ── CONTENT: Main area + Right Navigation Sidebar ──
    contentItem: RowLayout {
        id: mainRow
        spacing: 0

        // ─── CENTRAL CONTENT STACK ───
        VerticalStackView {
            id: contentItemStackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            focus: true
            movementTransitionsEnabled: true
            initialItem: root.componentForTab(root.initialTab)

            // When a deferred tab switch is pending, apply it as soon as the
            // running transition finishes (see root.pendingTabIndex).
            onBusyChanged: {
                if (busy)
                    return
                // Re-evaluate the current search state first: if the user is
                // typing, search wins over a pending tab switch.
                if (root.pendingSearch || (root.header && root.header.searchText.length > 0
                        && (!currentItem || currentItem.objectName !== "searchView"))) {
                    root.pendingSearch = false
                    if (root.header && root.header.searchText.length > 0) {
                        contentItemStackView.reverseTransitions = false
                        contentItemStackView.replace(searchViewComponent)
                        return
                    }
                }
                if (root.pendingTabIndex >= 0) {
                    const t = root.pendingTabIndex
                    root.pendingTabIndex = -1
                    root.switchToTab(t)
                }
            }

            Component {
                id: homePageComponent
                HomePage {
                    id: homePage
                    objectName: "homePage"
                    favoritesModel: kickoff.rootModel.favoritesModel
                    recentModel: kickoff.recentUsageModel
                    frequentModel: kickoff.frequentUsageModel
                    recentDocsModel: kickoff.recentDocsModel
                    recentFoldersModel: kickoff.recentFoldersModel
                }
            }

            Component {
                id: allAppsPageComponent
                AllAppsPage {
                    id: allAppsPage
                    objectName: "allAppsPage"
                    Component.onCompleted: root.allAppsPageItem = allAppsPage
                    Component.onDestruction: {
                        if (root.allAppsPageItem === allAppsPage)
                            root.allAppsPageItem = null
                    }
                }
            }

            Component {
                id: placesPageComponent
                PlacesPage {
                    id: placesPage
                }
            }

            Component {
                id: infoPageComponent
                InfoPage {
                    id: infoPage
                    objectName: "infoPage"
                }
            }

            Component {
                id: searchViewComponent
                SearchResultsPage {
                    id: searchPage
                    objectName: "searchView"
                }
            }

            Keys.priority: Keys.AfterItem
            Keys.forwardTo: kickoff.searchField

            // ── Search text triggers page switch ──
            Connections {
                target: root.header
                function onSearchTextChanged() {
                    if (root.header.searchText.length === 0 && contentItemStackView.currentItem && contentItemStackView.currentItem.objectName === "searchView") {
                        root.blockingHoverFocus = false
                        contentItemStackView.reverseTransitions = true
                        switchToTab(navBar.currentIndex)
                    } else if (root.header.searchText.length > 0) {
                        if (!contentItemStackView.currentItem || contentItemStackView.currentItem.objectName !== "searchView") {
                            // Defer if a transition is still running to avoid
                            // replacing an item mid-animation (use-after-free).
                            if (contentItemStackView.busy) {
                                root.pendingSearch = true
                                return
                            }
                            contentItemStackView.reverseTransitions = false
                            contentItemStackView.replace(searchViewComponent)
                        } else {
                            root.blockingHoverFocus = true
                        }
                    }
                }
            }
        }

        // ─── VERTICAL SEPARATOR ───
        Kirigami.Separator {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
        }

        // ─── RIGHT NAVIGATION SIDEBAR ───
        Rectangle {
            id: navSideBar
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
            color: Qt.rgba(
                Kirigami.Theme.backgroundColor.r,
                Kirigami.Theme.backgroundColor.g,
                Kirigami.Theme.backgroundColor.b,
                0.3
            )

            Accessible.role: Accessible.ToolBar
            Accessible.name: i18n("Main navigation")

            ColumnLayout {
                id: navBar
                anchors.fill: parent
                anchors.topMargin: Kirigami.Units.smallSpacing
                anchors.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                property int currentIndex: root.initialTab

                Accessible.role: Accessible.PageTabList
                Accessible.name: i18n("Main navigation tabs")

                // ── Home ──
                PC3.AbstractButton {
                    id: homeTab
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    checkable: true
                    checked: navBar.currentIndex === 0
                    hoverEnabled: true
                    onClicked: root.activateTab(0)

                    Accessible.name: i18n("Home")
                    Accessible.role: Accessible.PageTab
                    Accessible.description: i18n("Show favorites and recent apps")

                    contentItem: ColumnLayout {
                        spacing: 2
                        Kirigami.Icon {
                            source: "go-home-symbolic"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            Layout.alignment: Qt.AlignHCenter
                            selected: homeTab.checked
                        }
                        PC3.Label {
                            text: i18n("Home")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            color: homeTab.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                    }
                    background: Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: Kirigami.Units.smallSpacing
                        color: homeTab.checked
                            ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15)
                            : homeTab.hovered
                                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                                : "transparent"
                    }
                }

                // ── Apps ──
                PC3.AbstractButton {
                    id: appsTab
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    checkable: true
                    checked: navBar.currentIndex === 1
                    hoverEnabled: true
                    onClicked: root.activateTab(1)

                    Accessible.name: i18n("Apps")
                    Accessible.role: Accessible.PageTab
                    Accessible.description: i18n("Browse all installed applications")

                    contentItem: ColumnLayout {
                        spacing: 2
                        Kirigami.Icon {
                            source: "view-app-grid-symbolic"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            Layout.alignment: Qt.AlignHCenter
                            selected: appsTab.checked
                        }
                        PC3.Label {
                            text: i18n("Apps")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            color: appsTab.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                    }
                    background: Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: Kirigami.Units.smallSpacing
                        color: appsTab.checked
                            ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15)
                            : appsTab.hovered
                                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                                : "transparent"
                    }
                }

                // ── Places ──
                PC3.AbstractButton {
                    id: placesTab
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    checkable: true
                    checked: navBar.currentIndex === 2
                    hoverEnabled: true
                    onClicked: root.activateTab(2)

                    Accessible.name: i18n("Places")
                    Accessible.role: Accessible.PageTab
                    Accessible.description: i18n("Computer, history, and frequently used")

                    contentItem: ColumnLayout {
                        spacing: 2
                        Kirigami.Icon {
                            source: "folder-symbolic"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            Layout.alignment: Qt.AlignHCenter
                            selected: placesTab.checked
                        }
                        PC3.Label {
                            text: i18n("Places")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            color: placesTab.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                    }
                    background: Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: Kirigami.Units.smallSpacing
                        color: placesTab.checked
                            ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15)
                            : placesTab.hovered
                                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                                : "transparent"
                    }
                }

                // ── Info ──
                PC3.AbstractButton {
                    id: infoTab
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    checkable: true
                    checked: navBar.currentIndex === 3
                    hoverEnabled: true
                    onClicked: root.activateTab(3)

                    Accessible.name: i18n("Info")
                    Accessible.role: Accessible.PageTab
                    Accessible.description: i18n("System information and widgets")

                    contentItem: ColumnLayout {
                        spacing: 2
                        Kirigami.Icon {
                            source: "help-about-symbolic"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            Layout.alignment: Qt.AlignHCenter
                            selected: infoTab.checked
                        }
                        PC3.Label {
                            text: i18n("Info")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            color: infoTab.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                    }
                    background: Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: Kirigami.Units.smallSpacing
                        color: infoTab.checked
                            ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15)
                            : infoTab.hovered
                                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                                : "transparent"
                    }
                }

                Item { Layout.fillHeight: true } // spacer pushes tabs to top

                onCurrentIndexChanged: {
                    Plasmoid.configuration.lastTab = currentIndex
                    if (root.header && root.header.searchText.length === 0) {
                        switchToTab(currentIndex)
                    }
                }

                // When the menu opens, go to the remembered tab (or Home)
                Connections {
                    target: kickoff
                    function onExpandedChanged() {
                        if (kickoff.expanded) {
                            navBar.currentIndex = root.initialTab
                            // Same tab as before: still make sure the page is shown
                            // (e.g. after a search left the search view active).
                            root.switchToTab(navBar.currentIndex)
                        }
                    }
                }
            }

            // Bind footer/navBar to kickoff
            Binding {
                target: kickoff
                property: "footer"
                value: navBar
                restoreMode: Binding.RestoreBinding
            }
        }
    }

    /* parent: root is required, not decorative. EmptyPage is a T.Page, so an
       item declared in its body goes into contentData and the contentItem
       RowLayout takes ownership of its geometry — which made QML warn
       "anchors on an item that is managed by a layout. This is undefined
       behavior". Parenting it to the page itself keeps it a free-floating
       overlay whose anchors are its own. */
    Components.OnboardingOverlay {
        parent: root
        anchors.fill: parent
        z: 100
    }

    // Single entry point for "the user asked for this tab".
    //
    // Clicking a tab has to work while a search is running, including a click
    // on the tab that was already selected — the case that used to do nothing
    // at all, because `navBar.currentIndex = n` emits no change signal when the
    // value is unchanged, and because onCurrentIndexChanged refuses to switch
    // pages while the query is non-empty.
    //
    // Order matters here. The index is set *before* the query is cleared, so
    // that the searchTextChanged handler — which fires on clear and switches
    // back to navBar.currentIndex — lands on the tab the user just asked for
    // rather than the one they came from. The explicit switchToTab() below is
    // then a no-op in that path, and does the work when no search was running.
    function activateTab(tabIndex) {
        if (tabIndex < 0 || tabIndex > 3) {
            return
        }

        // Drop queued work first: a late pendingSearch would otherwise pull the
        // view straight back to the results page once the transition finishes.
        root.pendingSearch = false
        root.pendingTabIndex = -1

        navBar.currentIndex = tabIndex
        Plasmoid.configuration.lastTab = tabIndex

        if (root.header && root.header.searchText.length > 0) {
            root.blockingHoverFocus = false
            // Clearing the field also empties Kicker.RunnerModel's query, so
            // the runners stop working on a query nobody is looking at.
            root.header.searchField.text = ""
        }

        contentItemStackView.reverseTransitions = false
        switchToTab(tabIndex)

        // Keyboard focus belongs on the page the user opened, not on the
        // search field they just left. Falls back to the stack view while the
        // page is still being built.
        if (kickoff.contentArea) {
            kickoff.contentArea.forceActiveFocus(Qt.MouseFocusReason)
        } else {
            contentItemStackView.forceActiveFocus(Qt.MouseFocusReason)
        }
    }

    // ── Helper to switch content page ──
    function switchToTab(tabIndex) {
        if (tabIndex < 0 || tabIndex > 3)
            return
        const targetObjectName = root.tabObjectNames[tabIndex]
        const targetComponent = root.componentForTab(tabIndex)

        if (!contentItemStackView.currentItem)
            return
        if (contentItemStackView.currentItem.objectName === targetObjectName)
            return
        // Never replace() while a transition is running — defer it instead.
        if (contentItemStackView.busy) {
            root.pendingTabIndex = tabIndex
            return
        }
        contentItemStackView.reverseTransitions = false
        contentItemStackView.replace(targetComponent)
    }

    Component.onCompleted: {
        rootModel.refresh();
    }
}
