/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    RingGauge — animated circular gauge (0..1) drawn with QtQuick.Shapes.
*/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: gauge
    property real value: 0            // 0..1
    property color color: Kirigami.Theme.highlightColor
    property real thickness: Math.max(3, Math.min(width, height) * 0.09)
    property real startAngle: -215
    property real sweepMax: 250
    default property alias content: centre.data

    readonly property real clamped: Math.max(0, Math.min(1, value))
    property real shown: 0
    Behavior on shown { NumberAnimation { duration: Kirigami.Units.longDuration * 2; easing.type: Easing.OutCubic } }
    onClampedChanged: shown = clamped
    Component.onCompleted: shown = clamped

    readonly property real r: Math.min(width, height) / 2 - thickness / 2

    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 4
        // track
        ShapePath {
            strokeColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.width / 2; centerY: gauge.height / 2
                radiusX: gauge.r; radiusY: gauge.r
                startAngle: gauge.startAngle
                sweepAngle: gauge.sweepMax
            }
        }
        // value
        ShapePath {
            strokeColor: gauge.color
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.width / 2; centerY: gauge.height / 2
                radiusX: gauge.r; radiusY: gauge.r
                startAngle: gauge.startAngle
                sweepAngle: Math.max(0.01, gauge.sweepMax * gauge.shown)
            }
        }
    }
    Item {
        id: centre
        anchors.centerIn: parent
        width: (gauge.r - gauge.thickness) * 1.5
        height: width
    }
}
