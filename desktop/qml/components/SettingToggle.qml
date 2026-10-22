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
    property bool showSwitch: true
    property int extraHeight: 0
    default property alias extraContent: extraHost.data
    signal toggled()

    implicitHeight: 72 + extraHeight
    radius: 12
    color: T.white
    border.width: 1
    border.color: T.line

    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: extraHost.top
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
            visible: root.showSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            onToggled: root.toggled()
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 14
            anchors.right: root.showSwitch ? switchItem.left : parent.right
            anchors.rightMargin: root.showSwitch ? 18 : 0
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
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: extraHost
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.extraHeight
    }
}
