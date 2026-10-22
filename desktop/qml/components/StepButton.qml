import QtQuick
import md3.Core as MD3

MD3.IconButton {
    id: control
    property string glyph: "+"

    icon: glyph === "−" ? "remove" : "add"
    type: "outlined"
    implicitWidth: 30
    implicitHeight: 30
    iconSize: 16
}
