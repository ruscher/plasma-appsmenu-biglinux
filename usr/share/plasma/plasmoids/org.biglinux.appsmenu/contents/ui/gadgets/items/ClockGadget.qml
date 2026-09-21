/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Clock gadget — analog (sweeping hands) or digital, with date.
    cfg: { mode: "analog"|"digital", h24: bool, seconds: bool, date: bool }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: clock
    required property var host

    readonly property string mode: host.cfg.mode || "analog"
    readonly property bool h24: host.cfg.h24 !== undefined ? host.cfg.h24 : true
    readonly property bool showSeconds: host.cfg.seconds !== undefined ? host.cfg.seconds : true
    readonly property bool showDate: host.cfg.date !== undefined ? host.cfg.date : true

    property date now: new Date()

    Component.onCompleted: {
        host.accentColor = "#3b82f6"
        host.settingsComponent = settings
    }

    Timer {
        interval: clock.showSeconds ? 1000 : 10000
        running: clock.host.active
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }
    // Keep hands correct even while paused (refresh once when reactivated)
    Connections {
        target: clock.host
        function onActiveChanged() { if (clock.host.active) clock.now = new Date() }
    }

    readonly property string timeText: {
        const fmt = clock.h24 ? (clock.showSeconds ? "HH:mm:ss" : "HH:mm") : (clock.showSeconds ? "h:mm:ss" : "h:mm")
        return Qt.formatTime(now, fmt)
    }
    readonly property string ampmText: clock.h24 ? "" : Qt.formatTime(now, "AP")
    readonly property string dateText: Qt.formatDate(now, Qt.locale().dateFormat(Locale.LongFormat))

    Binding { target: host; property: "subtitle"; value: clock.mode === "analog" && clock.showDate && host.wide ? "" : "" }

    // ── ANALOG ──
    Item {
        id: analog
        visible: clock.mode === "analog"
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Item {
                id: faceBox
                Layout.fillHeight: true
                Layout.fillWidth: !clock.host.wide
                Layout.preferredWidth: height
                // leave room for the date label under the dial in compact mode
                readonly property real reserved: (clock.showDate && !clock.host.wide) ? dateLabel.implicitHeight + Kirigami.Units.smallSpacing : 0
                readonly property real d: Math.min(width, height - reserved)

                Rectangle {
                    id: face
                    width: faceBox.d
                    height: faceBox.d
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (faceBox.height - faceBox.reserved - height) / 2
                    radius: width / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                    border.width: Math.max(1, width * 0.012)
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)

                    // ticks
                    Repeater {
                        model: 60
                        delegate: Rectangle {
                            required property int index
                            readonly property bool major: index % 5 === 0
                            width: major ? Math.max(2, face.width * 0.018) : 1
                            height: major ? face.width * 0.08 : face.width * 0.04
                            radius: width / 2
                            color: Kirigami.Theme.textColor
                            opacity: major ? 0.9 : 0.35
                            x: face.width / 2 - width / 2
                            y: face.width * 0.035
                            transform: Rotation { origin.x: width / 2; origin.y: face.width / 2 - face.width * 0.035; angle: index * 6 }
                        }
                    }
                    // hour numbers 12/3/6/9
                    Repeater {
                        model: [ { n: "12", a: 0 }, { n: "3", a: 90 }, { n: "6", a: 180 }, { n: "9", a: 270 } ]
                        delegate: PC3.Label {
                            required property var modelData
                            text: modelData.n
                            font.pointSize: Math.max(6, face.width * 0.075)
                            font.weight: Font.DemiBold
                            opacity: 0.8
                            readonly property real r: face.width * 0.36
                            x: face.width / 2 + r * Math.sin(modelData.a * Math.PI / 180) - width / 2
                            y: face.width / 2 - r * Math.cos(modelData.a * Math.PI / 180) - height / 2
                        }
                    }

                    // hands
                    component Hand : Rectangle {
                        id: hand
                        property real len: 0.3
                        property real thick: 0.03
                        property real angle: 0
                        width: Math.max(2, face.width * thick)
                        height: face.width * len
                        radius: width / 2
                        x: face.width / 2 - width / 2
                        y: face.width / 2 - height + width / 2
                        antialiasing: true
                        transform: Rotation {
                            origin.x: width / 2; origin.y: height - width / 2
                            angle: hand.angle
                            Behavior on angle {
                                enabled: Kirigami.Units.longDuration > 0
                                RotationAnimation { duration: 500; direction: RotationAnimation.Clockwise; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    Hand { len: 0.24; thick: 0.05; color: Kirigami.Theme.textColor; angle: (clock.now.getHours() % 12) * 30 + clock.now.getMinutes() * 0.5 }
                    Hand { len: 0.36; thick: 0.035; color: Kirigami.Theme.textColor; angle: clock.now.getMinutes() * 6 + clock.now.getSeconds() * 0.1 }
                    Hand { visible: clock.showSeconds; len: 0.42; thick: 0.012; color: clock.host.accent; angle: clock.now.getSeconds() * 6 }
                    Rectangle {
                        width: Math.max(4, face.width * 0.06); height: width; radius: width / 2
                        anchors.centerIn: parent
                        color: clock.host.accent
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.5)
                    }
                }
            }

            // Side text (only when wide)
            ColumnLayout {
                visible: clock.host.wide
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                PC3.Label {
                    text: clock.timeText
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                    font.weight: Font.Light
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                PC3.Label {
                    visible: clock.showDate
                    text: clock.dateText
                    opacity: 0.7
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }
        // Date under the face (compact)
        PC3.Label {
            id: dateLabel
            visible: clock.showDate && !clock.host.wide
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            text: Qt.formatDate(clock.now, Qt.locale().dateFormat(Locale.ShortFormat))
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
        }
    }

    // ── DIGITAL ──
    ColumnLayout {
        id: digital
        visible: clock.mode === "digital"
        anchors.fill: parent
        spacing: 0

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                id: bigTime
                text: clock.timeText
                font.pointSize: 72
                font.weight: Font.Light
                fontSizeMode: Text.HorizontalFit
                minimumPointSize: 10
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(clock.height * 0.55, clock.width * 0.45)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Kirigami.Theme.textColor
            }
            PC3.Label {
                visible: clock.ampmText.length > 0
                text: clock.ampmText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                Layout.alignment: Qt.AlignBottom
            }
        }
        PC3.Label {
            visible: clock.showDate
            text: clock.dateText
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Item { Layout.fillHeight: true }
    }

    // ── settings ──
    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.largeSpacing
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.RadioButton {
                    Kirigami.FormData.label: i18n("Style:")
                    text: i18n("Analog")
                    checked: (host.cfg.mode || "analog") === "analog"
                    onToggled: if (checked) host.setCfg("mode", "analog")
                }
                QQC2.RadioButton {
                    text: i18n("Digital")
                    checked: host.cfg.mode === "digital"
                    onToggled: if (checked) host.setCfg("mode", "digital")
                }
                QQC2.CheckBox {
                    Kirigami.FormData.label: i18n("Options:")
                    text: i18n("24-hour clock")
                    checked: host.cfg.h24 !== undefined ? host.cfg.h24 : true
                    onToggled: host.setCfg("h24", checked)
                }
                QQC2.CheckBox {
                    text: i18n("Show seconds")
                    checked: host.cfg.seconds !== undefined ? host.cfg.seconds : true
                    onToggled: host.setCfg("seconds", checked)
                }
                QQC2.CheckBox {
                    text: i18n("Show date")
                    checked: host.cfg.date !== undefined ? host.cfg.date : true
                    onToggled: host.setCfg("date", checked)
                }
            }
        }
    }
}
