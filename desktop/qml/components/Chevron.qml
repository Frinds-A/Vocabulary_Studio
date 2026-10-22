import QtQuick

Canvas {
    id: root
    width: 10
    height: 6
    property color color: "#9AA0A6"

    onColorChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.strokeStyle = color
        ctx.lineWidth = 1.3
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.moveTo(1, 1.5)
        ctx.lineTo(5, 4.8)
        ctx.lineTo(9, 1.5)
        ctx.stroke()
    }
}
