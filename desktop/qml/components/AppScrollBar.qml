import QtQuick
import QtQuick.Controls
import "../Theme.js" as T

ScrollBar {
    id: scrollBar
    width: 13
    padding: 2
    policy: ScrollBar.AsNeeded

    contentItem: Rectangle {
        implicitWidth: 9
        implicitHeight: 9
        radius: 5
        color: scrollBar.pressed ? T.muted : (scrollBar.hovered ? "#B8BDC5" : "#DDE1E6")
        opacity: scrollBar.size < 1 ? 1 : 0
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    background: Item {}
}
