/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

RowLayout {
    id: root

    property string sectionTitle: ""
    property int itemCount: 0
    property bool expanded: true
    property bool collapsible: true
    property string actionText: ""
    property string actionIcon: ""

    signal actionTriggered()
    signal toggleExpanded()

    spacing: Kirigami.Units.smallSpacing

    Accessible.role: Accessible.StaticText
    Accessible.name: sectionTitle + (itemCount > 0 ? " (" + itemCount + ")" : "")

    PC3.Label {
        Layout.fillWidth: true
        text: root.sectionTitle
        font.weight: Font.DemiBold
        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
        elide: Text.ElideRight
        textFormat: Text.PlainText
        color: Kirigami.Theme.textColor
    }

    PC3.Label {
        visible: root.itemCount > 0
        text: "(" + root.itemCount + ")"
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
        textFormat: Text.PlainText
    }

    PC3.ToolButton {
        visible: root.actionText.length > 0
        text: root.actionText
        icon.name: root.actionIcon
        font: Kirigami.Theme.smallFont
        display: root.actionIcon.length > 0 ? PC3.AbstractButton.TextBesideIcon : PC3.AbstractButton.TextOnly
        Accessible.name: root.actionText
        Accessible.role: Accessible.Button
        onClicked: root.actionTriggered()
    }

    PC3.ToolButton {
        visible: root.collapsible
        icon.name: root.expanded ? "arrow-up" : "arrow-down"
        display: PC3.AbstractButton.IconOnly
        Accessible.name: root.expanded ? i18n("Collapse %1", root.sectionTitle) : i18n("Expand %1", root.sectionTitle)
        Accessible.role: Accessible.Button
        onClicked: root.toggleExpanded()
    }
}
