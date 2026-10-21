import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: button
    property string kind: "minimize"
    property bool danger: false
    property string shortcut: ""
    signal clicked()

    ToolTip.visible: hover.hovered && button.shortcut.length > 0
    ToolTip.text: button.shortcut
    ToolTip.delay: 250

    Layout.preferredWidth: 44
    Layout.fillHeight: true
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "transparent"
        border.width: hover.hovered ? 1 : 0
        border.color: button.danger ? T.red : T.lineStrong
        antialiasing: true
        Behavior on border.color { ColorAnimation { duration: 140 } }
    }

    Canvas {
        id: canvas
        width: 16
        height: 16
        anchors.centerIn: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = hover.hovered && button.danger ? T.red : T.ink
            ctx.lineWidth = 1.6
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            function strokeRoundRect(x, y, w, h, r) {
                ctx.beginPath()
                ctx.moveTo(x + r, y)
                ctx.lineTo(x + w - r, y)
                ctx.arcTo(x + w, y, x + w, y + r, r)
                ctx.lineTo(x + w, y + h - r)
                ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                ctx.lineTo(x + r, y + h)
                ctx.arcTo(x, y + h, x, y + h - r, r)
                ctx.lineTo(x, y + r)
                ctx.arcTo(x, y, x + r, y, r)
                ctx.closePath()
                ctx.stroke()
            }

            if (button.kind === "minimize") {
                ctx.beginPath()
                ctx.moveTo(3.5, 8)
                ctx.lineTo(12.5, 8)
                ctx.stroke()
            } else if (button.kind === "maximize") {
                strokeRoundRect(3.5, 3.5, 9, 9, 1.2)
            } else if (button.kind === "restore") {
                strokeRoundRect(3.5, 5.5, 7, 7, 1.2)
                ctx.beginPath()
                ctx.moveTo(5.8, 5.5)
                ctx.lineTo(5.8, 3.5)
                ctx.lineTo(12.5, 3.5)
                ctx.lineTo(12.5, 10.2)
                ctx.lineTo(10.5, 10.2)
                ctx.stroke()
            } else if (button.kind === "close") {
                ctx.beginPath()
                ctx.moveTo(4.2, 4.2)
                ctx.lineTo(11.8, 11.8)
                ctx.moveTo(11.8, 4.2)
                ctx.lineTo(4.2, 11.8)
                ctx.stroke()
            }
        }
    }

    onKindChanged: canvas.requestPaint()
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: canvas.requestPaint()
    }
    TapHandler { enabled: button.enabled; onTapped: button.clicked() }
}
