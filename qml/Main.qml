import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs
import "."

ApplicationWindow {
    id: window
    width: 1320
    height: 820
    minimumWidth: 960
    minimumHeight: 620
    visible: true
    title: (backend && backend.path && backend.path.length > 0)
           ? "Rootline Atlas — " + backend.path
           : "Rootline Atlas"
    color: Theme.bg0

    opacity: 0
    NumberAnimation { id: fadeInAnim; target: window; property: "opacity"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }

    property string pendingScrollRestorePath: ""

    Connections {
        target: backend
        function onMessagePosted(message, level) { toast.show(message, level) }
        function onPathChanged() { tabBar.updateCurrentTabPath(backend.path) }
        function onPasteConflictsDetected(conflicts) {
            pasteConflictDialog.conflictsList = conflicts
            pasteConflictDialog.currentConflictIndex = 0
            applyAllCheck.checked = false
            pasteConflictDialog.open()
        }
        function onPasteStarted()  { pasteProgressDialog.open()  }
        function onPasteFinished() { pasteProgressDialog.close() }
        function onRenameConflictDetected(oldName, newName, suggestedName) {
            renameConflictDialog.oldName = oldName
            renameConflictDialog.newName = newName
            renameConflictDialog.suggestedName = suggestedName
            renameConflictDialog.open()
        }
        function onTotalsChanged() {
            if (pendingScrollRestorePath && backend && backend.path === pendingScrollRestorePath) {
                if (resultsView) {
                    resultsView.restoreScrollPosition(pendingScrollRestorePath)
                }
                pendingScrollRestorePath = ""
            }
        }
    }

    Rectangle {
        id: chromeBg
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 96
        color: Theme.bg0

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.divider
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 12
            anchors.bottomMargin: 0
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 6

                RowLayout {
                    spacing: 10
                    Layout.rightMargin: 8
                    Rectangle {
                        width: 32; height: 32; radius: 9
                        color: Theme.accent
                        GlyphIcon { anchors.centerIn: parent; name: "folderFill"; size: 16; color: "#ffffff" }
                    }
                    ColumnLayout {
                        spacing: -2
                        Label {
                            text: "Scanner"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: "v2.0"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                Rectangle { width: 1; Layout.preferredHeight: 24; color: Theme.divider; Layout.rightMargin: 4 }

                IconButton { iconName: "back";    tip: "Back";    enabled: backend ? backend.canGoBack    : false; onClicked: backend.goBack() }
                IconButton { iconName: "forward"; tip: "Forward"; enabled: backend ? backend.canGoForward : false; onClicked: backend.goForward() }
                Item {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                    IconButton {
                        anchors.fill: parent
                        iconName: "up";      tip: "Parent";  enabled: backend ? backend.path.length > 0 : false; onClicked: backend.goUp()
                    }
                    DropArea {
                        anchors.fill: parent
                        enabled: backend ? backend.path.length > 0 : false
                        onDropped: function(drop) {
                            if (drop.hasUrls && backend) {
                                var p = backend.path.replace(/\\/g, "/")
                                if (p.endsWith("/")) p = p.slice(0, -1)
                                var lastSlash = p.lastIndexOf("/")
                                if (lastSlash >= 0) {
                                    var parentPath = p.slice(0, lastSlash)
                                    if (parentPath.length === 0 || parentPath.endsWith(":")) parentPath += "/"
                                    backend.handleDrop(drop.urls, parentPath, drop.proposedAction)
                                    drop.accept()
                                }
                            }
                        }
                    }
                }
                IconButton {
                    iconName: (backend && backend.busy) ? "stop" : "reload"
                    tip:      (backend && backend.busy) ? "Cancel scan" : "Reload"
                    enabled:  backend ? backend.path.length > 0 : false
                    onClicked: (backend && backend.busy) ? backend.cancelScan() : backend.reload()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    radius: 19
                    color: addressField.activeFocus ? Theme.surfaceHi : Theme.surface
                    border.color: addressField.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.color: Qt.rgba(0.49, 0.36, 1.0, 0.25)
                        border.width: 1
                        visible: addressField.activeFocus
                        z: -1
                    }

                    DropArea {
                        anchors.fill: parent
                        onDropped: function(drop) {
                            if (drop.hasUrls && drop.urls.length > 0 && backend) {
                                var path = backend.localPathFromUrl(drop.urls[0])
                                if (path) {
                                    navigateSafe(path)
                                }
                                drop.accept()
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 80
                            spacing: 8
                            GlyphIcon { name: "search"; size: 14; color: Theme.textFaint }
                            TextField {
                                id: addressField
                                Layout.fillWidth: true
                                placeholderText: "Enter directory path…  (Ctrl+L)"
                                placeholderTextColor: Theme.textFaint
                                text: backend ? backend.path : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                background: null
                                selectByMouse: true
                                selectionColor: Theme.accent
                                selectedTextColor: "#ffffff"
                                onAccepted: navigateSafe(text)
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: browseRow.implicitWidth + 18
                            height: 28; radius: 14
                            color: browseMouse.pressed
                                   ? Qt.rgba(0.49,0.36,1.00,0.28)
                                   : browseMouse.containsMouse
                                     ? Qt.rgba(0.49,0.36,1.00,0.18)
                                     : Qt.rgba(0.49,0.36,1.00,0.10)
                            border.color: Qt.rgba(0.49,0.36,1.00, browseMouse.containsMouse ? 0.55 : 0.30)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 110 } }
                            Row {
                                id: browseRow
                                anchors.centerIn: parent
                                spacing: 5
                                GlyphIcon { name: "folder"; size: 12; color: Theme.accent }
                                Text {
                                    text: "Browse"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                            MouseArea {
                                id: browseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: folderDialog.open()
                            }
                        }
                    }
                }

                SegmentedControl {
                    id: viewSeg
                    Layout.preferredWidth: 300
                    options: [{key:"list", label:"List"}, {key:"tree", label:"Tree"}, {key:"grid", label:"Grid"}, {key:"analytics", label:"Stats"}]
                    currentKey: backend ? backend.viewMode : "list"
                    onSelected: function(k) {
                        if (!backend) return
                        backend.viewMode = k
                        if (k !== "analytics" && backend.path.length) backend.scan()
                    }
                }

                Rectangle { width: 1; Layout.preferredHeight: 24; color: Theme.divider; Layout.leftMargin: 4 }

                IconButton {
                    iconName: "download"
                    tip: "Export results"
                    enabled: backend ? (backend.path.length > 0 && !backend.busy) : false
                    onClicked: exportDialog.open()
                }
                IconButton {
                    iconName: "eye"
                    tip: "View exported file"
                    onClicked: viewExportDialog.open()
                }
                Rectangle { width: 1; Layout.preferredHeight: 24; color: Theme.divider; Layout.leftMargin: 4 }
                IconButton {
                    iconName: "folderPlus"
                    tip: "New folder (Ctrl+Shift+N)"
                    enabled: backend ? (backend.path.length > 0 && !backend.busy) : false
                    onClicked: newFolderDialog.open()
                }
                Rectangle { width: 1; Layout.preferredHeight: 24; color: Theme.divider; Layout.leftMargin: 4 }
                IconButton {
                    iconName: "undo"
                    tip: "Undo (Ctrl+Z)"
                    enabled: backend ? backend.canUndo : false
                    onClicked: backend.undo()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 8
                color: Theme.surface
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 0

                    ListModel { id: drivesModel }

                    Connections {
                        target: backend
                        function onAvailableDrivesChanged() { drivesSync.sync() }
                    }

                    Item {
                        id: drivesSync
                        property bool ready: false
                        Component.onCompleted: {
                            var initial = (backend && backend.availableDrives) ? backend.availableDrives : []
                            for (var i = 0; i < initial.length; i++) {
                                drivesModel.append({ drive: initial[i], isNew: false, removing: false })
                            }
                            ready = true
                        }
                        function sync() {
                            if (!backend) return
                            var current = backend.availableDrives || []
                            for (var i = 0; i < current.length; i++) {
                                var found = false
                                for (var j = 0; j < drivesModel.count; j++) {
                                    if (drivesModel.get(j).drive === current[i]) { found = true; break }
                                }
                                if (!found) {
                                    var insertAt = drivesModel.count
                                    var seen = 0
                                    for (var k = 0; k < drivesModel.count; k++) {
                                        if (drivesModel.get(k).removing) continue
                                        if (seen === i) { insertAt = k; break }
                                        seen++
                                    }
                                    drivesModel.insert(insertAt, { drive: current[i], isNew: true, removing: false })
                                }
                            }
                            for (var m = 0; m < drivesModel.count; m++) {
                                var d = drivesModel.get(m)
                                if (d.removing) continue
                                if (current.indexOf(d.drive) < 0) {
                                    drivesModel.setProperty(m, "removing", true)
                                }
                            }
                        }
                        function finalizeRemove(drive) {
                            for (var i = 0; i < drivesModel.count; i++) {
                                if (drivesModel.get(i).drive === drive && drivesModel.get(i).removing) {
                                    drivesModel.remove(i)
                                    return
                                }
                            }
                        }
                    }

                    Repeater {
                        id: drivesRepeater
                        model: drivesModel
                        delegate: Rectangle {
                            id: driveChip
                            Layout.alignment: Qt.AlignVCenter
                            readonly property int targetWidth: driveLabel.implicitWidth + 18
                            Layout.preferredWidth: model.isNew ? 0 : targetWidth
                            height: 22
                            radius: 6
                            opacity: model.isNew ? 0 : 1
                            clip: true
                            property bool isActive: backend && backend.path && backend.path.toLowerCase().startsWith(model.drive.toLowerCase())
                            color: isActive
                                   ? Qt.rgba(0.49, 0.36, 1.0, 0.18)
                                   : (driveChipMouse.containsMouse ? Theme.surfaceHi : "transparent")
                            Behavior on color { ColorAnimation { duration: 110 } }

                            SequentialAnimation {
                                id: appearAnim
                                running: model.isNew
                                NumberAnimation {
                                    target: driveChip; property: "Layout.preferredWidth"
                                    from: 0; to: driveChip.targetWidth
                                    duration: 260; easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: driveChip; property: "opacity"
                                    from: 0; to: 1
                                    duration: 220; easing.type: Easing.OutCubic
                                }
                            }

                            SequentialAnimation {
                                id: disappearAnim
                                running: model.removing
                                NumberAnimation {
                                    target: driveChip; property: "opacity"
                                    to: 0; duration: 220; easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    target: driveChip; property: "Layout.preferredWidth"
                                    to: 0; duration: 260; easing.type: Easing.InCubic
                                }
                                ScriptAction { script: drivesSync.finalizeRemove(model.drive) }
                            }

                            Text {
                                id: driveLabel
                                anchors.centerIn: parent
                                text: model.drive ? model.drive.substring(0, 2) : ""
                                color: driveChip.isActive ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: driveChip.isActive ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: driveChipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !model.removing
                                onClicked: navigateSafe(model.drive)
                            }
                        }
                    }

                    Text {
                        visible: backend && backend.availableDrives && backend.availableDrives.length > 0 && backend.path && backend.path.length > 0
                        text: "›"
                        color: Theme.textFaint
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 2
                        rightPadding: 2
                    }

                    Flickable {
                        id: crumbsFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: crumbRow.implicitWidth
                        contentHeight: height
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        ListModel { id: crumbsModel }

                        Connections {
                            target: backend
                            function onPathChanged() { crumbsSync.sync() }
                        }

                        Item {
                            id: crumbsSync
                            visible: false
                            property bool ready: false

                            function computeCrumbs() {
                                if (!backend || !backend.path) return []
                                var sep = backend.path.indexOf("\\") >= 0 ? "\\" : "/"
                                var parts = backend.path.split(sep).filter(function(p){ return p.length > 0 })
                                var acc = []
                                var cum = ""
                                for (var i = 0; i < parts.length; i++) {
                                    if (i === 0 && backend.path.startsWith("/")) cum = "/" + parts[i]
                                    else if (i === 0) cum = parts[i]
                                    else cum = cum + sep + parts[i]
                                    acc.push({ label: parts[i], full: cum, last: i === parts.length - 1 })
                                }
                                return acc
                            }

                            Component.onCompleted: {
                                var initial = computeCrumbs()
                                for (var i = 0; i < initial.length; i++) {
                                    crumbsModel.append({
                                        label: initial[i].label,
                                        full: initial[i].full,
                                        last: initial[i].last,
                                        isNew: false,
                                        removing: false
                                    })
                                }
                                ready = true
                            }

                            function sync() {
                                if (!ready) return
                                var target = computeCrumbs()
                                var existing = {}
                                for (var i = 0; i < crumbsModel.count; i++) {
                                    var e = crumbsModel.get(i)
                                    if (!e.removing) existing[e.full] = i
                                }
                                var targetSet = {}
                                for (var k = 0; k < target.length; k++) targetSet[target[k].full] = true

                                for (var m = 0; m < crumbsModel.count; m++) {
                                    var c = crumbsModel.get(m)
                                    if (c.removing) continue
                                    if (!targetSet[c.full]) {
                                        crumbsModel.setProperty(m, "last", false)
                                        crumbsModel.setProperty(m, "removing", true)
                                    }
                                }

                                for (var t = 0; t < target.length; t++) {
                                    var item = target[t]
                                    if (item.full in existing) {
                                        var idx = existing[item.full]
                                        if (crumbsModel.get(idx).last !== item.last) {
                                            crumbsModel.setProperty(idx, "last", item.last)
                                        }
                                    } else {
                                        var insertAt = crumbsModel.count
                                        var seen = 0
                                        for (var z = 0; z < crumbsModel.count; z++) {
                                            if (crumbsModel.get(z).removing) continue
                                            if (seen === t) { insertAt = z; break }
                                            seen++
                                        }
                                        crumbsModel.insert(insertAt, {
                                            label: item.label,
                                            full: item.full,
                                            last: item.last,
                                            isNew: true,
                                            removing: false
                                        })
                                    }
                                }

                                Qt.callLater(function() {
                                    if (crumbsFlickable.contentWidth > crumbsFlickable.width) {
                                        crumbsFlickable.contentX = crumbsFlickable.contentWidth - crumbsFlickable.width
                                    } else {
                                        crumbsFlickable.contentX = 0
                                    }
                                })
                            }

                            function finalizeRemove(fullPath) {
                                for (var i = 0; i < crumbsModel.count; i++) {
                                    var c = crumbsModel.get(i)
                                    if (c.full === fullPath && c.removing) {
                                        crumbsModel.remove(i)
                                        return
                                    }
                                }
                            }
                        }

                        Row {
                            id: crumbRow
                            spacing: 0
                            height: parent.height

                            Repeater {
                                model: crumbsModel
                                delegate: Item {
                                    id: crumb
                                    height: crumbRow.height
                                    readonly property real targetWidth: (index > 0 ? sepText.implicitWidth + sepText.leftPadding + sepText.rightPadding : 0)
                                                                        + chipRect.implicitWidth
                                    width: model.isNew ? 0 : targetWidth
                                    opacity: model.isNew ? 0 : 1
                                    clip: true

                                    SequentialAnimation {
                                        id: crumbAppear
                                        running: model.isNew
                                        NumberAnimation {
                                            target: crumb; property: "width"
                                            from: 0; to: crumb.targetWidth
                                            duration: 220; easing.type: Easing.OutCubic
                                        }
                                        NumberAnimation {
                                            target: crumb; property: "opacity"
                                            from: 0; to: 1
                                            duration: 180; easing.type: Easing.OutCubic
                                        }
                                    }

                                    SequentialAnimation {
                                        id: crumbDisappear
                                        running: model.removing
                                        NumberAnimation {
                                            target: crumb; property: "opacity"
                                            to: 0; duration: 160; easing.type: Easing.InCubic
                                        }
                                        NumberAnimation {
                                            target: crumb; property: "width"
                                            to: 0; duration: 200; easing.type: Easing.InCubic
                                        }
                                        ScriptAction { script: crumbsSync.finalizeRemove(model.full) }
                                    }

                                    Row {
                                        anchors.fill: parent
                                        spacing: 0

                                        Text {
                                            id: sepText
                                            visible: index > 0
                                            text: "/"
                                            color: Theme.textFaint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 0
                                            rightPadding: 0
                                            opacity: 0.5
                                        }

                                        Rectangle {
                                            id: chipRect
                                            implicitWidth: crumbText.implicitWidth + 10
                                            height: parent.height - 6
                                            y: 3
                                            radius: 6
                                            color: model.last
                                                   ? Qt.rgba(0.49, 0.36, 1.0, crumbMouse.containsMouse ? 0.20 : 0.12)
                                                   : (crumbMouse.containsMouse ? Theme.surfaceHi : "transparent")
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                id: crumbText
                                                anchors.centerIn: parent
                                                text: model.label
                                                color: model.last ? Theme.accent : (crumbMouse.containsMouse ? Theme.text : Theme.textDim)
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: model.last ? Font.DemiBold : Font.Normal
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }

                                            MouseArea {
                                                id: crumbMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !model.removing
                                                onClicked: navigateSafe(model.full)
                                            }

                                            DropArea {
                                                anchors.fill: parent
                                                enabled: !model.removing
                                                onDropped: function(drop) {
                                                    if (drop.hasUrls && backend) {
                                                        backend.handleDrop(drop.urls, model.full, drop.proposedAction)
                                                        drop.accept()
                                                    }
                                                }
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: Theme.accent
                                                    opacity: parent.containsDrag ? 0.2 : 0
                                                    radius: 6
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: searchField
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: searchInput.activeFocus || searchInput.text.length > 0 ? 220 : 160
                        Layout.preferredHeight: 22
                        Layout.leftMargin: 6
                        radius: 6
                        color: searchInput.activeFocus || searchInput.text.length > 0 ? Theme.bg1 : Qt.rgba(1,1,1,0.04)
                        border.color: searchInput.activeFocus || searchInput.text.length > 0 ? Theme.accent : Theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 4
                            spacing: 5

                            GlyphIcon {
                                name: "search"
                                size: 11
                                color: searchInput.activeFocus ? Theme.accent : Theme.textFaint
                            }
                            TextField {
                                id: searchInput
                                Layout.fillWidth: true
                                placeholderText: backend && backend.path
                                                 ? "Search " + (function() {
                                                       var p = backend.path.replace(/\\/g, "/")
                                                       var parts = p.split("/").filter(function(s){ return s.length > 0 })
                                                       return parts[parts.length - 1] || backend.path
                                                   })()
                                                 : "Search in folder…"
                                placeholderTextColor: Theme.textFaint
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                background: null
                                selectByMouse: true
                                selectionColor: Theme.accent
                                selectedTextColor: "#ffffff"
                                text: backend ? backend.searchText : ""
                                onTextChanged: searchDebounce.restart()
                                Keys.onEscapePressed: {
                                    if (text.length > 0) text = ""
                                    else focus = false
                                }
                                Connections {
                                    target: backend
                                    function onSearchTextChanged() {
                                        if (searchInput.text !== backend.searchText)
                                            searchInput.text = backend.searchText
                                    }
                                }
                                Timer {
                                    id: searchDebounce
                                    interval: 500
                                    onTriggered: {
                                        if (backend && backend.searchText !== searchInput.text)
                                            backend.searchText = searchInput.text
                                    }
                                }
                            }
                            Rectangle {
                                width: 14; height: 14; radius: 7
                                Layout.alignment: Qt.AlignVCenter
                                visible: searchInput.text.length > 0
                                color: clearMa.containsMouse ? Theme.surfaceHi : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: Theme.textFaint
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    id: clearMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }
    }

    Rectangle {
        id: tabBar
        anchors {
            left: parent.left
            right: parent.right
            top: chromeBg.bottom
        }
        height: 36
        color: Theme.bg0
        visible: true
        property bool newTabOpening: false

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.divider
        }

        Flickable {
            id: tabsFlickable
            anchors {
                left: parent.left
                right: addTabBtn.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: 8
                rightMargin: 4
            }
            contentWidth: tabsRow.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: tabsRow
                spacing: 3
                height: tabsFlickable.height

                move: Transition {
                    NumberAnimation {
                        properties: "x"
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    id: tabsRepeater
                    model: ListModel { id: tabsModel }
                    delegate: Rectangle {
                        id: tab
                        readonly property real targetWidth: model.pinned
                                                            ? 44
                                                            : Math.min(tabLabelText.implicitWidth + 52, 200)
                        property bool isDragging: false
                        width: model.isNew ? 0 : targetWidth
                        height: tabsRow.height - 6
                        y: 3
                        opacity: model.isNew ? 0 : 1
                        clip: false
                        z: isDragging ? 5 : 0
                        scale: isDragging ? 1.05 : 1.0
                        color: isDragging
                               ? Theme.surfaceHi
                               : (model.active ? Theme.surface : (tabMouse.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"))
                        radius: 6
                        border.color: isDragging
                                      ? Theme.accent
                                      : (model.active
                                         ? (model.tabColor && model.tabColor.length > 0 ? model.tabColor : Theme.borderHi)
                                         : "transparent")
                        border.width: isDragging ? 2 : 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on width {
                            enabled: !model.isNew && !model.removing
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: parent.radius + 2
                            color: "transparent"
                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                            border.width: 1
                            visible: tab.isDragging
                            z: -1
                        }

                        Rectangle {
                            anchors {
                                left: parent.left; right: parent.right
                                bottom: parent.bottom
                                leftMargin: 4; rightMargin: 4; bottomMargin: 1
                            }
                            height: 2; radius: 1
                            visible: model.tabColor && model.tabColor.length > 0
                            color: model.tabColor || "transparent"
                        }

                        SequentialAnimation {
                            id: tabAppearAnim
                            running: model.isNew
                            NumberAnimation {
                                target: tab; property: "width"
                                from: 0; to: tab.targetWidth
                                duration: 220; easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: tab; property: "opacity"
                                from: 0; to: 1
                                duration: 180; easing.type: Easing.OutCubic
                            }
                        }

                        SequentialAnimation {
                            id: tabDisappearAnim
                            running: model.removing
                            NumberAnimation {
                                target: tab; property: "opacity"
                                to: 0; duration: 150; easing.type: Easing.InCubic
                            }
                            NumberAnimation {
                                target: tab; property: "width"
                                to: 0; duration: 200; easing.type: Easing.InCubic
                            }
                            ScriptAction { script: tabBar.finalizeRemove(model.index) }
                        }

                        GlyphIcon {
                            visible: model.pinned
                            anchors.centerIn: parent
                            name: model.isDir ? "folderFill" : "file"
                            size: 14
                            color: model.isDir ? Theme.folder : Theme.file
                        }

                        Row {
                            visible: !model.pinned
                            anchors {
                                left: parent.left
                                right: closeBtn.left
                                verticalCenter: parent.verticalCenter
                                leftMargin: 8
                                rightMargin: 4
                            }
                            spacing: 5

                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: model.isDir ? "folderFill" : "file"
                                size: 11
                                color: model.isDir ? Theme.folder : Theme.file
                            }

                            Text {
                                id: tabLabelText
                                text: model.name || "New Tab"
                                color: model.active ? Theme.text : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: Math.min(Math.min(implicitWidth, 120), Math.max(10, parent.parent.width - 50))
                            }
                        }

                        Rectangle {
                            visible: model.pinned
                            anchors { top: parent.top; right: parent.right; topMargin: 3; rightMargin: 3 }
                            width: 5; height: 5; radius: 2.5
                            color: model.tabColor && model.tabColor.length > 0 ? model.tabColor : Theme.accent
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            enabled: !model.removing

                            property real grabOffset: 0
                            property bool dragging: false

                            onPressedChanged: if (!pressed) { dragging = false; tab.isDragging = false }

                            onPressed: function(mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    grabOffset = mouse.x
                                    dragging = false
                                    tab.isDragging = false
                                }
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var pt = tabMouse.mapToItem(tabsRow, mouse.x, mouse.y)
                                var moved = pt.x - (tab.x + grabOffset)
                                if (!dragging && Math.abs(moved) < 12) return
                                dragging = true
                                tab.isDragging = true

                                var newIndex = model.index
                                if (model.index > 0) {
                                    var prev = model.index - 1
                                    while (prev >= 0 && tabsModel.get(prev).removing) prev--
                                    if (prev >= 0) {
                                        var prevItem = tabsRepeater.itemAt(prev)
                                        if (prevItem && pt.x < prevItem.x + prevItem.width / 2) {
                                            newIndex = prev
                                        }
                                    }
                                }
                                if (newIndex === model.index && model.index < tabsModel.count - 1) {
                                    var nxt = model.index + 1
                                    while (nxt < tabsModel.count && tabsModel.get(nxt).removing) nxt++
                                    if (nxt < tabsModel.count) {
                                        var nxtItem = tabsRepeater.itemAt(nxt)
                                        if (nxtItem && pt.x > nxtItem.x + nxtItem.width / 2) {
                                            newIndex = nxt
                                        }
                                    }
                                }
                                if (newIndex !== model.index) {
                                    tabsModel.move(model.index, newIndex, 1)
                                    Qt.callLater(tabBar.saveTabs)
                                }
                            }
                            onReleased: function(mouse) {
                                grabOffset = 0
                                if (dragging) {
                                    dragging = false
                                    tab.isDragging = false
                                    mouse.accepted = true
                                    return
                                }
                            }
                            onClicked: function(mouse) {
                                if (dragging) { mouse.accepted = true; return }
                                if (mouse.button === Qt.RightButton) {
                                    tabContextMenu.tabIndex = model.index
                                    tabContextMenu.x = mouse.x
                                    tabContextMenu.y = mouse.y
                                    tabContextMenu.open()
                                } else if (mouse.button === Qt.MiddleButton) {
                                    if (!model.pinned) tabBar.closeTab(model.index)
                                } else {
                                    tabBar.switchTab(model.index)
                                }
                            }
                        }

                        Menu {
                            id: tabContextMenu
                            property int tabIndex: -1
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: 6
                                implicitWidth: 200
                            }
                            delegate: MenuItem {
                                id: tabMenuItem
                                implicitWidth: 200
                                implicitHeight: 32
                                contentItem: Text {
                                    text: tabMenuItem.text
                                    color: tabMenuItem.enabled ? Theme.text : Theme.textFaint
                                    leftPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                                background: Rectangle {
                                    color: tabMenuItem.highlighted ? Theme.surfaceHi : "transparent"
                                    radius: 4
                                }
                            }

                            MenuItem {
                                text: model.pinned ? "Unpin tab" : "Pin tab"
                                onTriggered: tabBar.togglePin(tabContextMenu.tabIndex)
                            }

                            MenuItem {
                                implicitWidth: 200
                                implicitHeight: 38
                                background: Rectangle { color: "transparent" }
                                contentItem: Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { c: "", label: "—" },
                                            { c: "#FF5C5C", label: "" },
                                            { c: "#FFA94D", label: "" },
                                            { c: "#FFD93D", label: "" },
                                            { c: "#4CC38A", label: "" },
                                            { c: "#4DABF7", label: "" },
                                            { c: "#B197FC", label: "" },
                                            { c: "#F783AC", label: "" }
                                        ]
                                        delegate: Rectangle {
                                            width: 16; height: 16; radius: 8
                                            color: modelData.c || "transparent"
                                            border.color: tabContextMenu.tabIndex >= 0
                                                          && tabsModel.get(tabContextMenu.tabIndex)
                                                          && tabsModel.get(tabContextMenu.tabIndex).tabColor === modelData.c
                                                          ? Theme.text : Theme.border
                                            border.width: swatchMa.containsMouse ? 2 : 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: Theme.textFaint
                                                font.pixelSize: 11
                                                visible: modelData.label.length > 0
                                            }
                                            MouseArea {
                                                id: swatchMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    tabBar.setTabColor(tabContextMenu.tabIndex, modelData.c)
                                                    tabContextMenu.close()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MenuItem {
                                text: "Close tab"
                                enabled: !model.pinned
                                onTriggered: tabBar.closeTab(tabContextMenu.tabIndex)
                            }
                            MenuItem {
                                text: "Close other tabs"
                                enabled: tabBar.liveTabCount() > 1
                                onTriggered: tabBar.closeOtherTabs(tabContextMenu.tabIndex)
                            }
                            MenuItem {
                                text: model.homePath && backend.path === model.homePath ? "Current location" : "Set as home"
                                visible: model.pinned
                                enabled: !(model.homePath && backend.path === model.homePath)
                                height: visible ? implicitHeight : 0
                                onTriggered: tabBar.setHomeLocation(tabContextMenu.tabIndex)
                            }
                        }

                        DropArea {
                            id: tabDropArea
                            anchors.fill: parent
                            property bool isHovering: containsDrag
                            property int previousActiveIndex: -1
                            onIsHoveringChanged: {
                                if (isHovering) tabHoverTimer.start()
                                else {
                                    tabHoverTimer.stop()
                                    if (previousActiveIndex >= 0 && previousActiveIndex < tabsModel.count) {
                                        for (var i = 0; i < tabsModel.count; i++) {
                                            tabsModel.setProperty(i, "active", i === previousActiveIndex)
                                        }
                                        previousActiveIndex = -1
                                    }
                                }
                            }
                            Timer {
                                id: tabHoverTimer
                                interval: 400
                                onTriggered: {
                                    for (var i = 0; i < tabsModel.count; i++) {
                                        if (tabsModel.get(i).active && tabDropArea.previousActiveIndex < 0)
                                            tabDropArea.previousActiveIndex = i
                                        tabsModel.setProperty(i, "active", i === model.index)
                                    }
                                }
                            }
                            onDropped: function(drop) {
                                if (drop.hasUrls && backend && model.path) {
                                    backend.handleDrop(drop.urls, model.path, drop.proposedAction)
                                    drop.accept()
                                    previousActiveIndex = -1
                                    tabBar.switchTab(model.index)
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.accent
                                opacity: parent.containsDrag ? 0.1 : 0
                                radius: 6
                            }
                        }

                        Rectangle {
                            id: closeBtn
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: 6
                            }
                            width: 16; height: 16; radius: 4
                            color: closeMa.pressed ? Qt.rgba(1,1,1,0.22) : (closeMa.containsMouse ? Qt.rgba(1,1,1,0.13) : "transparent")
                            visible: !model.pinned && (tabMouse.containsMouse || model.active)
                            z: 1
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: closeMa.containsMouse ? Theme.text : Theme.textDim
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !model.removing
                                onClicked: tabBar.closeTab(model.index)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: addTabBtn
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 12
            }
            width: 28; height: 28; radius: 6
            color: addMa.pressed ? Qt.rgba(1,1,1,0.15) : (addMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")
            border.color: Theme.border; border.width: 1
            GlyphIcon { anchors.centerIn: parent; name: "plus"; size: 14; color: Theme.textDim }
            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tabBar.addTab("", false, "")
            }
        }

        function liveTabCount() {
            var n = 0
            for (var i = 0; i < tabsModel.count; i++) {
                if (!tabsModel.get(i).removing) n++
            }
            return n
        }

        function addTab(path, pinned, color) {
            newTabOpening = true
            var newIndex = tabsModel.count
            tabsModel.append({
                path: path || backend.path,
                name: path ? getFolderName(path) : (backend.path ? getFolderName(backend.path) : "Home"),
                isDir: true,
                active: false,
                isNew: true,
                removing: false,
                pinned: pinned || false,
                tabColor: color || "",
                homePath: ""
            })
            for (var i = 0; i < tabsModel.count; i++) {
                tabsModel.setProperty(i, "active", i === newIndex)
            }
            if (path) backend.navigate(path)
            newTabOpening = false
            Qt.callLater(saveTabs)
        }

        function closeTab(index) {
            if (index < 0 || index >= tabsModel.count) return
            var tab = tabsModel.get(index)
            if (tab.removing) return
            if (tab.pinned) return
            var wasActive = tab.active
            var isLast = liveTabCount() <= 1
            if (isLast) {
                tabsModel.setProperty(index, "path", "")
                tabsModel.setProperty(index, "name", "New Tab")
                tabsModel.setProperty(index, "tabColor", "")
                if (backend) backend.clearResults()
                return
            }
            if (wasActive) {
                var next = -1
                for (var j = index + 1; j < tabsModel.count; j++) {
                    if (!tabsModel.get(j).removing) { next = j; break }
                }
                if (next === -1) {
                    for (var k = index - 1; k >= 0; k--) {
                        if (!tabsModel.get(k).removing) { next = k; break }
                    }
                }
                if (next >= 0) {
                    tabsModel.setProperty(index, "active", false)
                    switchTab(next)
                }
            }
            tabsModel.setProperty(index, "removing", true)
        }

        function finalizeRemove(index) {
            if (index < 0 || index >= tabsModel.count) return
            var tab = tabsModel.get(index)
            if (!tab || !tab.removing) return
            tabsModel.remove(index)
            Qt.callLater(saveTabs)
        }

        function togglePin(index) {
            if (index < 0 || index >= tabsModel.count) return
            var tab = tabsModel.get(index)
            if (!tab) return
            var wasPinned = tab.pinned
            tabsModel.setProperty(index, "pinned", !wasPinned)
            if (!wasPinned && !tab.homePath && backend.path) {
                tabsModel.setProperty(index, "homePath", backend.path)
            }
            var insertAt = 0
            for (var i = 0; i < tabsModel.count; i++) {
                if (i === index) continue
                if (tabsModel.get(i).pinned) insertAt++
                else break
            }
            if (insertAt !== index && insertAt < tabsModel.count) {
                tabsModel.move(index, insertAt, 1)
            }
            Qt.callLater(saveTabs)
        }

        function setHomeLocation(index) {
            if (index < 0 || index >= tabsModel.count) return
            if (!backend.path) return
            tabsModel.setProperty(index, "homePath", backend.path)
            Qt.callLater(saveTabs)
        }

        function setTabColor(index, color) {
            if (index < 0 || index >= tabsModel.count) return
            tabsModel.setProperty(index, "tabColor", color || "")
            Qt.callLater(saveTabs)
        }

        function closeOtherTabs(keepIndex) {
            if (keepIndex < 0 || keepIndex >= tabsModel.count) return
            for (var i = tabsModel.count - 1; i >= 0; i--) {
                if (i === keepIndex) continue
                var t = tabsModel.get(i)
                if (!t || t.pinned || t.removing) continue
                closeTab(i)
            }
            switchTab(keepIndex)
        }

        function switchTab(index) {
            if (backend && backend.path && resultsView) {
                resultsView.saveScrollPositions(backend.path)
            }
            if (backend && backend.searchText.length > 0) {
                backend.clearSearch()
            }
            for (var i = 0; i < tabsModel.count; i++) {
                tabsModel.setProperty(i, "active", i === index)
            }
            var tab = tabsModel.get(index)
            if (tab && tab.path && tab.path !== backend.path) {
                pendingScrollRestorePath = tab.path
                Qt.callLater(function() {
                    backend.navigate(tab.path)
                })
            } else {
                pendingScrollRestorePath = ""
            }
        }

        function getFolderName(path) {
            if (!path) return "Home"
            var parts = path.split(/[\\/]/)
            return parts[parts.length - 1] || parts[parts.length - 2] || "Home"
        }

        function updateCurrentTabPath(newPath) {
            for (var i = 0; i < tabsModel.count; i++) {
                if (tabsModel.get(i).active) {
                    tabsModel.setProperty(i, "path", newPath)
                    tabsModel.setProperty(i, "name", getFolderName(newPath))
                    return
                }
            }
        }

        function saveTabs() {
            if (!backend) return
            var tabs = []
            for (var i = 0; i < tabsModel.count; i++) {
                var t = tabsModel.get(i)
                if (!t.removing) {
                    tabs.push({path: t.path, pinned: t.pinned, tabColor: t.tabColor, homePath: t.homePath})
                }
            }
            backend.saveTabs(tabs)
        }

        Component.onCompleted: {
            if (tabsModel.count === 0) {
                var loaded = backend ? backend.loadTabs() : []
                if (loaded && loaded.length > 0) {
                    for (var i = 0; i < loaded.length; i++) {
                        var t = loaded[i]
                        tabsModel.append({
                            isNew: false,
                            removing: false,
                            pinned: t.pinned || false,
                            tabColor: t.color || "",
                            path: t.path || "",
                            name: t.path ? getFolderName(t.path) : "Home",
                            homePath: t.homePath || "",
                            isDir: true,
                            active: i === 0
                        })
                    }
                    var first = tabsModel.get(0)
                    if (first && first.path && backend) backend.navigate(first.path)
                } else {
                    tabsModel.append({
                        isNew: false,
                        removing: false,
                        pinned: false,
                        tabColor: "",
                        path: backend.path || "",
                        name: backend.path ? getFolderName(backend.path) : "Home",
                        homePath: "",
                        isDir: true,
                        active: true
                    })
                }
            }
        }
    }

    Item {
        id: body
        anchors {
            left: parent.left; right: parent.right
            top: tabBar.bottom; bottom: statusBar.top
        }

        SplitView {
            anchors.fill: parent
            orientation: Qt.Horizontal
            handle: Rectangle {
                implicitWidth: 1
                color: Theme.divider
            }

            Rectangle {
                id: filtersPanel
                property bool collapsed: false
                property bool ready: false
                SplitView.preferredWidth: collapsed ? 20 : Theme.sidebar
                SplitView.minimumWidth: collapsed ? 20 : 240
                SplitView.maximumWidth: collapsed ? 20 : 400
                color: Theme.bg0
                Component.onCompleted: {
                    var v = backend ? backend.getSetting("filters_collapsed") : null
                    if (v !== null && v !== undefined) collapsed = v
                    ready = true
                }
                onCollapsedChanged: if (backend && ready) backend.setSetting("filters_collapsed", collapsed)
                Behavior on SplitView.preferredWidth {
                    enabled: filtersPanel.ready
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }

                Item {
                    anchors.fill: parent
                    clip: true

                    FiltersPanel {
                        id: filtersContent
                        width: parent.width
                        height: parent.height
                        visible: opacity > 0
                        panelCollapsed: filtersPanel.collapsed
                        onCollapseRequested: filtersPanel.collapsed = true
                        opacity: 1
                        scale: 1.0
                        states: [
                            State {
                                name: "collapsed"
                                when: filtersPanel.collapsed
                                PropertyChanges { target: filtersContent; opacity: 0; scale: 0.9 }
                            },
                            State {
                                name: "expanded"
                                when: !filtersPanel.collapsed
                                PropertyChanges { target: filtersContent; opacity: 1; scale: 1.0 }
                            }
                        ]
                        transitions: [
                            Transition {
                                to: "expanded"
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; duration: 300; easing.type: Easing.InOutCubic }
                                    NumberAnimation { property: "scale"; duration: 350; easing.type: Easing.OutBack }
                                }
                            }
                        ]
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 16; height: 16; radius: 3
                    visible: filtersPanel.collapsed
                    color: filterExpandMouse.containsMouse ? Theme.surfaceHi : Theme.bg0
                    border.color: Theme.border; border.width: 1
                    scale: filterExpandMouse.containsMouse ? 1.2 : 1.0
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    GlyphIcon { anchors.centerIn: parent; name: "chevronRight"; size: 9; color: Theme.textDim }
                    MouseArea {
                        id: filterExpandMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: filtersPanel.collapsed = false
                        ToolTip.visible: filterExpandMouse.containsMouse
                        ToolTip.text: "Expand filters"
                    }
                }
            }

            ResultsView {
                id: resultsView
                SplitView.fillWidth: true
                onBulkRenameRequested: function(names, paths) { bulkRenameDialog.openWith(names, paths) }
            }

            Rectangle {
                id: bookmarksPanel
                property bool collapsed: false
                property bool ready: false
                SplitView.preferredWidth: collapsed ? 20 : 220
                SplitView.minimumWidth: collapsed ? 20 : 160
                SplitView.maximumWidth: collapsed ? 20 : 320
                color: Theme.bg0
                Component.onCompleted: {
                    var v = backend ? backend.getSetting("bookmarks_collapsed") : null
                    if (v !== null && v !== undefined) collapsed = v
                    ready = true
                }
                onCollapsedChanged: if (backend && ready) backend.setSetting("bookmarks_collapsed", collapsed)
                Behavior on SplitView.preferredWidth {
                    enabled: bookmarksPanel.ready
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 16; height: 16; radius: 3
                    visible: bookmarksPanel.collapsed
                    color: expandMouse.containsMouse ? Theme.surfaceHi : Theme.bg0
                    border.color: Theme.border; border.width: 1
                    scale: expandMouse.containsMouse ? 1.2 : 1.0
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    GlyphIcon {
                        anchors.centerIn: parent
                        name: "chevronLeft"
                        size: 9
                        color: Theme.textDim
                        rotation: 0
                        Behavior on rotation { NumberAnimation { duration: 350; easing.type: Easing.InOutCubic } }
                    }
                    MouseArea {
                        id: expandMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bookmarksPanel.collapsed = false
                        ToolTip.visible: expandMouse.containsMouse
                        ToolTip.text: "Expand bookmarks"
                    }
                }

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 1; color: Theme.divider
                    visible: !bookmarksPanel.collapsed
                }

                Item {
                    anchors.fill: parent
                    clip: true

                    ColumnLayout {
                        id: bookmarksContent
                        width: parent.width
                        height: parent.height
                        anchors.margins: 0
                        spacing: 0
                        opacity: 1
                        scale: 1.0
                        states: [
                            State {
                                name: "collapsed"
                                when: bookmarksPanel.collapsed
                                PropertyChanges { target: bookmarksContent; opacity: 0; scale: 0.9 }
                            },
                            State {
                                name: "expanded"
                                when: !bookmarksPanel.collapsed
                                PropertyChanges { target: bookmarksContent; opacity: 1; scale: 1.0 }
                            }
                        ]
                        transitions: [
                            Transition {
                                to: "expanded"
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; duration: 300; easing.type: Easing.InOutCubic }
                                    NumberAnimation { property: "scale"; duration: 350; easing.type: Easing.OutBack }
                                }
                            }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            color: "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 8
                                GlyphIcon { name: "star"; size: 13; color: "#FFD60A"; visible: !bookmarksPanel.collapsed }
                                Label {
                                    text: "Bookmarks"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    visible: !bookmarksPanel.collapsed
                                }
                                Item { Layout.fillWidth: true; visible: bookmarksPanel.collapsed }
                                Rectangle {
                                    width: 24; height: 24; radius: 4
                                    color: collapseMouse.containsMouse ? Theme.surfaceHi : "transparent"
                                    visible: !bookmarksPanel.collapsed
                                    scale: collapseMouse.containsMouse ? 1.2 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    GlyphIcon {
                                        anchors.centerIn: parent
                                        name: "chevronLeft"
                                        size: 12
                                        color: Theme.textDim
                                        rotation: 180
                                        Behavior on rotation { NumberAnimation { duration: 350; easing.type: Easing.InOutCubic } }
                                    }
                                    MouseArea {
                                        id: collapseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: bookmarksPanel.collapsed = true
                                        ToolTip.visible: collapseMouse.containsMouse
                                        ToolTip.text: "Collapse bookmarks"
                                    }
                                }
                            }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 1; color: Theme.divider
                                visible: !bookmarksPanel.collapsed
                            }
                        }

                        ListView {
                            id: bookmarkList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: backend ? backend.bookmarks : []
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            visible: bookmarksContent.opacity > 0

                            Label {
                                anchors.centerIn: parent
                                visible: bookmarkList.count === 0
                                text: "No bookmarks yet.\nStar a folder or file."
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            delegate: Rectangle {
                                id: bmRow
                                width: bookmarkList.width
                                height: 36
                                color: bmHover.containsMouse ? Theme.surfaceHi : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                MouseArea {
                                    id: bmHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.navigateBookmark(modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    GlyphIcon { name: "folderFill"; size: 11; color: Theme.folder }
                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            var parts = modelData.replace(/\\/g, "/").split("/")
                                            return parts[parts.length - 1] || modelData
                                        }
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        ToolTip.visible: bmHover.containsMouse
                                        ToolTip.text: modelData
                                        ToolTip.delay: 500
                                    }
                                    Rectangle {
                                        width: 20; height: 20; radius: 4
                                        color: unstarMouse.containsMouse ? Qt.rgba(1,0.35,0.35,0.32) : "transparent"
                                        opacity: (bmHover.containsMouse || unstarMouse.containsMouse) ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        GlyphIcon { anchors.centerIn: parent; name: "close"; size: 9; color: Theme.textFaint }
                                        MouseArea {
                                            id: unstarMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                mouse.accepted = true
                                                backend.toggleBookmark(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: statusBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 32
        color: Theme.bg0

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: Theme.divider
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 16

            Rectangle {
                radius: 10
                height: 24
                width: cacheChip.implicitWidth + 22
                color: cacheMouse.containsMouse ? Qt.rgba(0.31, 0.56, 1.00, 0.20) : Qt.rgba(0.31, 0.56, 1.00, 0.10)
                border.color: Qt.rgba(0.31, 0.56, 1.00, 0.40)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                RowLayout {
                    id: cacheChip
                    anchors.centerIn: parent
                    spacing: 6
                    property string cacheText: backend ? backend.totalCacheSizeText() : "0 B"
                    Timer {
                        interval: 3000
                        running: true
                        repeat: true
                        onTriggered: cacheChip.cacheText = backend ? backend.totalCacheSizeText() : "0 B"
                    }
                    GlyphIcon { name: "image"; size: 12; color: Qt.rgba(0.31, 0.56, 1.00, 1.0) }
                    Label {
                        text: cacheChip.cacheText
                        color: Qt.rgba(0.31, 0.56, 1.00, 1.0)
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        width: 1
                        height: 12
                        color: Qt.rgba(0.31, 0.56, 1.00, 0.30)
                    }
                    GlyphIcon {
                        name: "trash"
                        size: 11
                        color: cacheMouse.containsMouse ? Theme.danger : Qt.rgba(0.31, 0.56, 1.00, 0.7)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }
                MouseArea {
                    id: cacheMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (thumbnailCache) thumbnailCache.clearCache()
                        if (videoThumbnailCache) videoThumbnailCache.clearCache()
                        if (backend) backend.clearScanCache()
                    }
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Clear cache"
                    ToolTip.delay: 300
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 8
                Rectangle {
                    radius: 10
                    height: 20
                    width: foldersChip.implicitWidth + 18
                    color: Qt.rgba(0.96, 0.72, 0.38, 0.10)
                    border.color: Qt.rgba(0.96, 0.72, 0.38, 0.28)
                    RowLayout {
                        id: foldersChip
                        anchors.centerIn: parent
                        spacing: 5
                        GlyphIcon { name: "folderFill"; size: 11; color: Theme.folder }
                        Label { text: (backend && backend.directCounts && backend.totals) ? (backend.directCounts.folders + "/" + backend.totals.folders) : 0; color: Theme.folder; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.DemiBold }
                    }
                }
                Rectangle {
                    radius: 10
                    height: 20
                    width: filesChip.implicitWidth + 18
                    color: Qt.rgba(0.48, 0.84, 0.64, 0.10)
                    border.color: Qt.rgba(0.48, 0.84, 0.64, 0.28)
                    RowLayout {
                        id: filesChip
                        anchors.centerIn: parent
                        spacing: 5
                        GlyphIcon { name: "file"; size: 11; color: Theme.file }
                        Label { text: (backend && backend.directCounts && backend.totals) ? (backend.directCounts.files + "/" + backend.totals.files) : 0; color: Theme.file; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.DemiBold }
                    }
                }
                Rectangle {
                    radius: 10
                    height: 20
                    width: sizeChip.implicitWidth + 18
                    color: Qt.rgba(0.49, 0.36, 1.00, 0.12)
                    border.color: Qt.rgba(0.49, 0.36, 1.00, 0.30)
                    Label {
                        id: sizeChip
                        anchors.centerIn: parent
                        text: (backend && backend.totals) ? backend.totals.size_text : "0 B"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    radius: 10
                    height: 20
                    width: modeChip.implicitWidth + 18
                    color: Qt.rgba(0.31, 0.56, 1.00, 0.10)
                    border.color: Qt.rgba(0.31, 0.56, 1.00, 0.28)
                    RowLayout {
                        id: modeChip
                        anchors.centerIn: parent
                        spacing: 5
                        GlyphIcon {
                            name: {
                                if (!backend) return "list"
                                var m = backend.viewMode
                                if (m === "grid") return "grid"
                                if (m === "tree") return "tree"
                                if (m === "analytics") return "chart"
                                return "list"
                            }
                            size: 11
                            color: Qt.rgba(0.31, 0.56, 1.00, 1.0)
                        }
                        Label {
                            text: {
                                if (!backend) return "List"
                                var m = backend.viewMode
                                if (m === "grid") return "Grid"
                                if (m === "tree") return "Tree"
                                if (m === "analytics") return "Stats"
                                return "List"
                            }
                            color: Qt.rgba(0.31, 0.56, 1.00, 1.0)
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Select directory"
        onAccepted: {
            var p = selectedFolder.toString()
            if (p.startsWith("file:///")) p = p.substring(8)
            else if (p.startsWith("file://")) p = p.substring(7)
            navigateSafe(decodeURIComponent(p))
        }
    }

    FileDialog {
        id: exportDialog
        title: "Export results"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "txt"
        nameFilters: ["Text files (*.txt)", "All files (*)"]
        onAccepted: backend.exportCurrent(selectedFile.toString())
    }

    FileDialog {
        id: viewExportDialog
        title: "View exported file"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Text files (*.txt)", "All files (*)"]
        onAccepted: {
            exportPreview.text = backend.readExportedFile(selectedFile.toString())
            exportPreviewWindow.title = "Exported: " + selectedFile.toString()
            exportPreviewWindow.show()
        }
    }

    Popup {
        id: newFolderDialog
        modal: true
        anchors.centerIn: parent
        width: 320
        height: 160
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surface; radius: 14
            border.color: Theme.borderHi; border.width: 1
        }

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 24
            spacing: 14

            Label {
                text: "Create new folder"
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            TextField {
                id: newFolderName
                Layout.fillWidth: true
                placeholderText: "Folder name"
                placeholderTextColor: Theme.textFaint
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 13
                background: Rectangle { color: Theme.bg1; radius: 8; border.color: Theme.border; border.width: 1 }
                selectByMouse: true
                onAccepted: {
                    if (text.length > 0) {
                        backend.newFolder(text)
                        newFolderDialog.close()
                        text = ""
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 70; height: 32; radius: 8
                    color: cancelBtnMa.pressed ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Label { anchors.centerIn: parent; text: "Cancel"; color: Theme.textDim; font.pixelSize: 12 }
                    MouseArea {
                        id: cancelBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { newFolderDialog.close(); newFolderName.text = "" }
                    }
                }
                Rectangle {
                    width: 70; height: 32; radius: 8
                    color: okBtnMa.pressed ? Theme.accent : Qt.rgba(0.49,0.36,1.00,0.20)
                    border.color: Theme.accent; border.width: 1
                    Label { anchors.centerIn: parent; text: "Create"; color: Theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea {
                        id: okBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (newFolderName.text.length > 0) {
                                backend.newFolder(newFolderName.text)
                                newFolderDialog.close()
                                newFolderName.text = ""
                            }
                        }
                    }
                }
            }
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 } }
    }

    Window {
        id: exportPreviewWindow
        width: 920; height: 720
        color: Theme.bg0
        Rectangle {
            anchors.fill: parent
            anchors.margins: 16
            radius: Theme.radius
            color: Theme.surface
            border.color: Theme.border
            ScrollView {
                anchors.fill: parent
                anchors.margins: 14
                clip: true
                TextArea {
                    id: exportPreview
                    readOnly: true
                    wrapMode: TextArea.NoWrap
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: "#ffffff"
                    background: null
                }
            }
        }
    }

    Popup {
        id: archiveAppDialog
        modal: true
        anchors.centerIn: parent
        width: 360
        height: dialogCol2.implicitHeight + 48
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surface
            radius: 14
            border.color: Theme.borderHi
            border.width: 1
        }

        ColumnLayout {
            id: dialogCol2
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
            spacing: 16

            Label {
                text: "Select Archive Application"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.divider
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        {name: "7-Zip", id: "7z"},
                        {name: "WinRAR", id: "winrar"},
                        {name: "WinZip", id: "winzip"}
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 8
                        color: appMouse.containsMouse ? Theme.surfaceHi : "transparent"
                        border.color: (backend && backend.archiveApp === modelData.id) ? Theme.accent : Theme.border
                        border.width: (backend && backend.archiveApp === modelData.id) ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Rectangle {
                                width: 20; height: 20; radius: 4
                                color: (backend && backend.archiveApp === modelData.id) ? Theme.accent : Theme.bg1
                                border.color: (backend && backend.archiveApp === modelData.id) ? Theme.accent : Theme.border
                                border.width: 1

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10; height: 10; radius: 2
                                    color: "#ffffff"
                                    visible: backend && backend.archiveApp === modelData.id
                                }
                            }

                            Label {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }

                            Item { Layout.fillWidth: true }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.setArchiveApp(modelData.id)
                                archiveAppDialog.close()
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 80; height: 32; radius: 8
                    color: cancelArchiveBtn.pressed ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Label { anchors.centerIn: parent; text: "Cancel"; color: Theme.textDim; font.pixelSize: 12 }
                    MouseArea {
                        id: cancelArchiveBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: archiveAppDialog.close()
                    }
                }
            }
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 } }
    }

    property string _pendingPath: ""

    function navigateSafe(path) {
        backend.navigate(path)
    }

    Popup {
        id: driveRootDialog
        modal: true
        anchors.centerIn: parent
        width: 420
        height: dialogCol.implicitHeight + 48
        padding: 0
        closePolicy: Popup.NoAutoClose

        background: Rectangle {
            color: Theme.surface
            radius: 14
            border.color: Theme.warn
            border.width: 1
            layer.enabled: true
            layer.effect: null
        }

        Overlay.modal: Rectangle { color: Qt.rgba(0,0,0,0.55) }

        ColumnLayout {
            id: dialogCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 24
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 36; height: 36; radius: 10
                    color: Qt.rgba(1, 0.78, 0.20, 0.15)
                    border.color: Qt.rgba(1, 0.78, 0.20, 0.35); border.width: 1
                    GlyphIcon { anchors.centerIn: parent; name: "warn"; size: 18; color: Theme.warn }
                }
                Label {
                    text: "Scan entire disk?"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15; font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 16; Layout.bottomMargin: 16 }

            Label {
                Layout.fillWidth: true
                text: "Warning: Scanning entire disks is generally a bad idea as it can be extremely slow, consume significant system resources, and return too many results.<br/><br/>Are you sure you want to scan <b style='color:" + Theme.text + "'>" + window._pendingPath + "</b>?"
                color: Theme.textDim
                font.family: Theme.fontFamily; font.pixelSize: 12
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 16; Layout.bottomMargin: 16 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8
                    color: cancelMa.pressed ? Qt.rgba(1,1,1,0.10)
                         : cancelMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Label {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: 13
                    }
                    MouseArea {
                        id: cancelMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { window._pendingPath = ""; driveRootDialog.close() }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8
                    color: proceedMa.pressed ? Qt.rgba(1, 0.78, 0.20, 0.40)
                         : proceedMa.containsMouse ? Qt.rgba(1, 0.78, 0.20, 0.28) : Qt.rgba(1, 0.78, 0.20, 0.18)
                    border.color: Qt.rgba(1, 0.78, 0.20, proceedMa.containsMouse ? 0.7 : 0.45); border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Label {
                        anchors.centerIn: parent
                        text: "Confirm"
                        color: Theme.warn
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: proceedMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            window._pendingPath = ""
                            driveRootDialog.close()
                            if (backend) {
                                backend.forceRecursive = true
                                backend.scan()
                            }
                        }
                    }
                }
            }

            Item { height: 0 }
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic } }
        exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140; easing.type: Easing.InCubic } }
    }

    BulkRenameDialog { id: bulkRenameDialog }

    Popup {
        id: renameConflictDialog
        modal: true
        anchors.centerIn: parent
        width: 460
        height: renamingOldMode ? 260 : 210
        padding: 0
        closePolicy: Popup.NoAutoClose

        property string oldName: ""
        property string newName: ""
        property string suggestedName: ""
        property bool renamingOldMode: false

        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        onOpened: { renamingOldMode = false }

        Overlay.modal: Rectangle { color: Qt.rgba(0,0,0,0.55) }

        background: Rectangle {
            color: Theme.surface
            radius: 14
            border.color: Theme.borderHi
            border.width: 1
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic } }
        exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140; easing.type: Easing.InCubic } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24; Layout.rightMargin: 24
                Layout.topMargin: 20; Layout.bottomMargin: 16
                spacing: 10
                Label {
                    text: renameConflictDialog.renamingOldMode ? "Rename Existing File" : "Name Already Exists"
                    color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            Label {
                visible: !renameConflictDialog.renamingOldMode
                Layout.fillWidth: true
                Layout.leftMargin: 24; Layout.rightMargin: 24
                Layout.topMargin: 16; Layout.bottomMargin: 16
                text: "<b>" + renameConflictDialog.newName + "</b> already exists in this folder. What would you like to do?"
                color: Theme.textDim
                font.family: Theme.fontFamily; font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                visible: renameConflictDialog.renamingOldMode
                Layout.fillWidth: true
                Layout.leftMargin: 24; Layout.rightMargin: 24
                Layout.topMargin: 16; Layout.bottomMargin: 12
                spacing: 8

                Label {
                    text: "New name for the existing file:"
                    color: Theme.textDim
                    font.family: Theme.fontFamily; font.pixelSize: 12
                }
                TextField {
                    id: renameOldField
                    Layout.fillWidth: true
                    text: renameConflictDialog.suggestedName
                    color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 13
                    selectByMouse: true
                    background: Rectangle {
                        color: Theme.surfaceHi
                        radius: 7
                        border.color: renameOldField.activeFocus ? Theme.accent : Theme.border
                        border.width: renameOldField.activeFocus ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                    onVisibleChanged: {
                        if (visible) Qt.callLater(function() {
                            renameOldField.forceActiveFocus()
                            var dot = renameOldField.text.lastIndexOf(".")
                            if (dot > 0) renameOldField.select(0, dot)
                            else renameOldField.selectAll()
                        })
                    }
                    onAccepted: rcKeepBothMa.doConfirm()
                    Keys.onEscapePressed: renameConflictDialog.renamingOldMode = false
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16; Layout.rightMargin: 16
                Layout.topMargin: 12; Layout.bottomMargin: 16
                spacing: 8

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 60; height: 32; radius: 8
                    color: rcSkipMa.pressed   ? Qt.rgba(1,1,1,0.10)
                         : rcSkipMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Label {
                        anchors.centerIn: parent
                        text: renameConflictDialog.renamingOldMode ? "Back" : "Skip"
                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                    }
                    MouseArea {
                        id: rcSkipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (renameConflictDialog.renamingOldMode) {
                                renameConflictDialog.renamingOldMode = false
                            } else {
                                backend.resolveRenameConflict(renameConflictDialog.oldName, renameConflictDialog.newName, "skip")
                                renameConflictDialog.close()
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !renameConflictDialog.renamingOldMode
                    width: 90; height: 32; radius: 8
                    color: rcRenameOldMa.pressed   ? Qt.rgba(1,1,1,0.10)
                         : rcRenameOldMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Label { anchors.centerIn: parent; text: "Rename Old"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12 }
                    MouseArea {
                        id: rcRenameOldMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: renameConflictDialog.renamingOldMode = true
                    }
                }

                Rectangle {
                    id: rcKeepBothBtn
                    height: 32; width: 86; radius: 8
                    color: rcKeepBothMa.pressed   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                         : rcKeepBothMa.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                         :                              Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, rcKeepBothMa.containsMouse ? 0.6 : 0.35)
                    border.width: 1
                    Label {
                        anchors.centerIn: parent
                        text: renameConflictDialog.renamingOldMode ? "Confirm" : "Keep Both"
                        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                    }
                    MouseArea {
                        id: rcKeepBothMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        function doConfirm() {
                            if (renameConflictDialog.renamingOldMode) {
                                var newOldName = renameOldField.text.trim()
                                if (newOldName.length === 0) return
                                backend.resolveRenameConflict(
                                    renameConflictDialog.oldName,
                                    renameConflictDialog.newName,
                                    "renameold:" + newOldName
                                )
                                renameConflictDialog.close()
                            } else {
                                backend.resolveRenameConflict(renameConflictDialog.oldName, renameConflictDialog.newName, "keepboth")
                                renameConflictDialog.close()
                            }
                        }
                        onClicked: doConfirm()
                    }
                    ToolTip {
                        visible: rcKeepBothMa.containsMouse && !renameConflictDialog.renamingOldMode
                        text: "Will be saved as: " + renameConflictDialog.suggestedName
                        delay: 0
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    Popup {
        id: pasteConflictDialog
        modal: true
        anchors.centerIn: parent
        width: 580
        height: 380
        padding: 0
        closePolicy: Popup.NoAutoClose

        property var conflictsList: []
        property int currentConflictIndex: 0

        Overlay.modal: Rectangle { color: Qt.rgba(0,0,0,0.55) }

        background: Rectangle {
            color: Theme.surface
            radius: 14
            border.color: Theme.borderHi
            border.width: 1
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic } }
        exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140; easing.type: Easing.InCubic } }

        ColumnLayout {
            id: conflictLayout
            anchors.fill: parent
            anchors.margins: 24
            spacing: 0

            property var currentConflict: (pasteConflictDialog.conflictsList && pasteConflictDialog.currentConflictIndex < pasteConflictDialog.conflictsList.length) ? pasteConflictDialog.conflictsList[pasteConflictDialog.currentConflictIndex] : null

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    width: 36; height: 36; radius: 10
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35); border.width: 1
                    GlyphIcon { anchors.centerIn: parent; name: "copy"; size: 18; color: Theme.accent }
                }
                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    Label {
                        text: "File Naming Conflict"
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
                    }
                    Label {
                        text: pasteConflictDialog.conflictsList.length > 1
                              ? "Resolving conflict " + (pasteConflictDialog.currentConflictIndex + 1) + " of " + pasteConflictDialog.conflictsList.length
                              : "This destination folder already contains a file with the same name."
                        color: Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 16; Layout.bottomMargin: 16 }

            RowLayout {
                id: cardsRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                property var cc: conflictLayout.currentConflict

                Rectangle {
                    id: existingCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: existingMa.containsMouse
                           ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.06)
                           : Theme.bg1
                    border.color: existingMa.containsMouse
                                  ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.65)
                                  : Theme.border
                    border.width: existingMa.containsMouse ? 2 : 1
                    clip: true
                    scale: existingMa.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: existingMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pasteConflictDialog.resolveAndNext("skip")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "EXISTING FILE"
                                color: existingMa.containsMouse ? Theme.success : Theme.textFaint
                                font.family: Theme.fontFamily; font.pixelSize: 9; font.weight: Font.Bold
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Label {
                                text: "Click to keep"
                                color: Theme.success
                                font.family: Theme.fontFamily; font.pixelSize: 9; font.weight: Font.DemiBold
                                opacity: existingMa.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: cardsRow.cc ? (cardsRow.cc.isDir ? Qt.rgba(0.96,0.72,0.38,0.20) : Qt.rgba(0.5,0.5,0.5,0.15)) : "transparent"
                                GlyphIcon {
                                    anchors.centerIn: parent
                                    name: cardsRow.cc && cardsRow.cc.isDir ? "folderFill" : "file"
                                    size: 16
                                    color: cardsRow.cc && cardsRow.cc.isDir ? Theme.folder : Theme.file
                                }
                            }
                            Label {
                                text: cardsRow.cc ? cardsRow.cc.name : ""
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        Item { Layout.fillHeight: true }

                        ColumnLayout {
                            spacing: 3
                            Layout.fillWidth: true
                            Label {
                                text: "Size: " + (cardsRow.cc ? cardsRow.cc.destSize : "")
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: 12
                            }
                            Label {
                                text: "Modified: " + (cardsRow.cc ? cardsRow.cc.destModified : "")
                                color: Theme.textFaint
                                font.family: Theme.fontMono; font.pixelSize: 10
                            }
                        }
                    }
                }

                Rectangle {
                    id: incomingCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: incomingMa.containsMouse
                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                           : Theme.bg1
                    border.color: incomingMa.containsMouse
                                  ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                                  : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                    border.width: incomingMa.containsMouse ? 2 : 1
                    clip: true
                    scale: incomingMa.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.03)
                    }

                    MouseArea {
                        id: incomingMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pasteConflictDialog.resolveAndNext("replace")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "NEW INCOMING FILE"
                                color: incomingMa.containsMouse ? Theme.accent : Theme.accent
                                font.family: Theme.fontFamily; font.pixelSize: 9; font.weight: Font.Bold
                                Layout.fillWidth: true
                            }
                            Label {
                                text: "Click to use"
                                color: Theme.accent
                                font.family: Theme.fontFamily; font.pixelSize: 9; font.weight: Font.DemiBold
                                opacity: incomingMa.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: cardsRow.cc ? (cardsRow.cc.isDir ? Qt.rgba(0.96,0.72,0.38,0.20) : Qt.rgba(0.5,0.5,0.5,0.15)) : "transparent"
                                GlyphIcon {
                                    anchors.centerIn: parent
                                    name: cardsRow.cc && cardsRow.cc.isDir ? "folderFill" : "file"
                                    size: 16
                                    color: cardsRow.cc && cardsRow.cc.isDir ? Theme.folder : Theme.file
                                }
                            }
                            Label {
                                text: cardsRow.cc ? cardsRow.cc.name : ""
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        Item { Layout.fillHeight: true }

                        ColumnLayout {
                            spacing: 3
                            Layout.fillWidth: true
                            Label {
                                text: "Size: " + (cardsRow.cc ? cardsRow.cc.srcSize : "")
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: 12
                            }
                            Label {
                                text: "Modified: " + (cardsRow.cc ? cardsRow.cc.srcModified : "")
                                color: Theme.textFaint
                                font.family: Theme.fontMono; font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 16; Layout.bottomMargin: 16 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    spacing: 6
                    visible: pasteConflictDialog.conflictsList.length > 1
                    ModernCheck {
                        id: applyAllCheck
                        text: "Do this for all remaining conflicts"
                        checked: false
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 72; height: 32; radius: 8
                    color: cancelConflictMa.pressed ? Qt.rgba(1,1,1,0.10)
                         : cancelConflictMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Label { anchors.centerIn: parent; text: "Cancel"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12 }
                    MouseArea {
                        id: cancelConflictMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            backend.clearPendingPaste()
                            pasteConflictDialog.close()
                        }
                    }
                }

                Rectangle {
                    width: 60; height: 32; radius: 8
                    color: skipConflictMa.pressed ? Qt.rgba(1,1,1,0.10)
                         : skipConflictMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Label { anchors.centerIn: parent; text: "Skip"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12 }
                    MouseArea {
                        id: skipConflictMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: pasteConflictDialog.resolveAndNext("skip")
                    }
                }

                Rectangle {
                    width: 86; height: 32; radius: 8
                    color: renameConflictMa.pressed ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                         : renameConflictMa.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, renameConflictMa.containsMouse ? 0.6 : 0.35); border.width: 1
                    Label { anchors.centerIn: parent; text: "Keep Both"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12 }
                    MouseArea {
                        id: renameConflictMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: pasteConflictDialog.resolveAndNext("rename")
                    }
                }

                Rectangle {
                    width: 80; height: 32; radius: 8
                    color: replaceConflictMa.pressed ? Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.35)
                         : replaceConflictMa.containsMouse ? Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.25) : Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.15)
                    border.color: Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, replaceConflictMa.containsMouse ? 0.7 : 0.45); border.width: 1
                    Label { anchors.centerIn: parent; text: "Replace"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12 }
                    MouseArea {
                        id: replaceConflictMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: pasteConflictDialog.resolveAndNext("replace")
                    }
                }
            }
        }

        function resolveAndNext(action) {
            var current = pasteConflictDialog.conflictsList[pasteConflictDialog.currentConflictIndex]
            if (!current) return

            if (applyAllCheck.checked) {
                backend.resolveAllConflicts(action)
                pasteConflictDialog.close()
            } else {
                backend.resolveConflict(current.src, action)
                pasteConflictDialog.currentConflictIndex++
                if (pasteConflictDialog.currentConflictIndex >= pasteConflictDialog.conflictsList.length) {
                    backend.executePendingPaste()
                    pasteConflictDialog.close()
                }
            }
        }
    }

    Popup {
        id: pasteProgressDialog
        modal: true
        anchors.centerIn: parent
        width: 440
        height: 250
        padding: 0
        closePolicy: Popup.NoAutoClose

        Overlay.modal: Rectangle { color: Qt.rgba(0,0,0,0.55) }

        background: Rectangle {
            color: Theme.surface
            radius: 14
            border.color: Theme.borderHi
            border.width: 1
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic } }
        exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140; easing.type: Easing.InCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    GlyphIcon { anchors.centerIn: parent; name: "copy"; size: 14; color: Theme.accent }
                }
                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    Label {
                        text: (backend && backend.pasteProgress)
                              ? (backend.clipboardCutPaths && backend.clipboardCutPaths.length > 0 ? "Moving items..." : "Copying items...")
                              : "Copying..."
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    Label {
                        text: (backend && backend.pasteProgress)
                              ? "Item " + (backend.pasteProgress.currentFileIndex + 1) + " of " + backend.pasteProgress.totalFiles
                              : ""
                        color: Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
                    Layout.fillWidth: true
                    text: (backend && backend.pasteProgress && backend.pasteProgress.currentFileName)
                          ? "Current: " + backend.pasteProgress.currentFileName
                          : "Preparing..."
                    color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 11
                    elide: Text.ElideMiddle
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Theme.bg1
                    clip: true

                    Rectangle {
                        width: (backend && backend.pasteProgress && backend.pasteProgress.filePercent)
                               ? (backend.pasteProgress.filePercent / 100) * parent.width
                               : 0
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: (backend && backend.pasteProgress)
                              ? backend.pasteProgress.fileBytesDoneText + " of " + backend.pasteProgress.fileBytesTotalText
                              : ""
                        color: Theme.textFaint
                        font.family: Theme.fontMono; font.pixelSize: 9
                    }
                    Label {
                        text: (backend && backend.pasteProgress && backend.pasteProgress.speedText)
                              ? backend.pasteProgress.speedText
                              : ""
                        color: Theme.textFaint
                        font.family: Theme.fontMono; font.pixelSize: 9
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: (backend && backend.pasteProgress)
                              ? backend.pasteProgress.filePercent + "%"
                              : "0%"
                        color: Theme.textFaint
                        font.family: Theme.fontMono; font.pixelSize: 9
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
                    text: "Total Progress"
                    color: Theme.textDim
                    font.family: Theme.fontFamily; font.pixelSize: 11
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Theme.bg1
                    clip: true

                    Rectangle {
                        width: (backend && backend.pasteProgress && backend.pasteProgress.overallPercent)
                               ? (backend.pasteProgress.overallPercent / 100) * parent.width
                               : 0
                        height: parent.height
                        radius: 3
                        color: Theme.accent
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: (backend && backend.pasteProgress)
                              ? backend.pasteProgress.overallBytesDoneText + " of " + backend.pasteProgress.overallBytesTotalText
                              : ""
                        color: Theme.textDim
                        font.family: Theme.fontMono; font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: (backend && backend.pasteProgress)
                              ? backend.pasteProgress.overallPercent + "%"
                              : "0%"
                        color: Theme.accent
                        font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 72; height: 28; radius: 6
                    color: cancelPasteMa.pressed ? Qt.rgba(1,1,1,0.10)
                         : cancelPasteMa.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    Label { anchors.centerIn: parent; text: "Cancel"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
                    MouseArea {
                        id: cancelPasteMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            backend.cancelPaste()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: toast
        property string level: "info"
        anchors.top: parent.top
        anchors.topMargin: 112
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 10
        opacity: 0
        visible: opacity > 0
        z: 999
        color: Theme.surfaceHi
        border.color: level === "error" ? Theme.danger
                     : level === "warn" ? Theme.warn
                     : level === "success" ? Theme.success
                     : Theme.borderHi
        border.width: 1
        width: 480
        height: toastLabel.implicitHeight + 22

        Rectangle {
            width: 4
            height: parent.height - 14
            radius: 2
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            color: toast.level === "error" ? Theme.danger
                  : toast.level === "warn" ? Theme.warn
                  : toast.level === "success" ? Theme.success
                  : Theme.accent
        }

        Label {
            id: toastLabel
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 22
            anchors.right: parent.right; anchors.rightMargin: 14
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        Behavior on opacity { NumberAnimation { duration: 220 } }
        transform: Translate { id: toastT; y: toast.opacity > 0 ? 0 : -12 }

        Timer {
            id: toastTimer
            interval: 3500
            onTriggered: toast.opacity = 0
        }

        function show(msg, lvl) {
            toastLabel.text = msg
            level = lvl || "info"
            opacity = 0.98
            toastTimer.interval = (lvl === "warn" || lvl === "error") ? 6000 : 3500
            toastTimer.restart()
        }
    }

    Shortcut { sequence: "Ctrl+L"; onActivated: { addressField.forceActiveFocus(); addressField.selectAll() } }
    Shortcut { sequence: "Ctrl+F"; onActivated: { searchInput.forceActiveFocus(); searchInput.selectAll() } }
    Shortcut { sequence: "Ctrl+R"; onActivated: backend.reload() }
    Shortcut { sequence: "F5";     onActivated: backend.reload() }
    Shortcut { sequence: "Alt+Left";  onActivated: backend.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: backend.goForward() }
    Shortcut { sequence: "Alt+Up";    onActivated: backend.goUp() }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: newFolderDialog.open() }
    Shortcut { sequence: "Ctrl+T"; onActivated: tabBar.addTab("") }
    Shortcut { sequence: "Ctrl+W"; onActivated: {
        for (var i = 0; i < tabsModel.count; i++) {
            if (tabsModel.get(i).active) {
                tabBar.closeTab(i)
                break
            }
        }
    }}
    Shortcut { sequence: "Ctrl+Tab"; onActivated: {
        var next = 0
        for (var i = 0; i < tabsModel.count; i++) {
            if (tabsModel.get(i).active) {
                next = (i + 1) % tabsModel.count
                break
            }
        }
        tabBar.switchTab(next)
    }}
    Shortcut { sequence: "Ctrl+Z"; onActivated: { if (backend) backend.undoAndNotify() } }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.BackButton) backend.goBack()
            else if (mouse.button === Qt.ForwardButton) backend.goForward()
        }
    }

    Component.onCompleted: { fadeInAnim.start() }
}
