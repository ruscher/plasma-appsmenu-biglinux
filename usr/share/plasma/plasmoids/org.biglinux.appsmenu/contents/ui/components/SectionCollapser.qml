/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import "../singletons" as Singletons

RowLayout {
    id: root
    property string sectionTitle: ""
    property int itemCount: 0
    property bool expanded: true

    signal toggleExpanded()

    height: Singletons.MenuSingleton.compactListDelegateHeight
    spacing: Kirigami.Units.smallSpacing

    Accessible.role: Accessible.Heading
    Accessible.name: sectionTitle + " (" + itemCount + " " + i18n("items") + ")"

    PC3.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Singletons.MenuSingleton.listItemMetrics.margins.left
        text: root.sectionTitle
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        textFormat: Text.PlainText
        maximumLineCount: 1
        verticalAlignment: Text.AlignVCenter
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
        icon.name: root.expanded ? "arrow-up" : "arrow-down"
        display: PC3.AbstractButton.IconOnly
        Accessible.name: root.expanded ? i18n("Collapse %1", root.sectionTitle) : i18n("Expand %1", root.sectionTitle)
        onClicked: root.toggleExpanded()
    }
}
