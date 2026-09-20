/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar gadget — compact month grid, today highlighted, month navigation.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: cal
    required property var host

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()   // 0-11
    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek % 7   // 0 = Sunday
    readonly property bool isCurrentMonth: year === today.getFullYear() && month === today.getMonth()

    Component.onCompleted: host.accent = "#ef4444"

    Timer {
        interval: 60 * 60 * 1000
        running: cal.host.active
        repeat: true
        onTriggered: cal.today = new Date()
    }
    Connections {
        target: cal.host
        function onActiveChanged() { if (cal.host.active) cal.today = new Date() }
    }

    function monthName(y, m) {
        return Qt.locale().standaloneMonthName(m, Locale.LongFormat) + " " + y
    }
    function shift(delta) {
        let m = month + delta, y = year
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        month = m; year = y
    }
    // 42 cells: { day, inMonth, isToday }
    readonly property var cells: {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() - firstDayOfWeek + 7) % 7
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const daysPrev = new Date(year, month, 0).getDate()
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = i - offset + 1
            if (d < 1) out.push({ day: daysPrev + d, inMonth: false, isToday: false })
            else if (d > daysInMonth) out.push({ day: d - daysInMonth, inMonth: false, isToday: false })
            else out.push({ day: d, inMonth: true, isToday: isCurrentMonth && d === today.getDate() })
        }
        return out
    }
    readonly property int rowsNeeded: {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() - firstDayOfWeek + 7) % 7
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        return Math.ceil((offset + daysInMonth) / 7)
    }

    Binding { target: cal.host; property: "subtitle"; value: cal.isCurrentMonth ? "" : "" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            PC3.ToolButton {
                icon.name: "go-previous"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                implicitWidth: Kirigami.Units.iconSizes.smallMedium + 4
                implicitHeight: implicitWidth
                onClicked: cal.shift(-1)
                Accessible.name: i18n("Previous month")
            }
            PC3.Label {
                text: cal.monthName(cal.year, cal.month)
                font.weight: Font.DemiBold
                font.pointSize: cal.host.compact ? Kirigami.Theme.smallFont.pointSize : Kirigami.Theme.defaultFont.pointSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { cal.today = new Date(); cal.year = cal.today.getFullYear(); cal.month = cal.today.getMonth() }
                    PC3.ToolTip.text: i18n("Back to today")
                    PC3.ToolTip.visible: containsMouse && !cal.isCurrentMonth
                    hoverEnabled: true
                }
            }
            PC3.ToolButton {
                icon.name: "go-next"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                implicitWidth: Kirigami.Units.iconSizes.smallMedium + 4
                implicitHeight: implicitWidth
                onClicked: cal.shift(1)
                Accessible.name: i18n("Next month")
            }
        }

        // Weekday header
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0
            Repeater {
                model: 7
                delegate: PC3.Label {
                    required property int index
                    readonly property int dow: (cal.firstDayOfWeek + index) % 7
                    text: Qt.locale().dayName(dow === 0 ? 7 : dow, Locale.NarrowFormat)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    font.weight: Font.DemiBold
                    opacity: (dow === 0 || dow === 6) ? 0.45 : 0.6
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }

        // Days
        GridLayout {
            id: daysGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rows: cal.rowsNeeded
            rowSpacing: 0
            columnSpacing: 0
            readonly property real cellSize: Math.min(width / 7, height / Math.max(1, cal.rowsNeeded))

            Repeater {
                model: cal.cells.slice(0, cal.rowsNeeded * 7)
                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(14, Math.min(parent.width, parent.height) * 0.86)
                        height: width
                        radius: width / 2
                        color: modelData.isToday ? cal.host.accent : (dayHover.hovered && modelData.inMonth ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12) : "transparent")
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                        HoverHandler { id: dayHover }
                        PC3.Label {
                            anchors.centerIn: parent
                            text: modelData.day
                            font.pointSize: Math.max(6, Math.min(Kirigami.Theme.defaultFont.pointSize, daysGrid.cellSize * 0.42))
                            font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            color: modelData.isToday ? "white" : Kirigami.Theme.textColor
                            opacity: modelData.inMonth ? 1 : 0.3
                        }
                    }
                }
            }
        }
    }
}
