/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Sparkline — filled line graph of a numeric history (Canvas, repainted only
    when values change). Two series supported (a on top of b).
*/

import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

Canvas {
    id: spark
    property var values: []        // series A (newest last)
    property var values2: []       // optional series B
    property color color: Kirigami.Theme.highlightColor
    property color color2: Kirigami.Theme.positiveTextColor
    property real maxValue: 0      // 0 = auto
    property bool fill: true

    onValuesChanged: requestPaint()
    onValues2Changed: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function drawSeries(ctx, vals, col, max) {
        if (!vals || vals.length < 2) return
        const n = vals.length
        const stepX = width / Math.max(1, n - 1)
        ctx.beginPath()
        for (let i = 0; i < n; i++) {
            const x = i * stepX
            const y = height - (Math.max(0, vals[i]) / max) * (height - 2) - 1
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.lineWidth = 2
        ctx.strokeStyle = col
        ctx.lineJoin = "round"
        ctx.stroke()
        if (fill) {
            ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
            const g = ctx.createLinearGradient(0, 0, 0, height)
            g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.35))
            g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.02))
            ctx.fillStyle = g
            ctx.fill()
        }
    }
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        let max = maxValue
        if (max <= 0) {
            max = 1
            for (const v of values) if (v > max) max = v
            for (const v of values2) if (v > max) max = v
            max *= 1.15
        }
        // baseline
        ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
        ctx.lineWidth = 1
        ctx.beginPath(); ctx.moveTo(0, height - 0.5); ctx.lineTo(width, height - 0.5); ctx.stroke()
        drawSeries(ctx, values2, color2, max)
        drawSeries(ctx, values, color, max)
    }
}
