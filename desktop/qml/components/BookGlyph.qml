import QtQuick

Canvas {
    id: root
    width: 16
    height: 16
    property color color: "#6B7078"

    onColorChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.strokeStyle = color
        ctx.lineWidth = 1.2
        ctx.lineJoin = "round"
        ctx.beginPath()
        ctx.moveTo(3, 2)
        ctx.lineTo(13, 2)
        ctx.lineTo(13, 14)
        ctx.lineTo(3, 14)
        ctx.closePath()
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(5.5, 2)
        ctx.lineTo(5.5, 14)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(8, 5)
        ctx.lineTo(11, 5)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(8, 8)
        ctx.lineTo(11, 8)
        ctx.stroke()
    }
}
