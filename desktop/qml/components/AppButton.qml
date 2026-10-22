import QtQuick
import QtQuick.Controls
import md3.Core as MD3
import "../Theme.js" as T

MD3.Button {
    id: control

    property bool primary: false
    property bool subtle: false
    property bool restoreStyle: false
    property bool showBorder: false
    property int radiusValue: 10
    property string shortcut: "Enter"

    ToolTip.visible: control.hovered && control.shortcut.length > 0
    ToolTip.text: control.shortcut
    ToolTip.delay: 250

    type: restoreStyle ? (primary ? "filled" : "outlined") : "text"
    containerColor: restoreStyle ? (primary ? T.ink : "transparent") : "transparent"
    contentColor: enabled
                  ? (restoreStyle ? (primary ? T.white : T.ink) : T.ink)
                  : T.faint
    stateLayerColor: restoreStyle ? (primary ? T.white : T.ink) : "transparent"
    outlineColor: restoreStyle ? T.lineStrong : "transparent"
    opacity: enabled ? 1 : 0.45
    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: !control.restoreStyle && (control.showBorder || control.hovered) ? 1 : 0
        border.color: control.hovered ? T.ink : T.lineStrong
        antialiasing: true
        enabled: false
        z: 5
    }
}
