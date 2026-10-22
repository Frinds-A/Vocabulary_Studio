import QtQuick
import md3.Core as MD3
import "../Theme.js" as T

MD3.CircularProgress {
    id: ring
    property real progress: 0
    property color color1: T.ink
    property color color2: T.ink
    property color trackColor: "#F1F3F5"
    property real thickness: 8

    value: Math.max(0, Math.min(1, Number(progress) || 0))
    implicitWidth: 78
    implicitHeight: 78
    showTrack: true

    Behavior on value { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }
}
