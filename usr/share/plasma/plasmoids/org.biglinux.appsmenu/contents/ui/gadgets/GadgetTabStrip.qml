/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetTabStrip — a single row of selectable chips that scrolls sideways
    when it runs out of room.

    Gadgets used to solve this with `model: things.slice(0, wide ? 5 : 3)`,
    which silently dropped everything past the cut: the news gadget hid two of
    its five sources, and you could neither see nor reach them. Squeezing the
    chips instead would only trade a hidden item for an unreadable one.

    So the chips keep their natural width and the strip scrolls: by flick or
    drag, by wheel (vertical or horizontal — a mouse only has the one axis and
    the user still means "move along the strip"), and with a thin scrollbar
    that appears only while it is needed. When everything fits, the strip
    consumes no wheel events at all, so the page behind it keeps scrolling
    normally.
*/

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: strip

    /*  Any array whose entries have a `name`. */
    property var model: []
    property int currentIndex: 0
    /*  Emitted with the index the user picked; the owner stores it. */
    signal activated(int index)

    readonly property bool overflowing: list.contentWidth > list.width + 1

    implicitHeight: Kirigami.Units.iconSizes.smallMedium
        + (overflowing ? Kirigami.Units.smallSpacing : 0)

    ListView {
        id: list

        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        model: strip.model

        delegate: PC3.ToolButton {
            required property var modelData
            required property int index

            text: modelData.name
            checkable: true
            checked: index === strip.currentIndex
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
            onClicked: strip.activated(index)

            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.name
        }

        QQC2.ScrollBar.horizontal: PC3.ScrollBar {
            policy: strip.overflowing ? QQC2.ScrollBar.AsNeeded
                                      : QQC2.ScrollBar.AlwaysOff
        }

        /*  Keep the selected chip reachable after a programmatic change. */
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        currentIndex: strip.currentIndex
        highlightMoveDuration: 0
    }

    WheelHandler {
        /*  Disabled while everything fits, so the wheel goes on scrolling the
            page behind instead of being swallowed here. */
        enabled: strip.overflowing
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y
                                                   : event.angleDelta.x
            const max = Math.max(0, list.contentWidth - list.width)
            list.contentX = Math.max(0, Math.min(max, list.contentX - delta))
        }
    }
}
