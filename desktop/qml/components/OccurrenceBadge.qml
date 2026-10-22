import QtQuick
import "../Theme.js" as T

Rectangle {
    id: badge
    property int occurrence: 0

    visible: occurrence > 0
    implicitHeight: 24
    implicitWidth: label.implicitWidth + 18
    radius: 12
    color: occurrence > 1 ? T.ink : T.neutralPale
    border.width: 1
    border.color: occurrence > 1 ? T.ink : T.line

    Text {
        id: label
        anchors.centerIn: parent
        text: "第 " + badge.occurrence + " 次出现"
        color: badge.occurrence > 1 ? T.white : T.muted
        font.family: T.fontCN
        font.pixelSize: 10
        font.bold: badge.occurrence > 1
    }
}
