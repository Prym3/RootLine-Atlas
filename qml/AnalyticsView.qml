import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    color: Theme.bg1

    property var stats: ({
        totalFiles: 0,
        totalSize: 0,
        byExt: [],
        bySizeBucket: [],
        largestFiles: [],
        largestFolders: []
    })

    onVisibleChanged: {
        if (visible && backend) {
            stats = backend.analyticsStats()
        }
    }

    onStatsChanged: {
        if (barCanvas) barCanvas.requestPaint()
        if (pieCanvas) pieCanvas.requestPaint()
    }

    Connections {
        target: backend
        function onTotalsChanged() {
            if (root.visible) {
                stats = backend.analyticsStats()
            }
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: parent.width
        contentHeight: contentCol.height

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 16

            RowLayout {
                width: parent.width
                spacing: 12

                Label {
                    text: "Analytics"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 80; height: 28; radius: 6
                    color: refreshMa.pressed ? Theme.surfaceHi2 : (refreshMa.containsMouse ? Theme.surfaceHi : "transparent")
                    border.color: Theme.border; border.width: 1
                    visible: refreshMa.containsMouse || refreshMa.pressed
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Label {
                        anchors.centerIn: parent
                        text: "Refresh"
                        color: Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: stats = backend.analyticsStats()
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 12

                Repeater {
                    model: [
                        { label: "Files", value: stats.totalFiles || 0, color: Theme.accent },
                        { label: "Total Size", value: stats.totalSizeText || "0 B", color: Theme.success },
                        { label: "Extensions", value: (stats.byExt ? stats.byExt.length : 0), color: Theme.warn },
                        { label: "Folders", value: (backend ? backend.totals.folders : 0), color: Theme.folder }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        radius: Theme.radius
                        color: Theme.surface
                        border.color: Theme.border; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Label {
                                text: modelData.value.toString()
                                color: modelData.color
                                font.family: Theme.fontMono
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: modelData.label
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 12
                Layout.preferredHeight: 320

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Label {
                            text: "Size Distribution"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Canvas {
                                id: barCanvas
                                anchors.fill: parent

                                Component.onCompleted: Qt.callLater(requestPaint)

                                onPaint: {
                                    var ctx = getContext("2d")
                                    var w = width, h = height
                                    ctx.clearRect(0, 0, w, h)

                                    var buckets = stats.bySizeBucket || []
                                    if (buckets.length === 0) {
                                        ctx.fillStyle = Theme.textFaint
                                        ctx.font = "12px sans-serif"
                                        ctx.textAlign = "center"
                                        ctx.textBaseline = "middle"
                                        ctx.fillText("No data", w/2, h/2)
                                        return
                                    }

                                    var maxCount = 0
                                    for (var i = 0; i < buckets.length; i++) {
                                        maxCount = Math.max(maxCount, buckets[i].count)
                                    }
                                    if (maxCount === 0) maxCount = 1

                                    var barW = (w - 30) / buckets.length
                                    var colors = [Theme.accent, Theme.success, Theme.warn, Theme.danger, Theme.folder, Theme.subfolder]

                                    for (i = 0; i < buckets.length; i++) {
                                        var bucket = buckets[i]
                                        var barH = (bucket.count / maxCount) * (h - 40)
                                        var x = 15 + i * barW + barW * 0.15
                                        var y = h - 25 - barH

                                        ctx.fillStyle = colors[i % colors.length]
                                        ctx.fillRect(x, y, barW * 0.7, barH)

                                        ctx.fillStyle = Theme.textDim
                                        ctx.font = "9px sans-serif"
                                        ctx.textAlign = "center"
                                        ctx.fillText(bucket.label, x + barW * 0.35, h - 8)

                                        if (barH > 18) {
                                            ctx.fillStyle = "#fff"
                                            ctx.fillText(bucket.count.toString(), x + barW * 0.35, y + 12)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Label {
                            text: "By Extension"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 140
                                Layout.alignment: Qt.AlignTop
                                color: "transparent"

                                Canvas {
                                    id: pieCanvas
                                    anchors.fill: parent

                                    Component.onCompleted: Qt.callLater(requestPaint)

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        var cx = width / 2, cy = height / 2
                                        var r = Math.min(cx, cy) - 8

                                        var exts = stats.byExt || []
                                        if (exts.length === 0) {
                                            ctx.fillStyle = Theme.text
                                            ctx.font = "12px sans-serif"
                                            ctx.textAlign = "center"
                                            ctx.textBaseline = "middle"
                                            ctx.fillText("No data", cx, cy)
                                            return
                                        }

                                        var total = 0
                                        for (var i = 0; i < exts.length; i++) total += exts[i].size
                                        if (total === 0) total = 1

                                        var start = -Math.PI / 2

                                        for (i = 0; i < exts.length && i < 8; i++) {
                                            var slice = (exts[i].size / total) * Math.PI * 2
                                            ctx.beginPath()
                                            ctx.moveTo(cx, cy)
                                            ctx.arc(cx, cy, r, start, start + slice)
                                            ctx.closePath()
                                            var extColor = exts[i].color
                                            ctx.fillStyle = (extColor && extColor.length > 0) ? extColor : "#888888"
                                            ctx.fill()
                                            start += slice
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4

                                property var displayedExts: stats.byExt ? stats.byExt.slice(0, 8) : []
                                property var displayedTotal: {
                                    var sum = 0
                                    for (var i = 0; i < displayedExts.length; i++) {
                                        sum += displayedExts[i].size
                                    }
                                    return sum || 1
                                }

                                Repeater {
                                    model: parent.displayedExts
                                    RowLayout {
                                        width: parent.width
                                        spacing: 8
                                        Rectangle {
                                            width: 8; height: 8; radius: 2
                                            color: modelData.color ? modelData.color : "#888888"
                                        }
                                        Label {
                                            text: modelData.ext || "(none)"
                                            color: Theme.textDim
                                            font.family: Theme.fontFamily; font.pixelSize: 10
                                            Layout.preferredWidth: 50
                                        }
                                        Label {
                                            text: Math.round((modelData.size / parent.parent.displayedTotal) * 100) + "%"
                                            color: Theme.text
                                            font.family: Theme.fontMono; font.pixelSize: 10
                                        }
                                        Item { Layout.fillWidth: true }
                                        Label {
                                            text: modelData.sizeText
                                            color: Theme.text
                                            font.family: Theme.fontMono; font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 12
                Layout.preferredHeight: 220

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Label {
                            text: "Largest Files"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                anchors.fill: parent
                                clip: true
                                model: stats.largestFiles || []
                                spacing: 4
                                visible: stats.largestFiles.length > 0

                                delegate: RowLayout {
                                    width: ListView.view.width
                                    spacing: 8
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        color: Theme.accent
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: Theme.text
                                        font.family: Theme.fontFamily; font.pixelSize: 10
                                        elide: Text.ElideMiddle
                                    }
                                    Label {
                                        text: modelData.sizeText
                                        color: Theme.textDim
                                        font.family: Theme.fontMono; font.pixelSize: 10
                                    }
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: "No data available"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                visible: stats.largestFiles.length === 0
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Label {
                            text: "Largest Folders"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                anchors.fill: parent
                                clip: true
                                model: stats.largestFolders || []
                                spacing: 4
                                visible: stats.largestFolders.length > 0

                                delegate: RowLayout {
                                    width: ListView.view.width
                                    spacing: 8
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        color: Theme.folder
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: Theme.text
                                        font.family: Theme.fontFamily; font.pixelSize: 10
                                        elide: Text.ElideMiddle
                                    }
                                    Label {
                                        text: modelData.sizeText
                                        color: Theme.textDim
                                        font.family: Theme.fontMono; font.pixelSize: 10
                                    }
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: "No data available"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                visible: stats.largestFolders.length === 0
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
