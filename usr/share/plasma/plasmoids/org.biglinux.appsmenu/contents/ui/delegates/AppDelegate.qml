/*
    SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2022 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQml 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.15 as T
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.ksvg 1.0 as KSvg
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "../code/tools.js" as Tools
import "../singletons" as Singletons

T.ItemDelegate {
    id: root

    // model properties (made optional for stability with different model types)
    property var model: null
    property int index: 0
    property url url: ""
    property var decoration: ""
    property string description: ""

    // "grid" or "list"
    property string displayMode: "list"
    property bool compact: false
    property bool isCategoryListItem: false
    property bool isSearchResult: false

    readonly property Flickable view: ListView.view ?? GridView.view
    readonly property bool hasActionList: model && (model.favoriteId !== null || ("hasActionList" in model && model.hasActionList === true))
    readonly property bool isSeparator: model && (model.isSeparator === true)
    readonly property bool isFavorite: model && model.favoriteId !== null && view && view.model && view.model.favoritesModel && view.model.favoritesModel.isFavorite(model.favoriteId)

    property int separatorHeight: Singletons.MenuSingleton.lineSvg.horLineHeight + (2 * Kirigami.Units.smallSpacing)
    property int itemHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, implicitContentHeight + topPadding + bottomPadding)

    readonly property bool dragEnabled: enabled && !isCategoryListItem
        && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable

    readonly property alias mouseArea: mouseArea
    readonly property bool isPressed: mouseArea.pressed
    readonly property bool iconAndLabelsShouldlookSelected: isPressed && !isCategoryListItem

    property bool labelTruncated: false
    property bool descriptionTruncated: false
    property bool descriptionVisible: displayMode === "list"
    property Item dragIconItem: displayMode === "grid" ? gridIcon : listIcon

    function openActionMenu(x = undefined, y = undefined) {
        if (!hasActionList) { return; }

        let actions = Array.from(model.actionList);
        const favoriteActions = Tools.createFavoriteActions(
            i18n,
            view.model.favoritesModel,
            model.favoriteId,
        );
        if (favoriteActions) {
            if (actions && actions.length > 0) {
                actions.push({ "type": "separator" }, ...favoriteActions);
            } else {
                actions = favoriteActions;
            }
        }

        if (actions && actions.length > 0) {
            Singletons.ActionMenuSingleton.plasmoid = kickoff;
            Singletons.ActionMenuSingleton.menu.visualParent = root;
            Singletons.ActionMenuSingleton.actionList = actions;
            if (x !== undefined && y !== undefined) {
                Singletons.ActionMenuSingleton.menu.open(x, y);
            } else {
                Singletons.ActionMenuSingleton.menu.openRelative();
            }
        }
    }

    z: Drag.active ? 4 : 1

    // Press micro-feedback
    scale: isPressed ? 0.97 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: isSeparator ? separatorHeight : itemHeight

    spacing: Singletons.MenuSingleton.fontMetrics.descent

    // Guard model access: during model reset/reuse `model` can be null, and an
    // unguarded `model.disabled` throws (crash surface on the live delegate).
    enabled: !isSeparator && !(model && model.disabled === true)
    hoverEnabled: true

    onHoveredChanged: {
        if (hovered) {
            if (view && view.hasOwnProperty("currentIndex")) {
                view.currentIndex = index
            }
            forceActiveFocus()
        }
    }

    text: model ? (model.name ?? model.displayWrapped ?? model.display) : ""

    // Accessible — correct roles and descriptive names
    Accessible.role: Accessible.MenuItem
    Accessible.name: root.text
    Accessible.description: root.description !== root.text ? root.description : ""
    Accessible.onPressAction: {
        root.forceActiveFocus()
        action.trigger()
    }

    action: T.Action {
        onTriggered: {
            if (!root.activeFocus && !root.isSearchResult) {
                return;
            }
            view.currentIndex = index
            if (view.model.trigger && view.model.trigger(index, "", null)) {
                if (kickoff.hideOnWindowDeactivate) {
                    kickoff.expanded = false;
                }
            }
        }
    }

    Keys.onReturnPressed: event => root.action.trigger()
    Keys.onEnterPressed: event => root.action.trigger()

    Drag.active: mouseArea.drag.active
    Drag.dragType: Drag.Automatic
    Drag.mimeData: { "text/uri-list" : root.url }
    Drag.onDragFinished: Drag.imageSource = ""

    // Padding depends on display mode
    leftPadding: displayMode === "grid"
        ? Singletons.MenuSingleton.listItemMetrics.margins.left
        : Singletons.MenuSingleton.listItemMetrics.margins.left + (mirrored ? Singletons.MenuSingleton.fontMetrics.descent : 0)
    rightPadding: displayMode === "grid"
        ? Singletons.MenuSingleton.listItemMetrics.margins.right
        : Singletons.MenuSingleton.listItemMetrics.margins.right + (!mirrored ? Singletons.MenuSingleton.fontMetrics.descent : 0)
    topPadding: displayMode === "grid"
        ? Kirigami.Units.smallSpacing * 2
        : (compact ? Kirigami.Units.mediumSpacing : Kirigami.Units.smallSpacing)
    bottomPadding: topPadding

    icon.width: {
        if (displayMode === "grid") return Kirigami.Units.iconSizes.large;
        if (compact || isCategoryListItem) return Kirigami.Units.iconSizes.small;
        return Kirigami.Units.iconSizes.medium;
    }
    icon.height: icon.width

    MouseArea {
        id: mouseArea
        property bool dragEnabled: false
        parent: root
        anchors.fill: parent
        anchors.margins: 1
        LayoutMirroring.enabled: false
        anchors.leftMargin: root.view instanceof ListView ? -root.view.leftMargin : anchors.margins
        anchors.rightMargin: root.view instanceof ListView ? -root.view.rightMargin : anchors.margins
        hoverEnabled: root.view
            && !root.view.movedWithWheel
            && kickoff.fullRepresentationItem && !kickoff.fullRepresentationItem.contentItem.busy && !kickoff.fullRepresentationItem.blockingHoverFocus
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag {
            axis: Drag.XAndYAxis
            target: root.dragEnabled && mouseArea.dragEnabled ? dragItem : undefined
        }
        Item { id: dragItem }

        onEntered: {
            if (root.view.movedWithKeyboard) { return; }
            if (root.isSeparator) { return; }
            if (!root.activeFocus) {
                root.forceActiveFocus(Qt.MouseFocusReason)
            }
            root.view.currentIndex = index
        }
        onPressed: mouse => {
            view.currentIndex = index
            root.forceActiveFocus(Qt.MouseFocusReason)
            mouseArea.dragEnabled = mouse.source === Qt.MouseEventNotSynthesized
            if (mouse.button === Qt.RightButton) {
                root.openActionMenu(mouseX, mouseY)
            } else if (mouseArea.dragEnabled && mouse.button === Qt.LeftButton
                && root.dragEnabled && root.dragIconItem && root.Drag.imageSource.toString() === ""
            ) {
                root.dragIconItem.grabToImage(result => {
                    root.Drag.imageSource = result.url
                })
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.action.trigger()
            }
        }
        onPressAndHold: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.openActionMenu(mouseX, mouseY)
            }
        }
    }

    PC3.ToolTip.text: {
        if (root.labelTruncated && root.descriptionTruncated) {
            return `${text} (${description})`
        } else if (root.descriptionTruncated || !root.descriptionVisible) {
            return description
        }
        return ""
    }
    PC3.ToolTip.visible: mouseArea.containsMouse && PC3.ToolTip.text.length > 0
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: null

    // Content item switches between grid and list layout
    contentItem: Loader {
        sourceComponent: root.displayMode === "grid" ? gridContent : listContent
    }

    Component {
        id: gridContent
        ColumnLayout {
            spacing: root.spacing

            Kirigami.Icon {
                id: gridIconInner
                implicitWidth: root.icon.width
                implicitHeight: root.icon.height
                Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                animated: false
                selected: root.iconAndLabelsShouldlookSelected
                source: root.decoration || root.icon.name || root.icon.source
                Component.onCompleted: root.dragIconItem = gridIconInner

                // Hover micro-feedback
                scale: mouseArea.containsMouse ? 1.04 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                // ★ Gold star favorite badge
                Kirigami.Icon {
                    anchors { top: parent.top; right: parent.right; topMargin: -2; rightMargin: -2 }
                    visible: root.isFavorite && !root.isCategoryListItem
                    width: Kirigami.Units.iconSizes.small * 0.7
                    height: width
                    source: "starred-symbolic"
                    color: "#FFD700"
                    Accessible.ignored: true
                }
            }

            PC3.Label {
                id: gridLabel
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                Layout.fillWidth: true
                Layout.preferredHeight: lineCount === 1 ? implicitHeight * 2 : implicitHeight
                text: root.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                maximumLineCount: 2
                wrapMode: Text.Wrap
                color: root.iconAndLabelsShouldlookSelected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                Component.onCompleted: root.labelTruncated = Qt.binding(() => gridLabel.truncated)
            }
        }
    }

    Component {
        id: listContent
        RowLayout {
            spacing: Singletons.MenuSingleton.listItemMetrics.margins.left * 2

            Kirigami.Icon {
                id: listIconInner
                implicitWidth: root.icon.width
                implicitHeight: root.icon.height
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                animated: false
                selected: root.iconAndLabelsShouldlookSelected
                source: {
                    if (Plasmoid.configuration.useSymbolicIcons) {
                        return root.decoration || root.icon.name || root.icon.source
                    }
                    const src = root.decoration || root.icon.name
                    if (src && src.length > 0) {
                        if (src.endsWith("-symbolic")) { return src.slice(0, -9); }
                        if (root.isCategoryListItem && src.search(/:|\/|\\|-symbolic$/g) === -1) {
                            return src + "-symbolic";
                        }
                    }
                    return src || root.icon.source
                }
                Component.onCompleted: root.dragIconItem = listIconInner
            }

            GridLayout {
                id: gridLayout
                readonly property color textColor: root.iconAndLabelsShouldlookSelected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                Layout.fillWidth: true
                rows: root.compact ? 1 : 2
                columns: root.compact ? 2 : 1
                rowSpacing: 0
                columnSpacing: Kirigami.Units.largeSpacing

                PC3.Label {
                    id: nameLabel
                    Layout.fillWidth: !descriptionLabel.visible
                    Layout.maximumWidth: root.width - root.leftPadding - root.rightPadding - listIconInner.width - parent.parent.spacing
                    Layout.preferredHeight: {
                        if (root.isCategoryListItem) {
                            return root.compact ? implicitHeight : Math.round(implicitHeight * 1.5);
                        }
                        if (!root.compact && !descriptionLabel.visible) {
                            return implicitHeight + descriptionLabel.implicitHeight;
                        }
                        return implicitHeight;
                    }
                    text: root.text
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    maximumLineCount: 1
                    color: gridLayout.textColor
                    Component.onCompleted: root.labelTruncated = Qt.binding(() => nameLabel.truncated)
                }

                PC3.Label {
                    id: descriptionLabel
                    Layout.fillWidth: true
                    visible: text.length > 0 && text !== root.text && !root.isCategoryListItem
                    enabled: false
                    text: root.description
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: root.compact ? Text.AlignRight : Text.AlignLeft
                    maximumLineCount: 1
                    color: gridLayout.textColor
                    Component.onCompleted: {
                        root.descriptionTruncated = Qt.binding(() => descriptionLabel.truncated)
                        root.descriptionVisible = Qt.binding(() => descriptionLabel.visible)
                    }
                }
            }
        }
    }

    // Alias properties for measurement delegates in MenuSingleton
    property alias gridIcon: root.dragIconItem
    property alias listIcon: root.dragIconItem
}
