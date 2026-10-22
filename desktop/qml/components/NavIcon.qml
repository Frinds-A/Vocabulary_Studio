import QtQuick

Item {
    id: icon
    property string kind: "home"
    property color color: "#61666B"

    implicitWidth: 20
    implicitHeight: 20

    onColorChanged: canvas.requestPaint()
    onKindChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = icon.color
            ctx.fillStyle = icon.color
            ctx.lineWidth = 1.7
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

            if (icon.kind === "home") {
                strokeRoundRect(4.5, 5.0, 11.0, 11.5, 3)
                ctx.beginPath()
                ctx.moveTo(4.5, 8.8)
                ctx.lineTo(15.5, 8.8)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(7.5, 3.6)
                ctx.lineTo(7.5, 6.4)
                ctx.moveTo(12.5, 3.6)
                ctx.lineTo(12.5, 6.4)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(10, 12.7, 1.1, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.kind === "library") {
                strokeRoundRect(4.5, 4.0, 11.0, 12.0, 2.5)
                ctx.beginPath()
                ctx.moveTo(10, 5.2)
                ctx.lineTo(10, 15.0)
                ctx.stroke()
            } else if (icon.kind === "practice") {
                ctx.beginPath()
                ctx.arc(10, 10, 6.6, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(8.6, 7.2)
                ctx.lineTo(13.1, 10)
                ctx.lineTo(8.6, 12.8)
                ctx.closePath()
                ctx.fill()
            } else if (icon.kind === "notebook") {
                strokeRoundRect(5.0, 3.6, 10.0, 12.8, 2.4)
                ctx.beginPath()
                ctx.moveTo(7.5, 7.2)
                ctx.lineTo(12.5, 7.2)
                ctx.moveTo(7.5, 10.0)
                ctx.lineTo(12.5, 10.0)
                ctx.moveTo(7.5, 12.8)
                ctx.lineTo(11.0, 12.8)
                ctx.stroke()
            } else if (icon.kind === "stats") {
                ctx.lineWidth = 2.2
                ctx.beginPath()
                ctx.moveTo(6.0, 15.5)
                ctx.lineTo(6.0, 11.0)
                ctx.moveTo(10.0, 15.5)
                ctx.lineTo(10.0, 6.5)
                ctx.moveTo(14.0, 15.5)
                ctx.lineTo(14.0, 9.0)
                ctx.stroke()
            } else if (icon.kind === "settings") {
                ctx.lineWidth = 1.6
                ctx.beginPath()
                ctx.moveTo(4.0, 6.2)
                ctx.lineTo(16.0, 6.2)
                ctx.moveTo(4.0, 10.0)
                ctx.lineTo(16.0, 10.0)
                ctx.moveTo(4.0, 13.8)
                ctx.lineTo(16.0, 13.8)
                ctx.stroke()
                var knobs = [[7.0, 6.2], [13.0, 10.0], [9.5, 13.8]]
                for (var i = 0; i < knobs.length; ++i) {
                    ctx.beginPath()
                    ctx.arc(knobs[i][0], knobs[i][1], 1.9, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}

