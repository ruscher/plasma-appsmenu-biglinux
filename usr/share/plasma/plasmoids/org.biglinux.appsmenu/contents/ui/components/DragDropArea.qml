/*
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQml 2.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import "../delegates" as Delegates

DropArea {
    id: root
    required property Flickable targetView
    readonly property bool enableAutoScroll: targetView.height < targetView.contentHeight
    property real scrollUpMargin: 0
    property real scrollDownMargin: 0

    // Undo stack for reorder operations (stores {from, to} pairs)
    property var _undoStack: []

    enabled: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable

    onPositionChanged: {
        if (drag.source instanceof Delegates.AppDelegate) {
            const source = drag.source
            const view = drag.source.view
            if (source.view === root.targetView && !view.move.running && !view.moveDisplaced.running) {
                const pos = mapToItem(view.contentItem, drag.x, drag.y)
                const targetIndex = view.indexAt(pos.x, pos.y)
                if (targetIndex >= 0 && targetIndex !== source.index) {
                    _undoStack.push({ from: source.index, to: targetIndex })
                    view.model.moveRow(source.index, targetIndex)
                    view.currentIndex = source.index
                }
            }
        }
    }

    function moveRow(targetIndex) {
        if (targetIndex < 0 || targetIndex >= targetView.count) {
            return;
        }
        _undoStack.push({ from: targetView.currentIndex, to: targetIndex })
        targetView.model.moveRow(targetView.currentIndex, targetIndex);
        targetView.currentIndex = targetIndex;
    }

    function undoLastMove() {
        if (_undoStack.length === 0) return;
        const last = _undoStack.pop();
        targetView.model.moveRow(last.to, last.from);
        targetView.currentIndex = last.from;
    }

    Shortcut {
        enabled: (targetView instanceof GridView && targetView.currentIndex >= targetView.columns)
              || (targetView instanceof ListView && targetView.currentIndex > 0)
        sequence: "Ctrl+Shift+Up"
        onActivated: moveRow(targetView.currentIndex - (targetView instanceof GridView ? targetView.columns : 1))
    }

    Shortcut {
        enabled: (targetView instanceof GridView && targetView.currentIndex < targetView.count - targetView.columns)
              || (targetView instanceof ListView && targetView.currentIndex + 1 < targetView.count)
        sequence: "Ctrl+Shift+Down"
        onActivated: moveRow(targetView.currentIndex + (targetView instanceof GridView ? targetView.columns : 1))
    }

    Shortcut {
        enabled: targetView instanceof GridView && targetView.currentIndex % targetView.columns > 0
        sequence: "Ctrl+Shift+Left"
        onActivated: moveRow(targetView.currentIndex - 1)
    }

    Shortcut {
        enabled: targetView instanceof GridView && targetView.currentIndex % targetView.columns !== targetView.columns - 1
        sequence: "Ctrl+Shift+Right"
        onActivated: moveRow(targetView.currentIndex + 1)
    }

    Shortcut {
        enabled: root._undoStack.length > 0
        sequence: StandardKey.Undo
        onActivated: undoLastMove()
    }

    // Clear undo stack when the menu closes
    Connections {
        target: kickoff
        function onExpandedChanged() {
            if (!kickoff.expanded) {
                root._undoStack = [];
            }
        }
    }

    SmoothedAnimation {
        target: root.targetView
        property: "contentY"
        to: 0
        velocity: 200
        running: root.enableAutoScroll && root.containsDrag && root.drag.y <= root.scrollUpMargin
    }

    SmoothedAnimation {
        target: root.targetView
        property: "contentY"
        to: root.targetView.contentHeight - root.targetView.height
        velocity: 200
        running: root.enableAutoScroll && root.containsDrag && root.drag.y >= root.height - root.scrollDownMargin
    }
}
