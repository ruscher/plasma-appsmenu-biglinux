/*
    SPDX-FileCopyrightText: 2020 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Kai Uwe Broulik <kde@broulik.de>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    PowerMenu — quick icon buttons for the configured system favorites
    (default: log out · reboot · shut down), followed by an "Options" kebab
    button holding the remaining session/power actions. In a narrow popup the
    quick buttons collapse and everything moves into the menu.

    All actions go through Kicker.SystemModel, i.e. Plasma's own session
    handling — never shell commands like `systemctl poweroff`.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.plasmoid 2.0

RowLayout {
    id: root
    readonly property alias buttonImplicitWidth: buttonRepeaterRow.implicitWidth
    // When true (narrow popup) the quick buttons are hidden; everything is in the menu.
    property bool shouldCollapseButtons: false
    spacing: Kirigami.Units.smallSpacing

    Kicker.SystemModel {
        id: systemModel
        favoritesModel: kickoff.rootModel.systemFavoritesModel
    }

    component FilteredModel : KItemModels.KSortFilterProxyModel {
        sourceModel: systemModel

        function systemFavoritesContainsRow(sourceRow, sourceParent) {
            const FavoriteIdRole = sourceModel.KItemModels.KRoleNames.role("favoriteId");
            const favoriteId = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), FavoriteIdRole);
            return String(Plasmoid.configuration.systemFavorites).split(",").includes(String(favoriteId));
        }

        function trigger(index) {
            const sourceIndex = mapToSource(this.index(index, 0));
            systemModel.trigger(sourceIndex.row, "", null);
        }

        Component.onCompleted: {
            Plasmoid.configuration.valueChanged.connect((key, value) => {
                if (key === "systemFavorites") {
                    invalidateFilter();
                }
            });
        }
    }

    // Quick icon buttons: the configured favorites
    FilteredModel {
        id: filteredButtonsModel
        filterRowCallback: (sourceRow, sourceParent) =>
            systemFavoritesContainsRow(sourceRow, sourceParent)
    }

    // Menu: the remaining actions (the favorites are already icon buttons);
    // when the buttons are collapsed, everything goes into the menu.
    FilteredModel {
        id: menuModel
        filterRowCallback: root.shouldCollapseButtons
            ? null
            : (sourceRow, sourceParent) => !systemFavoritesContainsRow(sourceRow, sourceParent)
    }

    // ── Quick icon buttons (logout / reboot / shut down by default) ──
    // These come first: Options is the overflow, so it belongs at the end of
    // the row, after the actions the user reaches most often.
    RowLayout {
        id: buttonRepeaterRow
        visible: !root.shouldCollapseButtons
        spacing: root.spacing

        Repeater {
            id: buttonRepeater
            model: filteredButtonsModel
            delegate: PC3.ToolButton {
                required property var model
                required property int index

                text: model.display
                icon.name: model.decoration
                icon.width: Kirigami.Units.iconSizes.smallMedium
                icon.height: Kirigami.Units.iconSizes.smallMedium
                display: Plasmoid.configuration.showActionButtonCaptions ? PC3.AbstractButton.TextBesideIcon : PC3.AbstractButton.IconOnly
                onClicked: filteredButtonsModel.trigger(index)

                Accessible.name: model.display
                Accessible.role: Accessible.Button

                PC3.ToolTip.text: text
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                PC3.ToolTip.visible: display === PC3.AbstractButton.IconOnly && hovered

                // Tab moves on to Options, which is the next item in the row.
                Keys.onTabPressed: event => {
                    event.accepted = false
                }
            }
        }
    }

    // ── "Options" menu button (kebab) ──
    // Last in the row, after the quick buttons. When the popup is too narrow
    // the quick buttons collapse into this menu, so it is then the only
    // control here and still reachable.
    PC3.ToolButton {
        id: leaveButton

        Accessible.role: Accessible.ButtonMenu
        Accessible.name: i18nc("@action:button open session and power options", "Options")
        Accessible.description: i18n("Opens a menu with session and power actions")

        // Kebab (⋮). view-more-symbolic ships with Breeze, Breeze Dark and the
        // BigLinux icon theme; view-more-horizontal-symbolic is the "…"
        // variant and is deliberately not used here.
        icon.name: "view-more-symbolic"
        icon.width: Kirigami.Units.iconSizes.smallMedium
        icon.height: Kirigami.Units.iconSizes.smallMedium
        // Icon only: the kebab is the affordance, and the row is tight once
        // the quick buttons sit next to it.
        display: PC3.AbstractButton.IconOnly
        text: i18nc("@action:button open session and power options", "Options")
        down: contextMenu.status === PlasmaExtras.Menu.Open || pressed

        PC3.ToolTip.text: text
        PC3.ToolTip.visible: hovered
        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

        Keys.onTabPressed: event => {
            kickoff.firstHeaderItem.forceActiveFocus(Qt.TabFocusReason)
        }
        onPressed: contextMenu.openRelative()
    }

    Instantiator {
        model: menuModel
        delegate: PlasmaExtras.MenuItem {
            required property var model
            required property int index
            text: model.display
            icon: model.decoration
            onClicked: menuModel.trigger(index)
        }
        onObjectAdded: (index, object) => contextMenu.addMenuItem(object)
        onObjectRemoved: (index, object) => contextMenu.removeMenuItem(object)
    }

    PlasmaExtras.Menu {
        id: contextMenu
        visualParent: leaveButton
        placement: {
            switch (Plasmoid.location) {
            case PlasmaCore.Types.LeftEdge:
            case PlasmaCore.Types.RightEdge:
            case PlasmaCore.Types.TopEdge:
                return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
            case PlasmaCore.Types.BottomEdge:
            default:
                return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
            }
        }
    }
}
