/*
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton

import QtQml 2.15
import QtQuick 2.15
import QtQuick.Templates 2.15 as T
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.plasma5support 2.0 as P5Support

Item {
    id: root
    visible: false

    // Power management data source
    readonly property P5Support.DataSource powerManagement: P5Support.DataSource {
        engine: "powermanagement"
        connectedSources: ["PowerDevil"]
        onSourceAdded: source => {
            disconnectSource(source);
            connectSource(source);
        }
        onSourceRemoved: source => disconnectSource(source);
    }

    // Reusable SVG elements
    readonly property KSvg.Svg lineSvg: KSvg.Svg {
        imagePath: "widgets/line"
        property int horLineHeight: lineSvg.elementSize("horizontal-line").height
        property int vertLineWidth: lineSvg.elementSize("vertical-line").width
    }

    // List item frame metrics
    readonly property KSvg.FrameSvgItem listItemMetrics: KSvg.FrameSvgItem {
        visible: false
        imagePath: "widgets/listitem"
        prefix: "normal"
    }

    // Font metrics for sizing calculations
    readonly property FontMetrics fontMetrics: FontMetrics {
        font: Kirigami.Theme.defaultFont
    }

    // Grid cell size: icon + label + padding (avoids circular dep with AppDelegate)
    readonly property real gridCellSize: {
        var iconSize = Kirigami.Units.iconSizes.large;
        var labelHeight = fontMetrics.height * 2; // Two lines for name
        var vertPadding = Kirigami.Units.smallSpacing * 4; // top + bottom padding
        var spacing = fontMetrics.descent;
        return iconSize + labelHeight + vertPadding + spacing;
    }

    // Compact list delegate metrics (calculated inline)
    readonly property real compactListDelegateHeight: {
        var iconSize = Kirigami.Units.iconSizes.small;
        var vertPadding = Kirigami.Units.mediumSpacing * 2;
        return Math.max(iconSize, fontMetrics.height) + vertPadding;
    }
    // Content height only (no padding) — used for section-header font size and
    // single-letter section width. Equal to the row height it made headers huge.
    readonly property real compactListDelegateContentHeight: Math.max(Kirigami.Units.iconSizes.small, fontMetrics.height)

    // Accessibility constants
    readonly property real minimumTouchTarget: 44
    readonly property real focusRingWidth: 2
    readonly property real minimumInteractiveSize: Math.max(minimumTouchTarget, Kirigami.Units.gridUnit * 2)

    // Animation constants
    readonly property int shortDuration: Kirigami.Units.shortDuration
    readonly property int longDuration: Kirigami.Units.longDuration
    readonly property int veryLongDuration: Kirigami.Units.veryLongDuration

    // Search debounce
    readonly property int searchDebounceMs: 150

}
