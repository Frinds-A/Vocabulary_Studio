import QtQuick
import QtQuick.Layouts
import "../Theme.js" as T

Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property string glyph: "•"
    property color tint: T.ink
    property color tintSoft: T.neutralPale
    property bool checked: false
    signal toggled()

    implicitHeight: 72
    radius: 12
    color: T.white
    border.width: 1
    border.color: T.line

    Item {
        anchors.fill: parent
        anchors.margins: 16

        Rectangle {
            id: iconBox
            width: 32
            height: 32
            radius: 7
            color: T.neutralPale
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 14
            }
        }

        ToggleSwitch {
            id: switchItem
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            onToggled: root.toggled()
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 14
            anchors.right: switchItem.left
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: root.title
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.subtitle
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }
}
