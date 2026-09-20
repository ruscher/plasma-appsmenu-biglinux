/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    HomePage — Dashboard: Favorites, Recent Apps, Recent Files, Recent Folders, Frequent
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.15 as T
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "components" as Components
import "singletons" as Singletons

EmptyPage {
    id: root

    property var favoritesModel: null
    property var recentModel: null
    property var frequentModel: null
    property var recentDocsModel: null
    property var recentFoldersModel: null

    Accessible.name: i18n("Home page")
    Accessible.role: Accessible.Pane

    T.StackView.onActivated: {
        kickoff.sideBar = null
        kickoff.contentArea = root
    }

    contentItem: Item {
        Flickable {
            id: homeFlickable
            anchors.fill: parent
            contentWidth: width
            contentHeight: homeColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            PC3.ScrollBar.vertical: PC3.ScrollBar {}

            ColumnLayout {
                id: homeColumn
                width: homeFlickable.width
                spacing: Kirigami.Units.mediumSpacing

                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

                // ══════════════════════════════════
                // ★ FAVORITES GRID ★
                // ══════════════════════════════════
                HomeSection {
                    sectionTitle: i18n("Favorites")
                    sectionIcon: "starred-symbolic"
                    sectionCount: root.favoritesModel ? root.favoritesModel.count : 0
                    visible: root.favoritesModel !== null && root.favoritesModel.count > 0

                    Flow {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: root.favoritesModel
                            delegate: PC3.AbstractButton {
                                id: favBtn
                                width: Singletons.MenuSingleton.gridCellSize
                                height: width
                                hoverEnabled: true

                                Accessible.role: Accessible.MenuItem
                                Accessible.name: model.display || ""
                                Accessible.description: model.description || ""

                                contentItem: ColumnLayout {
                                    spacing: 2
                                    Item {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                                        Layout.alignment: Qt.AlignHCenter

                                        Kirigami.Icon {
                                            anchors.fill: parent
                                            source: model.decoration || "application-x-executable"
                                            scale: favBtn.hovered ? 1.04 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        }

                                        // ★ Star badge
                                        Kirigami.Icon {
                                            source: "starred-symbolic"
                                            width: Kirigami.Units.iconSizes.small * 0.7
                                            height: width
                                            anchors { top: parent.top; right: parent.right; topMargin: -2; rightMargin: -2 }
                                            color: "#FFD700"
                                            Accessible.ignored: true
                                        }
                                    }
                                    PC3.Label {
                                        text: model.display || ""
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.Wrap
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        Layout.fillWidth: true
                                    }
                                }

                                background: Rectangle {
                                    radius: Kirigami.Units.smallSpacing
                                    color: favBtn.hovered || favBtn.activeFocus
                                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15)
                                        : "transparent"
                                }

                                scale: pressed ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                onClicked: {
                                    if (root.favoritesModel.trigger) {
                                        root.favoritesModel.trigger(model.index, "", null)
                                        if (kickoff.hideOnWindowDeactivate) kickoff.expanded = false
                                    }
                                }

                                PC3.ToolTip.text: model.description || ""
                                PC3.ToolTip.visible: hovered && PC3.ToolTip.text.length > 0
                                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }
                        }
                    }
                }

                // ══════════════════════════════════
                // RECENT APPS
                // ══════════════════════════════════
                HomeSection {
                    id: recentAppsSection
                    sectionTitle: i18n("Recent Apps")
                    sectionIcon: "history"
                    sectionCount: root.recentModel ? root.recentModel.count : 0
                    collapsible: true
                    visible: Plasmoid.configuration.showRecentSection && root.recentModel !== null && root.recentModel.count > 0

                    hoverEnabled: true
                    onHoveredChanged: if (hovered) expanded = true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: recentAppsSection.expanded

                        Repeater {
                            model: root.recentModel
                            delegate: RecentItemDelegate {
                                // Double check: hidden if it looks like a folder
                                visible: model.index < Plasmoid.configuration.recentAppsMax && 
                                         !(String(model.url).endsWith("/") || String(model.decoration).indexOf("folder") !== -1)
                                itemModel: root.recentModel
                                itemIcon: model.decoration || "application-x-executable"
                                itemName: model.display || ""
                                itemDescription: model.description || ""
                                itemIndex: model.index
                            }
                        }
                    }
                }

                // ══════════════════════════════════
                // RECENT FILES
                // ══════════════════════════════════
                HomeSection {
                    id: recentFilesSection
                    sectionTitle: i18n("Recent Files")
                    sectionIcon: "document-open-recent"
                    sectionCount: root.recentDocsModel ? root.recentDocsModel.count : 0
                    collapsible: true
                    visible: Plasmoid.configuration.showRecentFiles && root.recentDocsModel !== null && root.recentDocsModel.count > 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: recentFilesSection.expanded

                        Repeater {
                            model: root.recentDocsModel
                            delegate: RecentItemDelegate {
                                // Double check: hidden if it looks like an app (.desktop) or a folder (ends with /)
                                visible: index < Plasmoid.configuration.recentFilesMax && 
                                         !String(model.url).includes(".desktop") && 
                                         !String(model.url).endsWith("/") &&
                                         !(String(model.decoration).indexOf("folder") !== -1)
                                itemModel: root.recentDocsModel
                                itemIcon: model.decoration || "text-x-generic"
                                itemName: model.display || ""
                                itemDescription: model.description || model.url || ""
                                itemIndex: model.index
                            }
                        }
                    }
                }

                // ══════════════════════════════════
                // RECENT FOLDERS
                // ══════════════════════════════════
                HomeSection {
                    id: recentFoldersSection
                    sectionTitle: i18n("Recent Folders")
                    sectionIcon: "folder-open-recent"
                    sectionCount: root.recentFoldersModel ? root.recentFoldersModel.count : 0
                    collapsible: true
                    visible: Plasmoid.configuration.showRecentFolders && root.recentFoldersModel !== null && root.recentFoldersModel.count > 0

                    hoverEnabled: true
                    onHoveredChanged: if (hovered) expanded = true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: recentFoldersSection.expanded

                        Repeater {
                            model: root.recentFoldersModel
                            delegate: RecentItemDelegate {
                                // Double check: only if it ends with / or has folder in name/icon
                                visible: index < Plasmoid.configuration.recentFoldersMax && 
                                         (String(model.url).endsWith("/") || String(model.decoration).indexOf("folder") !== -1)
                                itemModel: root.recentFoldersModel
                                itemIcon: model.decoration || "folder"
                                itemName: model.display || ""
                                itemDescription: model.description || model.url || ""
                                itemIndex: model.index
                            }
                        }
                    }
                }

                // ══════════════════════════════════
                // FREQUENT APPS
                // ══════════════════════════════════
                HomeSection {
                    id: frequentSection
                    sectionTitle: i18n("Frequently Used")
                    sectionIcon: "clock"
                    sectionCount: root.frequentModel ? root.frequentModel.count : 0
                    collapsible: true
                    visible: Plasmoid.configuration.showFrequentSection && root.frequentModel !== null && root.frequentModel.count > 0

                    hoverEnabled: true
                    onHoveredChanged: if (hovered) expanded = true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: frequentSection.expanded

                        Repeater {
                            model: root.frequentModel
                            delegate: RecentItemDelegate {
                                visible: model.index < 5
                                itemModel: root.frequentModel
                                itemIcon: model.decoration || "application-x-executable"
                                itemName: model.display || ""
                                itemDescription: model.description || ""
                                itemIndex: model.index
                            }
                        }
                    }
                }

                // ── Empty favorites hint ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: emptyHint.implicitHeight + Kirigami.Units.gridUnit * 2
                    visible: root.favoritesModel !== null && root.favoritesModel.count === 0

                    PC3.Label {
                        id: emptyHint
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 4
                        text: i18n("No favorites yet. Right-click an app to add it here.")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
            }
        }
    }

    // ══════════════════════════════════════════════════════
    // INLINE COMPONENTS
    // ══════════════════════════════════════════════════════

    // ── Section card with header, count badge, collapse button ──
    component HomeSection : Item {
        id: sectionRoot
        property string sectionTitle: ""
        property string sectionIcon: ""
        property int sectionCount: 0
        property bool collapsible: false
        property bool expanded: true
        property bool hoverEnabled: false
        readonly property bool hovered: hoverEnabled && mouseArea.containsMouse

        default property alias contentChildren: sectionContentCol.data

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: sectionRoot.hoverEnabled
            onEntered: sectionRoot.hoveredChanged(true)
            onExited: sectionRoot.hoveredChanged(false)
            onClicked: mouse.accepted = false
        }

        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.mediumSpacing
        Layout.rightMargin: Kirigami.Units.mediumSpacing
        Layout.preferredHeight: sectionInnerCol.implicitHeight + Kirigami.Units.largeSpacing

        // Card background
        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.mediumSpacing
            color: Qt.rgba(
                Kirigami.Theme.backgroundColor.r,
                Kirigami.Theme.backgroundColor.g,
                Kirigami.Theme.backgroundColor.b,
                0.35
            )
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
        }

        ColumnLayout {
            id: sectionInnerCol
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: Kirigami.Units.mediumSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: sectionRoot.sectionIcon
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    visible: sectionRoot.sectionIcon.length > 0
                }

                PC3.Label {
                    text: sectionRoot.sectionTitle
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Accessible.role: Accessible.Heading
                    Accessible.name: sectionRoot.sectionTitle
                }

                // Count badge
                Rectangle {
                    visible: sectionRoot.sectionCount > 0
                    Layout.preferredWidth: countLabel.implicitWidth + Kirigami.Units.mediumSpacing * 2
                    Layout.preferredHeight: countLabel.implicitHeight + 4
                    radius: height / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)

                    PC3.Label {
                        id: countLabel
                        anchors.centerIn: parent
                        text: sectionRoot.sectionCount
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                // Collapse/expand
                PC3.ToolButton {
                    visible: sectionRoot.collapsible
                    icon.name: sectionRoot.expanded ? "arrow-up" : "arrow-down"
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    display: PC3.AbstractButton.IconOnly

                    Accessible.name: sectionRoot.expanded ? i18n("Collapse %1", sectionRoot.sectionTitle) : i18n("Expand %1", sectionRoot.sectionTitle)
                    Accessible.role: Accessible.Button

                    onClicked: sectionRoot.expanded = !sectionRoot.expanded
                }
            }

            // Content area
            ColumnLayout {
                id: sectionContentCol
                Layout.fillWidth: true
                spacing: 0
            }
        }
    }

    // ── Reusable list item delegate for recent items ──
    component RecentItemDelegate : PC3.AbstractButton {
        id: recentBtn
        property var itemModel: null
        property string itemIcon: ""
        property string itemName: ""
        property string itemDescription: ""
        property int itemIndex: 0

        Layout.fillWidth: true
        Layout.preferredHeight: Singletons.MenuSingleton.compactListDelegateHeight
        hoverEnabled: true

        onHoveredChanged: {
            if (hovered) forceActiveFocus()
        }

        Accessible.role: Accessible.MenuItem
        Accessible.name: itemName
        Accessible.description: itemDescription

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: recentBtn.itemIcon
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PC3.Label {
                text: recentBtn.itemName
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            PC3.Label {
                text: recentBtn.itemDescription
                visible: text.length > 0 && text !== recentBtn.itemName
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideMiddle
                maximumLineCount: 1
                Layout.maximumWidth: parent.width * 0.45
            }
        }

        background: Rectangle {
            radius: Kirigami.Units.smallSpacing
            color: recentBtn.hovered || recentBtn.activeFocus
                ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.12)
                : "transparent"
        }

        scale: pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        onClicked: {
            if (recentBtn.itemModel && recentBtn.itemModel.trigger) {
                recentBtn.itemModel.trigger(recentBtn.itemIndex, "", null)
                if (kickoff.hideOnWindowDeactivate) kickoff.expanded = false
            }
        }
    }
}
