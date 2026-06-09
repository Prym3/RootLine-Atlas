import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    property var options: []
    property string currentKey: ""
    signal selected(string key)

    implicitHeight: 34
    implicitWidth: row.implicitWidth + 8
    radius: Theme.radiusSm
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    Rectangle {
        id: pill
        height: parent.height - 8
        y: 4
        radius: Theme.radiusSm - 2
        color: Theme.accent
        property int idx: {
            for (var i = 0; i < root.options.length; i++)
                if (root.options[i].key === root.currentKey) return i
            return 0
        }
        x: 4 + idx * (root.options.length > 0 ? (root.width - 8) / root.options.length : 0)
        width: root.options.length > 0 ? (root.width - 8) / root.options.length : 0
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0
        Repeater {
            model: root.options
            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: modelData.key === root.currentKey ? "#ffffff" : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: modelData.key === root.currentKey ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.selected(modelData.key)
                }
            }
        }
    }
}
