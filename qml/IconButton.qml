import QtQuick
import QtQuick.Controls
import "."

AbstractButton {
    id: control
    property string iconName: ""
    property color iconColor: Theme.text
    property color hoverBg: Theme.surfaceHi
    property color pressBg: Theme.surfaceHi2
    property int iconSize: 16
    property string tip: ""
    property bool danger: false
    property bool primary: false

    hoverEnabled: true
    implicitWidth: 36
    implicitHeight: 36
    padding: 0

    ToolTip.visible: hovered && tip.length > 0
    ToolTip.text: tip
    ToolTip.delay: 450

    background: Rectangle {
        radius: Theme.radiusSm
        color: control.primary
               ? (control.down ? Qt.darker(Theme.accent, 1.2)
                  : control.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
               : (control.down ? control.pressBg
                  : control.hovered ? control.hoverBg : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: Item {
        GlyphIcon {
            anchors.centerIn: parent
            name: control.iconName
            size: control.iconSize
            color: control.primary ? "#ffffff"
                  : control.danger ? Theme.danger
                  : control.enabled ? control.iconColor
                                    : Theme.textFaint
            opacity: control.enabled ? 1 : 0.45
        }
    }
}
