import QtQuick
import QtQuick.Controls
import md3.Core as MD3
import "../Theme.js" as T

MD3.Button {
    id: control
    property bool bordered: false
    property string shortcut: "Enter"

    ToolTip.visible: control.hovered && control.shortcut.length > 0
    ToolTip.text: control.shortcut
    ToolTip.delay: 250
    type: "text"
    containerColor: "transparent"
    contentColor: enabled ? T.ink : T.faint
    stateLayerColor: "transparent"
    outlineColor: "transparent"
    opacity: enabled ? 1 : 0.45
    fontSize: 13
    implicitHeight: 36
    horizontalPadding: 12

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "transparent"
        border.width: (control.bordered || control.hovered) ? 1 : 0
        border.color: control.hovered ? T.ink : T.lineStrong
        antialiasing: true
        enabled: false
        z: 5
    }
}
