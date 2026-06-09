import QtQuick
import QtQuick.Controls
import "."

ComboBox {
    id: control
    font.family: Theme.fontFamily
    font.pixelSize: 13
    leftPadding: 12
    rightPadding: 36
    topPadding: 9
    bottomPadding: 9
    implicitHeight: 36

    delegate: ItemDelegate {
        width: control.width
        height: 32
        contentItem: Text {
            text: modelData
            color: control.highlightedIndex === index ? "#ffffff" : Theme.text
            font: control.font
            verticalAlignment: Text.AlignVCenter
            leftPadding: 12
        }
        background: Rectangle {
            color: control.highlightedIndex === index ? Theme.accent
                  : hovered ? Theme.surfaceHi : "transparent"
            radius: 4
        }
    }

    indicator: GlyphIcon {
        x: control.width - width - 10
        y: control.topPadding + (control.availableHeight - height) / 2
        size: 12
        name: "chevron"
        rotation: 90
        color: Theme.textDim
    }

    contentItem: Text {
        text: control.displayText
        color: Theme.text
        font: control.font
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: control.pressed ? Theme.surfaceHi2
              : control.hovered ? Theme.surfaceHi : Theme.surface
        border.color: control.activeFocus ? Theme.accent
                     : control.hovered ? Theme.borderHi : Theme.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: contentItem.implicitHeight + 8
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            radius: Theme.radius
            color: Theme.surfaceHi
            border.color: Theme.borderHi
            border.width: 1
        }
    }
}
