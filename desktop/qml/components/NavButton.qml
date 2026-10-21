import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: nav
    property string label: ""
    property string icon: "home"
    property bool active: false
    property string shortcut: ""
    signal clicked()

    ToolTip.visible: mouse.containsMouse && nav.shortcut.length > 0
    ToolTip.text: nav.shortcut
    ToolTip.delay: 250

    Layout.fillWidth: true
    implicitHeight: 40
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: nav.active ? "#EBEEF2"
                          : (mouse.pressed ? "#E7EAEE" : (mouse.containsMouse ? "#F1F3F5" : "transparent"))
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        NavIcon {
            width: 18
            height: 18
            kind: nav.icon
            color: nav.active ? T.ink : T.muted
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: nav.label
            color: nav.active ? T.ink : T.inkSoft
            font.family: T.fontCN
            font.pixelSize: 14
            font.bold: nav.active
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: nav.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nav.clicked()
    }
}
