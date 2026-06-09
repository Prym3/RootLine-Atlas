import QtQuick
import QtQuick.Controls
import "."

TextField {
    id: control
    color: Theme.text
    selectionColor: Theme.accent
    selectedTextColor: "#ffffff"
    placeholderTextColor: Theme.textFaint
    selectByMouse: true
    font.family: Theme.fontFamily
    font.pixelSize: 13
    leftPadding: 12
    rightPadding: 12
    topPadding: 9
    bottomPadding: 9

    background: Rectangle {
        radius: Theme.radiusSm
        color: control.activeFocus ? Theme.surfaceHi : Theme.surface
        border.color: control.activeFocus ? Theme.accent
                     : control.hovered ? Theme.borderHi : Theme.border
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 130 } }
        Behavior on color { ColorAnimation { duration: 130 } }
    }
}
