import QtQuick
import QtQuick.Controls
import "."

Label {
    property string label: ""
    color: Theme.textFaint
    font.family: Theme.fontFamily
    font.pixelSize: 10
    font.letterSpacing: 1.4
    font.bold: true
    text: label.toUpperCase()
}
