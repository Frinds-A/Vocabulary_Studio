import QtQuick
import md3.Core as MD3

Item {
    id: control
    property bool checked: false
    signal toggled()

    implicitWidth: 52
    implicitHeight: 32
    opacity: enabled ? 1 : 0.45

    MD3.Switch {
        id: sw
        anchors.fill: parent
        text: ""
        showIcon: false
        enabled: control.enabled
        onClicked: control.toggled()
    }

    onCheckedChanged: {
        if (sw.checked !== checked)
            sw.checked = checked
    }
    Component.onCompleted: sw.checked = checked
}
