import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Popup {
    id: dlg
    modal: true
    anchors.centerIn: parent
    width: 680
    height: 540
    padding: 0
    closePolicy: Popup.NoAutoClose

    property var originalNames: []
    property var fullPaths: []

    property var pairs: []

    function openWith(names, paths) {
        originalNames = names.slice()
        fullPaths = (paths && paths.length === names.length) ? paths.slice() : []
        _buildPairs()
        _applyTransform()
        dlg.open()
    }

    function _refreshStart() {
        var mode = numberModeCombo.currentIndex
        if (mode === 1) {
            startField.text = backend.nextBulkRenameStart("normal", "").toString()
        } else if (mode === 2) {
            startField.text = backend.nextBulkRenameStart("decimal", decFirstField.text).toString()
        }
    }

    function _buildPairs() {
        var p = []
        for (var i = 0; i < originalNames.length; i++) {
            p.push({ "from": originalNames[i], "to": originalNames[i] })
        }
        pairs = p
    }

    function _applyTransform() {
        var find     = findField.text
        var replace  = replaceField.text
        var prefix   = prefixField.text
        var suffix   = suffixField.text
        var numMode  = numberModeCombo.currentIndex
        var start    = parseInt(startField.text)  || 1
        var pad      = parseInt(padField.text)    || 1
        var sep      = sepField.text
        var decFirst = parseInt(decFirstField.text) || 1

        var newPairs = []
        for (var i = 0; i < originalNames.length; i++) {
            var orig = originalNames[i]
            var dot  = orig.lastIndexOf(".")
            var stem = dot > 0 ? orig.substring(0, dot) : orig
            var ext  = dot > 0 ? orig.substring(dot)   : ""

            var newStem = stem
            if (find.length > 0) {
                try {
                    var re = new RegExp(find.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), "gi")
                    newStem = newStem.replace(re, replace)
                } catch(e) {}
            }

            var newName
            if (numMode === 1) {
                var n = (start + i).toString()
                while (n.length < pad) n = "0" + n
                newName = n + ext
            } else if (numMode === 2) {
                newName = decFirst + "." + (start + i) + ext
            } else if (numMode === 3) {
                newName = orig + "." + (start + i)
            } else {
                newName = prefix + newStem + suffix + ext
            }

            newPairs.push({ "from": orig, "to": newName })
        }
        pairs = newPairs
        previewModel.reload()
    }

    onOpened: {
        findField.text               = ""
        replaceField.text            = ""
        prefixField.text             = ""
        suffixField.text             = ""
        numberModeCombo.currentIndex = 0
        startField.text              = "1"
        padField.text                = "1"
        sepField.text                = "_"
        decFirstField.text           = "1"
        _applyTransform()
    }

    Overlay.modal: Rectangle { color: Qt.rgba(0,0,0,0.6) }

    background: Rectangle {
        color: Theme.surface
        radius: 14
        border.color: Theme.borderHi
        border.width: 1
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic } }
    exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140; easing.type: Easing.InCubic } }

    ListModel {
        id: previewModel
        function reload() {
            previewModel.clear()
            for (var i = 0; i < dlg.pairs.length; i++) {
                var fp = (dlg.fullPaths.length > i) ? dlg.fullPaths[i] : ""
                previewModel.append({ "fromName": dlg.pairs[i]["from"], "toName": dlg.pairs[i]["to"], "fullPath": fp })
            }
        }
    }

    Popup {
        id: thumbPopup
        modal: false
        dim: false
        closePolicy: Popup.NoAutoClose
        padding: 4
        width: 220; height: 220
        property string thumbUrl: ""
        background: Rectangle { color: Theme.surface; radius: 10; border.color: Theme.borderHi; border.width: 1 }
        Image {
            anchors.fill: parent
            anchors.margins: 4
            source: thumbPopup.thumbUrl
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    Popup {
        id: lightbox
        modal: true
        parent: Overlay.overlay
        x: 24; y: 24
        width: Overlay.overlay ? Overlay.overlay.width - 48 : 800
        height: Overlay.overlay ? Overlay.overlay.height - 48 : 600
        padding: 0
        closePolicy: Popup.NoAutoClose
        property string thumbUrl: ""

        Overlay.modal: Rectangle { color: Qt.rgba(0,0,0,0.82) }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale";   from: 0.92; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130; easing.type: Easing.InCubic }
        }

        background: Rectangle {
            color: "#0d0d0d"
            radius: 16
            border.color: Theme.borderHi
            border.width: 1
        }

        Image {
            anchors.fill: parent
            anchors.margins: 16
            source: lightbox.thumbUrl
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: lightbox.close()
        }

        Label {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 12
            text: "Click to close"
            color: "#666666"
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24; Layout.rightMargin: 16
            Layout.topMargin: 20; Layout.bottomMargin: 14
            spacing: 10
            Label {
                text: "Bulk Rename"
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Label {
                text: dlg.originalNames.length + " items"
                color: Theme.textDim
                font.family: Theme.fontFamily; font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 28; height: 28; radius: 7
                color: closeMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                Label { anchors.centerIn: parent; text: "✕"; color: Theme.textDim; font.pixelSize: 13 }
                MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dlg.close() }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20; Layout.rightMargin: 20
            Layout.topMargin: 14; Layout.bottomMargin: 10
            columns: 6
            columnSpacing: 10
            rowSpacing: 8

            Label { text: "Find"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
            TextField {
                id: findField
                Layout.columnSpan: 2; Layout.fillWidth: true
                placeholderText: "text to find…"
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1 }
                onTextChanged: dlg._applyTransform()
            }
            Label { text: "Replace"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
            TextField {
                id: replaceField
                Layout.columnSpan: 2; Layout.fillWidth: true
                placeholderText: "replacement…"
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1 }
                onTextChanged: dlg._applyTransform()
            }

            Label { text: "Prefix"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
            TextField {
                id: prefixField
                Layout.columnSpan: 2; Layout.fillWidth: true
                placeholderText: "add before name…"
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1 }
                onTextChanged: dlg._applyTransform()
            }
            Label { text: "Suffix"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
            TextField {
                id: suffixField
                Layout.columnSpan: 2; Layout.fillWidth: true
                placeholderText: "add before extension…"
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1 }
                onTextChanged: dlg._applyTransform()
            }

            Label { text: "Numbering"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
            ModernCombo {
                id: numberModeCombo
                Layout.columnSpan: 2; Layout.fillWidth: true
                model: ["None", "Normal  (name_1)", "Decimal  (1.1 name)", "Append  (name.1)"]
                currentIndex: 0
                onCurrentIndexChanged: { dlg._refreshStart(); dlg._applyTransform() }
            }
            Label {
                text: numberModeCombo.currentIndex === 3 ? "Start" : "Start"
                color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                opacity: numberModeCombo.currentIndex > 0 ? 1 : 0.3
            }
            TextField {
                id: startField; text: "1"
                Layout.preferredWidth: 48
                enabled: numberModeCombo.currentIndex > 0
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1; opacity: numberModeCombo.currentIndex > 0 ? 1 : 0.4 }
                onTextChanged: dlg._applyTransform()
            }
            RowLayout {
                spacing: 6
                opacity: numberModeCombo.currentIndex === 1 ? 1 : 0.3
                Label { text: "Pad"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
                TextField {
                    id: padField; text: "1"
                    Layout.preferredWidth: 32
                    enabled: numberModeCombo.currentIndex === 1
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                    background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1 }
                    onTextChanged: dlg._applyTransform()
                }
                Label { text: "Sep"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
                TextField {
                    id: sepField; text: "_"
                    Layout.preferredWidth: 32
                    enabled: numberModeCombo.currentIndex === 1
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                    background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1 }
                    onTextChanged: dlg._applyTransform()
                }
                Label {
                    visible: numberModeCombo.currentIndex === 2
                    text: "First №"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                }
                TextField {
                    id: decFirstField; text: "1"
                    visible: numberModeCombo.currentIndex === 2
                    Layout.preferredWidth: 36
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                    background: Rectangle { color: Theme.surfaceHi; radius: 6; border.color: parent.activeFocus ? Theme.accent : Theme.border; border.width: 1 }
                    onTextChanged: { dlg._refreshStart(); dlg._applyTransform() }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            Layout.topMargin: 8; Layout.bottomMargin: 6
            spacing: 0
            Label { Layout.fillWidth: true; text: "Original name"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold }
            Item { width: 24 }
            Label { Layout.fillWidth: true; text: "New name (editable)"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold }
        }

        ListView {
            id: previewList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 8; Layout.rightMargin: 8
            clip: true
            model: previewModel
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 5; radius: 2; color: Theme.borderHi }
            }

            delegate: RowLayout {
                width: previewList.width - 8
                height: 34
                spacing: 0

                property string rowThumbUrl: ""
                property bool rowIsMedia: fullPath !== "" && (function() {
                    var n = fromName.toLowerCase()
                    var imgExts = [".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".tif",".heic",".heif"]
                    var vidExts = [".mp4",".mkv",".avi",".mov",".wmv",".flv",".webm",".m4v",".mpg",".mpeg"]
                    for (var e of imgExts) if (n.endsWith(e)) return true
                    for (var e of vidExts) if (n.endsWith(e)) return true
                    return false
                })()

                Component.onCompleted: {
                    if (rowIsMedia && fullPath) {
                        var url = thumbnailCache.get(fullPath)
                        if (!url) url = videoThumbnailCache.get(fullPath)
                        if (url) rowThumbUrl = url
                    }
                }

                Connections {
                    target: thumbnailCache
                    function onThumbnailReady(path, url) {
                        if (path === fullPath) rowThumbUrl = url
                    }
                }
                Connections {
                    target: videoThumbnailCache
                    function onThumbnailReady(path, url) {
                        if (path === fullPath) rowThumbUrl = url
                    }
                }

                Rectangle {
                    width: 28; height: 28; radius: 5
                    color: thumbHoverMa.containsMouse && rowIsMedia ? Qt.rgba(1,1,1,0.08) : "transparent"

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: rowThumbUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: rowThumbUrl !== ""
                    }
                    GlyphIcon {
                        anchors.centerIn: parent
                        name: "image"; size: 13
                        color: Theme.textFaint
                        visible: rowIsMedia && rowThumbUrl === ""
                    }
                    MouseArea {
                        id: thumbHoverMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: rowThumbUrl !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: {
                            if (rowThumbUrl !== "") {
                                thumbPopup.thumbUrl = rowThumbUrl
                                var gp = thumbHoverMa.mapToItem(null, 0, 0)
                                thumbPopup.x = Math.min(gp.x + 32, dlg.width - thumbPopup.width - 8)
                                thumbPopup.y = Math.max(4, Math.min(gp.y - thumbPopup.height / 2, dlg.height - thumbPopup.height - 4))
                                thumbPopup.open()
                            }
                        }
                        onExited: thumbPopup.close()
                        onClicked: {
                            if (rowThumbUrl !== "") {
                                thumbPopup.close()
                                lightbox.thumbUrl = rowThumbUrl
                                lightbox.open()
                            }
                        }
                    }
                }
                Item { width: 4 }

                Rectangle {
                    Layout.fillWidth: true; height: 28; radius: 6
                    color: Qt.rgba(1,1,1,0.03)
                    Label {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        text: fromName
                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }
                }

                Label {
                    width: 24; horizontalAlignment: Text.AlignHCenter
                    text: "→"
                    color: toNameField.text !== fromName ? Theme.accent : Theme.textFaint
                    font.pixelSize: 13
                }

                Rectangle {
                    Layout.fillWidth: true; height: 28; radius: 6
                    color: toNameField.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06) : Qt.rgba(1,1,1,0.03)
                    border.color: toNameField.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent"
                    border.width: 1

                    TextField {
                        id: toNameField
                        anchors.fill: parent
                        anchors.margins: 1
                        text: toName
                        color: toName !== fromName ? Theme.text : Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: 12
                        background: Item {}
                        selectByMouse: true
                        onEditingFinished: {
                            previewModel.setProperty(index, "toName", text)
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            Layout.topMargin: 12; Layout.bottomMargin: 16
            spacing: 8

            Rectangle {
                width: 70; height: 32; radius: 8
                color: resetMa.pressed ? Qt.rgba(1,1,1,0.10) : resetMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                border.color: Theme.border; border.width: 1
                Label { anchors.centerIn: parent; text: "Reset"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12 }
                MouseArea {
                    id: resetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { dlg._buildPairs(); dlg._applyTransform() }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 70; height: 32; radius: 8
                color: cancelMa.pressed ? Qt.rgba(1,1,1,0.10) : cancelMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                border.color: Theme.border; border.width: 1
                Label { anchors.centerIn: parent; text: "Cancel"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12 }
                MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dlg.close() }
            }

            Rectangle {
                width: 70; height: 32; radius: 8
                color: applyMa.pressed   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                     : applyMa.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                     :                         Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, applyMa.containsMouse ? 0.7 : 0.4)
                border.width: 1
                Label { anchors.centerIn: parent; text: "Apply"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12 }
                MouseArea {
                    id: applyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var finalPairs = []
                        for (var i = 0; i < previewModel.count; i++) {
                            var item = previewModel.get(i)
                            if (item.toName && item.toName !== item.fromName) {
                                finalPairs.push({ "from": item.fromName, "to": item.toName })
                            }
                        }
                        if (finalPairs.length > 0) backend.bulkRename(finalPairs)
                        dlg.close()
                    }
                }
            }
        }
    }
}
