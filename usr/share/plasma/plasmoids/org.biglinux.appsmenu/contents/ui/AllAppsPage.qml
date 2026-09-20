/*
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    AllAppsPage — Categories sidebar + application content area
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.15 as T
import QtQml 2.15
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "singletons" as Singletons
import "delegates" as Delegates
import "components" as Components

EmptyPage {
    id: root

    Accessible.name: i18n("All applications")
    Accessible.role: Accessible.Pane

    readonly property Item sideBarItem: sideBar
    readonly property Item contentAreaItem: contentStack

    // First sidebar row that is actually shown (skips the hidden Favorites row,
    // All Applications when disabled, and separator/top-level rows). Falls
    // back to 0 (Favorites) when the model has no categories.
    function isCategoryRowShown(row) {
        if (row <= 0) return false
        if (row === 1 && !Plasmoid.configuration.showAllApplications) return false
        return kickoff.rootModel.modelForRow(row) !== null
    }
    function firstVisibleCategoryRow() {
        const rm = kickoff.rootModel
        for (let i = 1; i < rm.count; i++) {
            if (isCategoryRowShown(i))
                return i
        }
        return 0
    }
    // Remembered category (if still valid) or the first visible one.
    function initialCategoryRow() {
        const last = Plasmoid.configuration.lastCategoryRow
        if (Plasmoid.configuration.rememberLastPage && isCategoryRowShown(last))
            return last
        return firstVisibleCategoryRow()
    }
    function componentForRow(row) {
        if (row === 0) return contentStack.preferredFavoritesViewComponent
        if (row === 1) return contentStack.preferredAllAppsViewComponent
        return contentStack.preferredAppsViewComponent
    }
    function selectInitialCategory() {
        sideBar.currentIndex = initialCategoryRow()
    }

    T.StackView.onActivated: {
        kickoff.sideBar = sideBar
        kickoff.contentArea = contentStack.currentItem
    }

    Component.onCompleted: selectInitialCategory()

    // AccessibleListView resets its view to row 0 (hidden Favorites) whenever
    // the menu opens; re-select the remembered/first real category right after.
    Connections {
        target: kickoff
        function onExpandedChanged() {
            if (kickoff.expanded)
                Qt.callLater(root.selectInitialCategory)
        }
    }

    contentItem: RowLayout {
        spacing: 0

        LayoutMirroring.enabled: kickoff.sideBarOnRight
        LayoutMirroring.childrenInherit: true

        // Category Sidebar
        Components.AccessibleListView {
            id: sideBar
            Layout.fillHeight: true
            Layout.preferredWidth: Singletons.MenuSingleton.gridCellSize * 2 + kickoff.backgroundMetrics.leftPadding
            Layout.maximumWidth: Layout.preferredWidth

            focus: true
            model: kickoff.rootModel

            section.property: ""

            Accessible.name: i18n("Application categories")
            Accessible.role: Accessible.List

            // Same look as the Places sidebar: AppDelegate in category mode, no
            // own background (the view's rounded Highlight is the selection).
            delegate: Delegates.AppDelegate {
                id: categoryDelegate
                // Sub-model of this row; null for separators/top-level items.
                readonly property var subModel: kickoff.rootModel.modelForRow(index)
                readonly property int appCount: subModel ? subModel.count : 0
                readonly property bool shown: root.isCategoryRowShown(index)

                width: sideBar.view.availableWidth
                height: shown ? implicitHeight : 0
                visible: shown
                enabled: shown
                hoverEnabled: shown

                isCategoryListItem: true
                displayMode: "list"
                text: model.display ?? ""
                decoration: (model.display === "WebApps" || model.display === "Web Apps")
                    ? "/usr/share/icons/hicolor/scalable/apps/big-webapps-symbolic.svg"
                    : (model.decoration ?? "")
                // App count as secondary info (never the only indicator)
                trailingText: appCount > 0 ? String(appCount) : ""

                Accessible.name: appCount > 0 ? i18nc("category name, app count", "%1 (%2)", text, appCount) : text
                Accessible.description: i18n("Application category")
            }

            emptyText: ""
            Keys.onRightPressed: event => {
                if (Qt.application.layoutDirection === Qt.LeftToRight && contentStack.currentItem) {
                    contentStack.currentItem.forceActiveFocus(Qt.TabFocusReason)
                } else {
                    event.accepted = false
                }
            }
            Keys.onLeftPressed: event => {
                if (Qt.application.layoutDirection === Qt.RightToLeft && contentStack.currentItem) {
                    contentStack.currentItem.forceActiveFocus(Qt.TabFocusReason)
                } else {
                    event.accepted = false
                }
            }

            Keys.onDownPressed: {
                let nextIndex = currentIndex + 1;
                while (nextIndex < count) {
                    const item = itemAtIndex(nextIndex);
                    if (item && item.visible) break;
                    nextIndex++;
                }
                if (nextIndex < count) {
                    currentIndex = nextIndex;
                }
            }

            Keys.onUpPressed: {
                let prevIndex = currentIndex - 1;
                while (prevIndex >= 0) {
                    const item = itemAtIndex(prevIndex);
                    if (item && item.visible) break;
                    prevIndex--;
                }
                if (prevIndex >= 0) {
                    currentIndex = prevIndex;
                }
            }
        }

        // Content: stack of app views
        VerticalStackView {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true

            readonly property string preferredFavoritesViewObjectName: Plasmoid.configuration.favoritesDisplay === 0 ? "favoritesGridView" : "favoritesListView"
            readonly property Component preferredFavoritesViewComponent: Plasmoid.configuration.favoritesDisplay === 0 ? favoritesGridViewComponent : favoritesListViewComponent
            readonly property string preferredAllAppsViewObjectName: Plasmoid.configuration.applicationsDisplay === 0 ? "listOfGridsView" : "applicationsListView"
            readonly property Component preferredAllAppsViewComponent: Plasmoid.configuration.applicationsDisplay === 0 ? listOfGridsViewComponent : applicationsListViewComponent
            readonly property string preferredAppsViewObjectName: Plasmoid.configuration.applicationsDisplay === 0 ? "applicationsGridView" : "applicationsListView"
            readonly property Component preferredAppsViewComponent: Plasmoid.configuration.applicationsDisplay === 0 ? applicationsGridViewComponent : applicationsListViewComponent

            // Start directly on the first visible category so the initial view
            // matches the highlighted sidebar row (no favorites→category flash).
            property int appsModelRow: Math.max(root.initialCategoryRow(), 0)
            readonly property Kicker.AppsModel appsModel: kickoff.rootModel.modelForRow(appsModelRow)

            initialItem: root.componentForRow(root.initialCategoryRow())

            // Safe view switching: skip redundant switches and never call
            // replace() while a transition is running (defer it). Same crash
            // class as the outer nav — category hover changes sideBar.currentIndex
            // and could fire replace() mid-transition (use-after-free).
            property Component pendingViewComponent: null
            function switchView(component, objectName) {
                if (!component)
                    return
                if (currentItem && currentItem.objectName === objectName)
                    return
                if (busy) {
                    pendingViewComponent = component
                    return
                }
                replace(component)
            }
            onBusyChanged: {
                if (!busy && pendingViewComponent) {
                    const c = pendingViewComponent
                    pendingViewComponent = null
                    replace(c)
                }
            }

            // Favorites as list
            Component {
                id: favoritesListViewComponent
                Components.AccessibleListView {
                    id: favoritesListView
                    objectName: "favoritesListView"
                    mainContentView: true
                    focus: true
                    model: kickoff.rootModel.favoritesModel

                    Components.DragDropArea {
                        z: -1
                        parent: favoritesListView
                        anchors.fill: parent
                        targetView: favoritesListView.view
                        scrollUpMargin: favoritesListView.header.height * 2
                        scrollDownMargin: favoritesListView.footer.height * 2
                    }
                }
            }

            // Favorites as grid
            Component {
                id: favoritesGridViewComponent
                Components.AccessibleGridView {
                    id: favoritesGridView
                    objectName: "favoritesGridView"
                    focus: true
                    model: kickoff.rootModel.favoritesModel

                    Components.DragDropArea {
                        z: -1
                        parent: favoritesGridView
                        anchors.fill: parent
                        targetView: favoritesGridView.view
                        scrollUpMargin: favoritesGridView.header.height * 2
                        scrollDownMargin: favoritesGridView.footer.height * 2
                    }
                }
            }

            // All apps flat list
            Component {
                id: applicationsListViewComponent
                Components.AccessibleListView {
                    id: applicationsListView
                    objectName: "applicationsListView"
                    mainContentView: true
                    model: contentStack.appsModel
                    section.property: model && model.description === "KICKER_ALL_MODEL" ? "group" : ""
                    section.criteria: ViewSection.FirstCharacter
                    hasSectionView: contentStack.appsModelRow === 1

                    onShowSectionViewRequested: sectionName => {
                        contentStack.push(applicationsSectionViewComponent, {
                            "currentSection": sectionName,
                            "parentView": applicationsListView
                        });
                    }
                }
            }

            // Section jump view
            Component {
                id: applicationsSectionViewComponent
                SectionView {
                    id: sectionView
                    model: contentStack.appsModel.sections
                    onHideSectionViewRequested: index => {
                        contentStack.pop();
                        // Guard: the revealed item may be null mid-transition or
                        // may not expose a `view` (avoid deref crash).
                        const it = contentStack.currentItem;
                        if (it && it.view) {
                            it.view.positionViewAtIndex(index, ListView.Beginning);
                            it.currentIndex = index;
                        }
                    }
                }
            }

            // Apps as grid
            Component {
                id: applicationsGridViewComponent
                Components.AccessibleGridView {
                    id: applicationsGridView
                    objectName: "applicationsGridView"
                    model: contentStack.appsModel
                }
            }

            // All apps as grid-of-grids
            Component {
                id: listOfGridsViewComponent
                ListOfGridsView {
                    id: listOfGridsView
                    objectName: "listOfGridsView"
                    mainContentView: true
                    gridModel: contentStack.appsModel

                    onShowSectionViewRequested: sectionName => {
                        contentStack.push(applicationsSectionViewComponent, {
                            currentSection: sectionName,
                            parentView: listOfGridsView
                        });
                    }
                }
            }

            onPreferredFavoritesViewComponentChanged: {
                if (sideBar.currentIndex === 0) {
                    contentStack.switchView(contentStack.preferredFavoritesViewComponent, contentStack.preferredFavoritesViewObjectName)
                }
            }
            onPreferredAllAppsViewComponentChanged: {
                if (sideBar.currentIndex === 1) {
                    contentStack.switchView(contentStack.preferredAllAppsViewComponent, contentStack.preferredAllAppsViewObjectName)
                }
            }
            onPreferredAppsViewComponentChanged: {
                if (sideBar.currentIndex > 1) {
                    contentStack.switchView(contentStack.preferredAppsViewComponent, contentStack.preferredAppsViewObjectName)
                }
            }

            Connections {
                target: sideBar
                function onCurrentIndexChanged() {
                    if (sideBar.currentIndex > 0) {
                        contentStack.appsModelRow = sideBar.currentIndex
                        Plasmoid.configuration.lastCategoryRow = sideBar.currentIndex
                    }
                    if (sideBar.currentIndex === 0) {
                        contentStack.switchView(contentStack.preferredFavoritesViewComponent, contentStack.preferredFavoritesViewObjectName)
                    } else if (sideBar.currentIndex === 1) {
                        contentStack.switchView(contentStack.preferredAllAppsViewComponent, contentStack.preferredAllAppsViewObjectName)
                    } else if (sideBar.currentIndex > 1) {
                        contentStack.switchView(contentStack.preferredAppsViewComponent, contentStack.preferredAppsViewObjectName)
                    }
                }
            }

            Connections {
                target: kickoff
                function onExpandedChanged() {
                    if (kickoff.expanded && contentStack.currentItem) {
                        contentStack.currentItem.forceActiveFocus()
                    }
                }
            }
        }
    }

    Binding {
        target: kickoff
        property: "sideBar"
        value: sideBar
        when: root.T.StackView.status === T.StackView.Active && root.visible
        restoreMode: Binding.RestoreBinding
    }
    Binding {
        target: kickoff
        property: "contentArea"
        value: contentStack.currentItem
        when: root.T.StackView.status === T.StackView.Active && root.visible
        restoreMode: Binding.RestoreBinding
    }
}
