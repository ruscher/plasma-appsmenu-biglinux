/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    SectionCard — Rounded card container for HomePage sections.
    Provides a themed background block with rounded corners, padding, and optional header.
    Usage: place as background behind a ColumnLayout section via cardTarget property.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Rectangle {
    id: root

    property string sectionTitle: ""
    property int itemCount: 0
    property bool collapsible: false
    property bool sectionExpanded: true
    property string headerIcon: ""

    signal toggleExpanded()

    radius: Kirigami.Units.largeSpacing
    color: Qt.rgba(
        Kirigami.Theme.backgroundColor.r,
        Kirigami.Theme.backgroundColor.g,
        Kirigami.Theme.backgroundColor.b,
        0.4
    )
    border.width: 1
    border.color: Qt.rgba(
        Kirigami.Theme.textColor.r,
        Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b,
        0.08
    )

    Accessible.role: Accessible.Grouping
    Accessible.name: sectionTitle
}
