/*
    SPDX-FileCopyrightText: 2026 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    ActivitySection — one titled block of a Kicker activity model (frequently
    used applications, folders or files).

    It is a plain ListView sized to its content rather than a scrolling view of
    its own: several sections stack inside the Places page's single Flickable,
    so the page scrolls as one surface instead of trapping the wheel in
    whichever list the pointer happens to be over.

    The rows are the project's normal Delegates.AppDelegate, so activation,
    drag and drop, favourites and context menus behave exactly as they do
    everywhere else — including going through `model.trigger()`, which is what
    keeps KIO handling remote URLs correctly.

    Upstream already caps these models at 15 rows (Limit(15) in
    recentusagemodel.cpp), which is exactly the 8-15 per section this page
    wants, so there is no limiting proxy here — adding one would only mean a
    second model to keep in sync with `trigger()`.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "../delegates" as Delegates
import "../singletons" as Singletons

ColumnLayout {
    id: root

    /* A Kicker model (RecentUsageModel). */
    property var model: null

    property string title: ""
    property string iconName: ""

    readonly property alias view: listView
    readonly property int count: listView.count

    /* The page chains sections together with these so Up/Down walks the whole
       column rather than stopping at a section boundary. */
    signal focusPreviousRequested()
    signal focusNextRequested()

    spacing: 0
    visible: count > 0

    Accessible.role: Accessible.Grouping
    Accessible.name: root.title

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: root.iconName
            visible: root.iconName.length > 0
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            opacity: 0.7
        }

        PC3.Label {
            text: root.title
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Accessible.role: Accessible.Heading
        }

        PC3.Label {
            text: root.count
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.6
        }

        Item { Layout.fillWidth: true }
    }

    ListView {
        id: listView

        Layout.fillWidth: true
        Layout.preferredHeight: contentHeight

        /* The page owns the scrolling. */
        interactive: false
        reuseItems: true
        keyNavigationEnabled: false
        keyNavigationWraps: false

        readonly property real availableWidth: width - leftMargin - rightMargin
        /* AppDelegate reads these to decide whether a hover should steal focus
           from the keyboard; without them it would dereference undefined. */
        property bool movedWithKeyboard: false
        property bool movedWithWheel: false

        model: root.model

        currentIndex: -1
        highlightResizeDuration: 0
        highlightMoveDuration: 0

        Accessible.role: Accessible.List
        Accessible.name: root.title

        delegate: Delegates.AppDelegate {
            width: listView.availableWidth
            displayMode: "list"
        }

        Keys.onUpPressed: event => {
            if (listView.currentIndex > 0) {
                listView.movedWithKeyboard = true
                listView.currentIndex--
                listView.currentItem.forceActiveFocus(Qt.BacktabFocusReason)
            } else {
                root.focusPreviousRequested()
            }
        }

        Keys.onDownPressed: event => {
            if (listView.currentIndex < listView.count - 1) {
                listView.movedWithKeyboard = true
                listView.currentIndex++
                listView.currentItem.forceActiveFocus(Qt.TabFocusReason)
            } else {
                root.focusNextRequested()
            }
        }
    }

    /* Put the keyboard on this section's first (or last) row. Returns false
       when the section is empty, so the caller can skip to the next one. */
    function focusFirst() {
        if (listView.count === 0) {
            return false
        }
        listView.movedWithKeyboard = true
        listView.currentIndex = 0
        listView.forceActiveFocus(Qt.TabFocusReason)
        if (listView.currentItem) {
            listView.currentItem.forceActiveFocus(Qt.TabFocusReason)
        }
        return true
    }

    function focusLast() {
        if (listView.count === 0) {
            return false
        }
        listView.movedWithKeyboard = true
        listView.currentIndex = listView.count - 1
        listView.forceActiveFocus(Qt.BacktabFocusReason)
        if (listView.currentItem) {
            listView.currentItem.forceActiveFocus(Qt.BacktabFocusReason)
        }
        return true
    }
}
