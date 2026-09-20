/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Small gold star badge shown on favorited app icons
*/

import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root
    property bool showIndicator: false

    visible: showIndicator
    width: Kirigami.Units.iconSizes.small * 0.8
    height: width

    Accessible.ignored: true

    Kirigami.Icon {
        anchors.fill: parent
        source: "starred-symbolic"
        color: "#FFD700" // gold star
    }
}
