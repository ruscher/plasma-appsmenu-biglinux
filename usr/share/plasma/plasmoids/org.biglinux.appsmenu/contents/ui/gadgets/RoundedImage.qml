/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    RoundedImage — network/local image cropped into a rounded rectangle
    (QtQuick.Effects mask), with a soft placeholder while loading.
*/

import QtQuick 2.15
import QtQuick.Effects
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root
    property alias source: img.source
    property real radius: Kirigami.Units.largeSpacing
    property alias status: img.status
    property alias fillMode: img.fillMode
    property string fallbackIcon: "image-x-generic"

    Rectangle {
        id: placeholder
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        visible: img.status !== Image.Ready
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.45
            height: width
            source: root.fallbackIcon
            opacity: 0.35
            visible: img.status !== Image.Loading
        }
    }

    Image {
        id: img
        anchors.fill: parent
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.max(1, Math.round(width * 1.5))
        sourceSize.height: Math.max(1, Math.round(height * 1.5))
        visible: false
        smooth: true
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        visible: img.status === Image.Ready
    }
}
