import QtQuick
import QtQuick.Controls
import "."

CheckBox {
    id: control
    font.family: Theme.fontFamily
    font.pixelSize: 13
    spacing: 10
    padding: 0

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 5
        border.color: control.checked ? Theme.accent
                     : control.hovered ? Theme.borderHi : Theme.border
        border.width: 1.5
        color: control.checked ? Theme.accent : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        GlyphIcon {
            anchors.centerIn: parent
            size: 14
            name: "play"
            color: "#ffffff"
            visible: false
        }
        Canvas {
            id: checkCanvas
            anchors.fill: parent
            visible: control.checked
            onPaint: {
                const ctx = getContext("2d"); ctx.reset()
                ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 2
                ctx.lineCap = "round"; ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(width*0.22, height*0.52)
                ctx.lineTo(width*0.44, height*0.72)
                ctx.lineTo(width*0.78, height*0.32)
                ctx.stroke()
            }
            Connections {
                target: control
                function onCheckedChanged() { checkCanvas.requestPaint() }
            }
        }
    }

    contentItem: Text {
        text: control.text
        color: Theme.text
        font: control.font
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
