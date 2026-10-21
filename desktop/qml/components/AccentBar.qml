import QtQuick
import md3.Core as MD3
import "../Theme.js" as T

MD3.LinearProgress {
    id: bar

    property color color1: T.ink
    property color color2: T.ink
    property color trackColor: "#F1F3F5"

    implicitHeight: 4
}
