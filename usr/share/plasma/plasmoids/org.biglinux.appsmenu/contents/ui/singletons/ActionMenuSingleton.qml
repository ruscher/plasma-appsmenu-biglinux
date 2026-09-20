/*
    SPDX-FileCopyrightText: 2013 Aurélien Gâteau <agateau@kde.org>
    SPDX-FileCopyrightText: 2014-2015 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton

import QtQuick 2.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.extras 2.0 as PlasmaExtras
import "../code/tools.js" as Tools

Item {
    id: root

    property var actionList: null
    property PlasmoidItem plasmoid: null

    readonly property PlasmaExtras.Menu menu: PlasmaExtras.Menu {
        id: menu
        visualParent: null
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
    }

    visible: false

    Instantiator {
        active: root.actionList !== null
        model: root.actionList
        delegate: menuItemComponent
        onObjectAdded: (index, object) => menu.addMenuItem(object)
        onObjectRemoved: (index, object) => menu.removeMenuItem(object)
    }

    Component {
        id: menuComponent
        PlasmaExtras.Menu {}
    }

    Component {
        id: menuItemComponent

        PlasmaExtras.MenuItem {
            id: menuItem

            required property var modelData
            property PlasmaExtras.Menu subMenu: modelData.subActions
                ? menuComponent.createObject(menuItem, { visualParent: menuItem.action })
                : null

            text: modelData.text ? modelData.text : ""
            enabled: modelData.type !== "title" && ("enabled" in modelData ? modelData.enabled : true)
            separator: modelData.type === "separator"
            section: modelData.type === "title"
            icon: modelData.icon ? modelData.icon : null
            checkable: modelData.hasOwnProperty("checkable") ? modelData.checkable : false
            checked: modelData.hasOwnProperty("checked") ? modelData.checked : false

            property Instantiator _instantiator: Instantiator {
                active: menuItem.subMenu !== null
                model: modelData.subActions
                delegate: menuItemComponent
                onObjectAdded: (index, object) => subMenu.addMenuItem(object)
                onObjectRemoved: (index, object) => subMenu.removeMenuItem(object)
            }

            onClicked: {
                const modelActionTriggered = Tools.triggerAction(
                    menu.visualParent.view.model,
                    menu.visualParent.index,
                    modelData.actionId,
                    modelData.actionArgument
                )
                if (modelActionTriggered) {
                    kickoff.expanded = false
                }
            }
        }
    }
}
