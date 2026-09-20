/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    SmartSection — Contextual app suggestions based on usage patterns and time of day
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami
import "../singletons" as Singletons
import "../code/tools.js" as Tools

ColumnLayout {
    id: root

    required property var frequentModel
    required property var favoritesModel
    property int maxItems: 6
    property bool showHeader: true
    readonly property int smartCount: smartRepeater.count

    spacing: 0
    // When showHeader is false (inside SectionCard), parent controls visibility
    visible: showHeader ? (Plasmoid.configuration.showSmartSection && smartRepeater.count > 0) : true

    Accessible.role: Accessible.Grouping
    Accessible.name: i18n("Suggested for you")

    // Section header (hidden when inside a SectionCard that provides its own)
    PC3.AbstractButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Singletons.MenuSingleton.compactListDelegateHeight
        visible: root.showHeader

        Accessible.role: Accessible.StaticText
        Accessible.name: i18n("Suggested for you, %1 items", smartRepeater.count)

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: i18n("Suggested for you")
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
            }

            PC3.Label {
                text: smartRepeater.count
                opacity: 0.6
                Layout.rightMargin: Kirigami.Units.largeSpacing
            }
        }
    }

    // Horizontal flow of suggested apps (compact icons)
    Flow {
        id: smartFlow
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            id: smartRepeater
            model: ListModel { id: smartModel }

            delegate: PC3.AbstractButton {
                id: smartDelegate
                width: Singletons.MenuSingleton.gridCellSize
                height: width

                Accessible.role: Accessible.MenuItem
                Accessible.name: model.display || ""
                Accessible.description: i18n("Suggested application")

                contentItem: ColumnLayout {
                    spacing: 2

                    Kirigami.Icon {
                        source: model.decoration || "application-x-executable"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                        Layout.alignment: Qt.AlignHCenter
                    }

                    PC3.Label {
                        text: model.display || ""
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        Layout.fillWidth: true
                    }
                }

                hoverEnabled: true

                background: Rectangle {
                    radius: Kirigami.Units.smallSpacing
                    color: smartDelegate.hovered || smartDelegate.activeFocus
                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15)
                        : "transparent"
                }

                onClicked: {
                    const sourceIndex = model.sourceIndex;
                    if (sourceIndex >= 0 && root.frequentModel) {
                        root.frequentModel.trigger(sourceIndex, "", null);
                    }
                }

                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
            }
        }
    }

    // Recalculate suggestions when the component becomes visible
    function refreshSuggestions() {
        smartModel.clear();
        if (!root.frequentModel || !root.visible) return;

        const scores = Tools.computeSmartScores(
            root.frequentModel,
            root.favoritesModel,
            root.maxItems
        );

        for (let i = 0; i < scores.length; i++) {
            const srcIdx = root.frequentModel.index(scores[i].index, 0);
            smartModel.append({
                display: root.frequentModel.data(srcIdx, Qt.DisplayRole) || "",
                decoration: root.frequentModel.data(srcIdx, Qt.DecorationRole) || "application-x-executable",
                sourceIndex: scores[i].index,
            });
        }
    }

    Component.onCompleted: refreshSuggestions()

    Connections {
        target: kickoff
        function onExpandedChanged() {
            if (kickoff.expanded) {
                root.refreshSuggestions();
            }
        }
    }
}
