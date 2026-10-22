import QtQuick
import md3.Core as MD3

MD3.Chip {
    id: control
    property string label: ""

    type: "filter"
    text: label
    implicitHeight: 32
}
