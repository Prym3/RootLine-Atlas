import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtMultimedia
import MpvVideo 1.0
import "."

Rectangle {
    id: root
    color: Theme.bg1
    focus: true

    Keys.onPressed: function(event) {
        if (event.text.length === 1 && /[a-zA-Z]/.test(event.text)) {
            jumpToLetter(event.text)
            event.accepted = true
        }
    }

    property bool previewShowing: previewPane.showPreview
    property int previewWidth: previewPane.width

    readonly property string prismRenameExe: backend ? backend.siblingAppPath("RootLine Nomen", "RootLineNomen.exe") : ""
    readonly property string prismCrossCheckExe: backend ? backend.siblingAppPath("Crosscheck", "Crosscheck.exe") : ""
    readonly property string prismTimestampExe: backend ? backend.adjacentAppPath("Timestamp/Timestamp.exe") : ""

    function _selectedPaths() {
        var paths = []
        var m = backend.model
        for (var i = 0; i < selectedIndices.length; i++) {
            var p = m.data(m.index(selectedIndices[i], 0), 267)
            if (p) paths.push(p)
        }
        return paths
    }

    function _isArchive(name) {
        var archiveExts = [".rar",".zip",".7z",".tar",".gz",".bz2",".xz",".iso",".cab",".arj",".lzh",".ace",".tar.gz",".tar.bz2",".tar.xz"]
        var lowerName = name.toLowerCase()
        for (var i = 0; i < archiveExts.length; i++) {
            if (lowerName.endsWith(archiveExts[i])) return true
        }
        return false
    }

    function _selectedArchivePaths() {
        var paths = []
        var m = backend.model
        for (var i = 0; i < selectedIndices.length; i++) {
            var idx = selectedIndices[i]
            var name = m.data(m.index(idx, 0), 257)
            var path = m.data(m.index(idx, 0), 267)
            if (path && _isArchive(name)) paths.push(path)
        }
        return paths
    }

    property var selectedIndices: []
    property int lastSelectedIndex: -1
    property int renameRequestIndex: -1

    property var activeEditField: null
    function commitActiveEdit() {
        if (activeEditField) {
            activeEditField.focus = false
        }
    }
    function cancelActiveEdit() {
        if (activeEditField) {
            activeEditField.canceling = true
            activeEditField.focus = false
        }
    }

    property bool dragActive: false
    property real dragStartContentX: 0
    property real dragStartContentY: 0
    property real dragCurrentViewX: 0
    property real dragCurrentViewY: 0
    property var dragStartSelection: []

    property var scrollPositions: ({})

    property string lastKeyNavLetter: ""
    property int lastKeyNavIndex: -1

    function jumpToLetter(letter) {
        if (!backend || !backend.model) return
        var m = backend.model
        var rowCount = m.rowCount()
        if (rowCount === 0) return

        var startIndex = 0
        if (lastKeyNavLetter === letter && lastKeyNavIndex >= 0) {
            startIndex = lastKeyNavIndex + 1
            if (startIndex >= rowCount) startIndex = 0
        }

        var foundIndex = -1
        for (var i = startIndex; i < rowCount; i++) {
            var name = m.data(m.index(i, 0), 257)
            if (name && name.length > 0) {
                var firstChar = name.charAt(0).toLowerCase()
                if (firstChar === letter.toLowerCase()) {
                    foundIndex = i
                    break
                }
            }
        }

        if (foundIndex === -1 && startIndex > 0) {
            for (var j = 0; j < startIndex; j++) {
                var name2 = m.data(m.index(j, 0), 257)
                if (name2 && name2.length > 0) {
                    var firstChar2 = name2.charAt(0).toLowerCase()
                    if (firstChar2 === letter.toLowerCase()) {
                        foundIndex = j
                        break
                    }
                }
            }
        }

        if (foundIndex >= 0) {
            lastKeyNavLetter = letter
            lastKeyNavIndex = foundIndex
            selectedIndices = [foundIndex]
            lastSelectedIndex = foundIndex

            var vm = backend.viewMode
            if (vm === "grid") {
                gridView.positionViewAtIndex(foundIndex, GridView.Contain)
            } else if (vm === "tree") {
                treeList.positionViewAtIndex(foundIndex, ListView.Contain)
            } else {
                listView.positionViewAtIndex(foundIndex, ListView.Contain)
            }
        }
    }

    function saveScrollPositions(path) {
        if (!path) return
        if (!scrollPositions[path]) scrollPositions[path] = {}
        scrollPositions[path]["grid"] = gridView.contentY
        scrollPositions[path]["list"] = listView.contentY
        scrollPositions[path]["tree"] = treeList.contentY
    }

    function restoreScrollPosition(path) {
        if (!path || !scrollPositions[path]) return
        var vm = backend ? backend.viewMode : "list"
        var y = scrollPositions[path][vm]
        if (y !== undefined) {
            if (vm === "grid") gridView.contentY = y
            else if (vm === "tree") treeList.contentY = y
            else listView.contentY = y
        }
    }

    function isSelected(index) { return selectedIndices.indexOf(index) >= 0 }
    function selectIndex(index, addToSelection) {
        if (addToSelection) {
            var idx = selectedIndices.indexOf(index)
            var newSel = selectedIndices.slice()
            if (idx >= 0) {
                newSel.splice(idx, 1)
            } else {
                newSel.push(index)
            }
            selectedIndices = newSel
        } else {
            selectedIndices = [index]
        }
        lastSelectedIndex = index
    }
    function selectRange(start, end) {
        var newSelection = selectedIndices.slice()
        var from = Math.min(start, end)
        var to = Math.max(start, end)
        for (var i = from; i <= to; i++) {
            if (newSelection.indexOf(i) < 0) {
                newSelection.push(i)
            }
        }
        selectedIndices = newSelection
        lastSelectedIndex = end
    }
    function clearSelection() {
        selectedIndices = []
        lastSelectedIndex = -1
    }
    function selectAll() {
        var all = []
        for (var i = 0; i < listView.count; i++) all.push(i)
        selectedIndices = all
        if (all.length > 0) lastSelectedIndex = all[all.length - 1]
    }

    function getSelectedUrlsAsText(draggedPath) {
        var urls = []
        var isDraggedSelected = false
        var m = backend.model
        for (var i = 0; i < selectedIndices.length; i++) {
            var idx = selectedIndices[i]
            var p = m.data(m.index(idx, 0), 267)
            if (p) {
                urls.push("file:///" + p.replace(/\\/g, "/"))
                if (p === draggedPath) isDraggedSelected = true
            }
        }
        if (!isDraggedSelected && draggedPath) {
            urls = ["file:///" + draggedPath.replace(/\\/g, "/")]
        }
        return urls.join("\r\n")
    }

    function getSelectedNames() {
        var names = []
        var m = backend.model
        for (var i = 0; i < selectedIndices.length; i++) {
            var n = m.data(m.index(selectedIndices[i], 0), 257)
            if (n) names.push(n)
        }
        return names
    }

    function getSelectedFullPaths() {
        var paths = []
        var m = backend.model
        for (var i = 0; i < selectedIndices.length; i++) {
            var p = m.data(m.index(selectedIndices[i], 0), 267)
            paths.push(p || "")
        }
        return paths
    }

    signal bulkRenameRequested(var names, var paths)

    function getTreeItemYPositions() {
        if (!backend || !backend.model) return []
        var count = treeList.count
        var yPos = []
        var currentY = 0
        var m = backend.model
        for (var i = 0; i < count; i++) {
            yPos.push(currentY)
            var lvl = m.data(m.index(i, 0), 265) || 0
            if (!treeArea.isHidden(i, lvl)) {
                currentY += 32
            }
        }
        return yPos
    }

    function updateDragSelectionBox() {
        var viewMode = backend ? backend.viewMode : "list"
        if (viewMode === "analytics") return
        var view = (viewMode === "grid") ? gridView : ((viewMode === "tree") ? treeList : listView)

        var currentViewportStartX = root.dragStartContentX - view.contentX
        var currentViewportStartY = root.dragStartContentY - view.contentY

        var startInRoot = view.mapToItem(root, currentViewportStartX, currentViewportStartY)
        var curInRoot = view.mapToItem(root, root.dragCurrentViewX, root.dragCurrentViewY)

        selectionBox.x = Math.min(startInRoot.x, curInRoot.x)
        selectionBox.y = Math.min(startInRoot.y, curInRoot.y)
        selectionBox.width = Math.abs(curInRoot.x - startInRoot.x)
        selectionBox.height = Math.abs(curInRoot.y - startInRoot.y)

        root.performDragSelection(root.dragCurrentViewX, root.dragCurrentViewY)
    }

    function performDragSelection(curViewX, curViewY) {
        if (!backend || !backend.model) return
        var viewMode = backend.viewMode
        var view = (viewMode === "grid") ? gridView : ((viewMode === "tree") ? treeList : listView)

        var curContentX = curViewX + view.contentX
        var curContentY = curViewY + view.contentY

        var x1 = Math.min(root.dragStartContentX, curContentX)
        var y1 = Math.min(root.dragStartContentY, curContentY)
        var x2 = Math.max(root.dragStartContentX, curContentX)
        var y2 = Math.max(root.dragStartContentY, curContentY)

        var m = backend.model
        var count = m.rowCount()

        var startSelection = root.dragStartSelection || []
        var selected = startSelection.slice()

        console.log("[DRAG] viewMode:", viewMode, "x1:", x1, "y1:", y1, "x2:", x2, "y2:", y2, "count:", count)

        if (viewMode === "grid") {
            var cols = Math.floor(gridView.width / gridView.cellWidth) || 1
            var cw = gridView.cellWidth
            var ch = gridView.cellHeight

            for (var i = 0; i < count; i++) {
                var col = i % cols
                var row = Math.floor(i / cols)
                var itemX = col * cw
                var itemY = row * ch

                var intersect = (itemX < x2 && itemX + cw > x1 &&
                                 itemY < y2 && itemY + ch > y1)

                var startIdx = startSelection.indexOf(i)
                if (intersect) {
                    if (startIdx < 0 && selected.indexOf(i) < 0) {
                        selected.push(i)
                    }
                } else {
                    var selIdx = selected.indexOf(i)
                    if (selIdx >= 0 && startIdx < 0) {
                        selected.splice(selIdx, 1)
                    }
                }
            }
        } else if (viewMode === "list") {
            for (var i = 0; i < count; i++) {
                var itemY = i * 36

                var intersect = (0 < x2 && listView.width > x1 &&
                                 itemY < y2 && itemY + 36 > y1)

                var startIdx = startSelection.indexOf(i)
                if (intersect) {
                    if (startIdx < 0 && selected.indexOf(i) < 0) {
                        selected.push(i)
                    }
                } else {
                    var selIdx = selected.indexOf(i)
                    if (selIdx >= 0 && startIdx < 0) {
                        selected.splice(selIdx, 1)
                    }
                }
            }
        } else if (viewMode === "tree") {
            var yPositions = getTreeItemYPositions()
            for (var i = 0; i < count; i++) {
                var lvl = m.data(m.index(i, 0), 265) || 0
                if (treeArea.isHidden(i, lvl)) continue

                var itemY = yPositions[i]
                var itemW = treeList.width

                var intersect = (0 < x2 && itemW > x1 &&
                                 itemY < y2 && itemY + 32 > y1)

                var startIdx = startSelection.indexOf(i)
                if (intersect) {
                    if (startIdx < 0 && selected.indexOf(i) < 0) {
                        selected.push(i)
                    }
                } else {
                    var selIdx = selected.indexOf(i)
                    if (selIdx >= 0 && startIdx < 0) {
                        selected.splice(selIdx, 1)
                    }
                }
            }
        }

        console.log("[DRAG] Final selected array:", JSON.stringify(selected))
        selectedIndices = selected
        if (selected.length > 0) {
            lastSelectedIndex = selected[selected.length - 1]
        }
    }

    function moveSelection(delta, view, shiftModifier) {
        var count = view.count
        if (count === 0) return

        var newIndex = 0
        if (lastSelectedIndex === -1 || selectedIndices.length === 0) {
            newIndex = delta > 0 ? 0 : count - 1
        } else {
            newIndex = lastSelectedIndex + delta
            if (newIndex < 0) newIndex = 0
            if (newIndex >= count) newIndex = count - 1
        }

        if (view === treeList) {
            var m = backend.model
            var attempts = 0
            var direction = delta > 0 ? 1 : -1
            while (newIndex >= 0 && newIndex < count && attempts < count) {
                var lvl = m.data(m.index(newIndex, 0), 265) || 0
                if (!treeArea.isHidden(newIndex, lvl)) {
                    break
                }
                newIndex += direction
                attempts++
            }
            if (newIndex < 0) newIndex = 0
            if (newIndex >= count) newIndex = count - 1
            var finalLvl = m.data(m.index(newIndex, 0), 265) || 0
            if (treeArea.isHidden(newIndex, finalLvl)) {
                return
            }
        }

        if (shiftModifier && lastSelectedIndex >= 0) {
            selectRange(lastSelectedIndex, newIndex)
        } else {
            selectIndex(newIndex, false)
        }
        if (view === gridView) {
            view.positionViewAtIndex(newIndex, GridView.Visible)
        } else {
            view.positionViewAtIndex(newIndex, ListView.Contain)
        }
    }

    property real elapsedSecs: 0
    Behavior on elapsedSecs { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        running: backend && backend.busy
        onTriggered: root.elapsedSecs = backend ? backend.scanProgress.elapsed : 0
    }
    Connections {
        target: backend
        function onBusyChanged() {
            if (backend.busy) {
                root.elapsedSecs = 0
                root.clearSelection()
            }
        }
    }

    DropArea {
        id: bgDropArea
        anchors.fill: parent
        onDropped: function(drop) {
            if (drop.hasUrls && drop.urls.length > 0 && backend && backend.path) {
                backend.handleDrop(drop.urls, backend.path, drop.proposedAction)
                drop.accept()
            }
        }
    }

    Rectangle {
        id: driveRootBanner
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: visible ? 12 : 0
            rightMargin: visible ? 12 : 0
            topMargin: visible ? 12 : 0
            bottomMargin: visible ? 6 : 0
        }
        height: visible ? 52 : 0
        visible: backend && backend.path.length > 0 && backend.isDriveRoot(backend.path) && !backend.forceRecursive
        color: Theme.surface
        border.color: Theme.warn
        border.width: 1
        radius: 8
        clip: true

        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            GlyphIcon {
                name: "warn"
                size: 16
                color: Theme.warn
            }

            Label {
                text: "You are viewing the disk root. Calculating folder sizes recursively can take a long time."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                Layout.fillWidth: true
            }

            Rectangle {
                width: scanBtnLabel.implicitWidth + 24
                height: 30
                radius: 6
                color: scanBtnMa.pressed ? Qt.rgba(1, 0.78, 0.20, 0.40)
                     : scanBtnMa.containsMouse ? Qt.rgba(1, 0.78, 0.20, 0.28) : Qt.rgba(1, 0.78, 0.20, 0.18)
                border.color: Qt.rgba(1, 0.78, 0.20, scanBtnMa.containsMouse ? 0.7 : 0.45); border.width: 1

                Label {
                    id: scanBtnLabel
                    anchors.centerIn: parent
                    text: "Scan Disk"
                    color: Theme.warn
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: scanBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window._pendingPath = backend.path
                        driveRootDialog.open()
                    }
                }
            }
        }
    }

    AnalyticsView {
        id: analyticsArea
        anchors {
            left: parent.left
            right: parent.right
            top: driveRootBanner.bottom
            bottom: parent.bottom
        }
        opacity: (backend && backend.viewMode === "analytics") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
    }

    Item {
        id: gridArea
        anchors {
            left: parent.left
            right: parent.right
            top: driveRootBanner.bottom
            bottom: parent.bottom
        }
        opacity: (backend && backend.viewMode === "grid") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }

        property var expandedPaths: ({})
        property int expandVersion: 0
        property int nextColorIndex: 0
        readonly property var expandPalette: [
            Qt.rgba(0.38, 0.62, 1.00, 1),
            Qt.rgba(0.28, 0.78, 0.56, 1),
            Qt.rgba(0.90, 0.55, 0.18, 1),
            Qt.rgba(0.80, 0.35, 0.80, 1),
            Qt.rgba(0.92, 0.38, 0.38, 1),
            Qt.rgba(0.38, 0.80, 0.80, 1),
            Qt.rgba(0.70, 0.85, 0.25, 1),
            Qt.rgba(0.95, 0.60, 0.35, 1),
        ]

        Connections {
            target: backend ? backend.model : null
            function onModelReset() {
                gridArea.expandedPaths = ({})
                gridArea.nextColorIndex = 0
                gridArea.expandVersion++
            }
        }

        Rectangle {
            id: gridSortBar
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 36
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 6
            visible: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Label {
                    text: "Sort:"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Repeater {
                    model: ["Name", "Size", "Type", "Date"]
                    Rectangle {
                        width: sortLabel.implicitWidth + 16
                        height: 26
                        radius: 4
                        color: {
                            var sortId = modelData.toLowerCase()
                            if (sortId === "name") sortId = "alph"
                            var isActive = (backend && backend.filters && backend.filters.sort_by === sortId)
                            return sortMouse.containsMouse ? (isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : Theme.surfaceHi)
                                 : (isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent")
                        }
                        border.color: {
                            var sortId = modelData.toLowerCase()
                            if (sortId === "name") sortId = "alph"
                            var isActive = (backend && backend.filters && backend.filters.sort_by === sortId)
                            return isActive ? Theme.accent : (sortMouse.containsMouse ? Theme.borderHi : "transparent")
                        }
                        border.width: 1

                        Label {
                            id: sortLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: {
                                var sortId = modelData.toLowerCase()
                                if (sortId === "name") sortId = "alph"
                                var isActive = (backend && backend.filters && backend.filters.sort_by === sortId)
                                return isActive ? Theme.accent : (sortMouse.containsMouse ? Theme.text : Theme.textDim)
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: sortMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var sortId = modelData.toLowerCase()
                                if (sortId === "name") sortId = "alph"
                                var currentSort = backend ? backend.filters.sort_by : "none"
                                if (currentSort === sortId) {
                                    backend.setSortDir(backend.filters.sort_dir === "asc" ? "desc" : "asc")
                                } else {
                                    backend.setSortBy(sortId)
                                    backend.setSortDir("asc")
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: (backend && backend.filters && backend.filters.sort_dir === "desc") ? "↓" : "↑"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        function isExpanded(fullPath) {
            var _v = expandVersion
            return expandedPaths[fullPath] !== undefined
        }

        function expandColor(fullPath) {
            var _v = expandVersion
            var idx = expandedPaths[fullPath]
            if (idx === undefined) return null
            return expandPalette[idx % expandPalette.length]
        }

        function ancestorColor(fullPath) {
            var _v = expandVersion
            if (!fullPath) return null
            var sep1 = fullPath.lastIndexOf("\\")
            var sep2 = fullPath.lastIndexOf("/")
            var sep = Math.max(sep1, sep2)
            while (sep > 0) {
                var par = fullPath.substring(0, sep)
                var idx = expandedPaths[par]
                if (idx !== undefined) return expandPalette[idx % expandPalette.length]
                var s1 = par.lastIndexOf("\\")
                var s2 = par.lastIndexOf("/")
                sep = Math.max(s1, s2)
            }
            return null
        }

        function toggleExpand(fullPath) {
            if (!backend || !fullPath) return
            var ep = expandedPaths
            if (ep[fullPath] !== undefined) {
                backend.collapseFolder(fullPath)
                delete ep[fullPath]
                var prefixA = fullPath + "\\"
                var prefixB = fullPath + "/"
                var keys = Object.keys(ep)
                for (var i = 0; i < keys.length; i++) {
                    var k = keys[i]
                    if (k.indexOf(prefixA) === 0 || k.indexOf(prefixB) === 0) {
                        delete ep[k]
                    }
                }
                expandedPaths = ep
                expandVersion++
            } else {
                backend.expandFolder(fullPath)
            }
        }

        Connections {
            target: backend
            function onExpandFinished(fullPath, rowsAdded) {
                if (rowsAdded > 0) {
                    var ep = gridArea.expandedPaths
                    ep[fullPath] = gridArea.nextColorIndex
                    gridArea.nextColorIndex++
                    gridArea.expandedPaths = ep
                    gridArea.expandVersion++
                }
            }
        }

        GridView {
            id: gridView
            reuseItems: true
            anchors {
                left: parent.left
                right: parent.right
                top: gridSortBar.bottom
                bottom: parent.bottom
                margins: 16
                topMargin: 8
            }
            cellWidth: 140; cellHeight: 160
            model: backend ? backend.model : null
            clip: true
            cacheBuffer: 4800
            boundsBehavior: Flickable.StopAtBounds
            focus: true
            footer: Item { height: 120 }

            WheelHandler {
                onWheel: function(event) {
                    var base = gridScrollAnim.running ? gridScrollAnim.to : gridView.contentY
                    var target = Math.max(0, Math.min(base - event.angleDelta.y * 0.8,
                                                      gridView.contentHeight - gridView.height))
                    gridScrollAnim.stop()
                    gridScrollAnim.from = gridView.contentY
                    gridScrollAnim.to = target
                    gridScrollAnim.start()
                    event.accepted = true
                }
            }
            NumberAnimation {
                id: gridScrollAnim
                target: gridView; property: "contentY"
                duration: 150; easing.type: Easing.OutQuad
            }

            MouseArea {
                id: gridBackgroundMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                propagateComposedEvents: true
                onPressed: function(mouse) {
                    var cell = gridView.contentItem.childAt(mouse.x + gridView.contentX, mouse.y + gridView.contentY)
                    if (cell) {
                        mouse.accepted = false
                    } else {
                        if (mouse.button === Qt.RightButton) {
                            var pos = gridBackgroundMouse.mapToItem(root, mouse.x, mouse.y)
                            emptySpaceContextMenu.x = pos.x
                            emptySpaceContextMenu.y = pos.y
                            emptySpaceContextMenu.open()
                            mouse.accepted = true
                        } else {
                            root.commitActiveEdit()
                            gridView.forceActiveFocus()

                            root.dragActive = true
                            root.dragStartContentX = mouse.x + gridView.contentX
                            root.dragStartContentY = mouse.y + gridView.contentY
                            root.dragCurrentViewX = mouse.x
                            root.dragCurrentViewY = mouse.y

                            var curInRoot = gridBackgroundMouse.mapToItem(root, mouse.x, mouse.y)
                            selectionBox.x = curInRoot.x
                            selectionBox.y = curInRoot.y
                            selectionBox.width = 0
                            selectionBox.height = 0
                            selectionBox.visible = true

                            if (mouse.modifiers & Qt.ControlModifier) {
                                root.dragStartSelection = root.selectedIndices.slice()
                            } else {
                                root.clearSelection()
                                root.dragStartSelection = []
                            }

                            mouse.accepted = true
                        }
                    }
                }
                onPositionChanged: function(mouse) {
                    if (root.dragActive) {
                        root.dragCurrentViewX = mouse.x
                        root.dragCurrentViewY = mouse.y
                        root.updateDragSelectionBox()
                    }
                }
                onReleased: function(mouse) {
                    if (root.dragActive) {
                        root.dragActive = false
                        selectionBox.visible = false
                    }
                }
                onClicked: function(mouse) { mouse.accepted = true }
                onDoubleClicked: function(mouse) { mouse.accepted = true }
                onPressAndHold: function(mouse) { mouse.accepted = true }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6; radius: 3
                    color: parent.pressed ? Theme.accent : Theme.borderHi
                    opacity: parent.active ? 0.9 : 0.5
                }
            }

            DropArea {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 40; z: 100
                onContainsDragChanged: gridAutoScrollUp.running = containsDrag
            }
            DropArea {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40; z: 100
                onContainsDragChanged: gridAutoScrollDown.running = containsDrag
            }
            Timer {
                id: gridAutoScrollUp
                interval: 16; repeat: true
                onTriggered: gridView.contentY = Math.max(0, gridView.contentY - 8)
            }
            Timer {
                id: gridAutoScrollDown
                interval: 16; repeat: true
                onTriggered: gridView.contentY = Math.min(gridView.contentHeight - gridView.height, gridView.contentY + 8)
            }

            Keys.onUpPressed: function(event) {
                var cols = Math.floor(gridView.width / gridView.cellWidth) || 1
                root.moveSelection(-cols, gridView, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onDownPressed: function(event) {
                var cols = Math.floor(gridView.width / gridView.cellWidth) || 1
                root.moveSelection(cols, gridView, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onLeftPressed: function(event) {
                root.moveSelection(-1, gridView, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onRightPressed: function(event) {
                root.moveSelection(1, gridView, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_A) {
                    root.selectAll()
                    event.accepted = true
                } else if (event.key === Qt.Key_F2) {
                    if (root.selectedIndices.length > 1) {
                        root.bulkRenameRequested(root.getSelectedNames(), root.getSelectedFullPaths())
                    } else if (root.selectedIndices.length === 1 && root.lastSelectedIndex >= 0) {
                        root.renameRequestIndex = root.lastSelectedIndex
                    }
                    event.accepted = true
                }
            }

            delegate: Rectangle {
                id: gridItem
                width: 132; height: 152
                property bool isImage: [".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".tif",".heic",".heif",".svg",".ico",".avif",".cr2",".nef",".arw",".orf",".rw2",".dng",".pef",".sr2",".srf",".srw",".raf",".mrw",".nrw",".x3f"].some(function(ext) {
                    return model.name.toLowerCase().endsWith(ext)
                })
                property bool isVideo: [".mp4",".mkv",".avi",".mov",".wmv",".flv",".webm",".m4v",".mpg",".mpeg",".3gp",".ts",".m2ts",".vob",".ogv",".rm",".rmvb",".divx"].some(function(ext) {
                    return model.name.toLowerCase().endsWith(ext)
                })
                property bool isSelected: root.isSelected(index)
                property bool isCut: backend && backend.clipboardCutPaths ? backend.clipboardCutPaths.indexOf(model.fullPath) !== -1 : false
                property bool editMode: false
                property string editName: ""

                Connections {
                    target: root
                    function onRenameRequestIndexChanged() {
                        if (root.renameRequestIndex === index && backend && backend.viewMode === "grid") {
                            gridItem.editName = model.name
                            gridItem.editMode = true
                            root.renameRequestIndex = -1
                        }
                    }
                }

                readonly property color expandRootColor:  gridArea.expandColor(model.fullPath) || "transparent"
                readonly property color expandChildColor: gridArea.ancestorColor(model.fullPath) || "transparent"
                readonly property bool  isExpandRoot:     gridArea.isExpanded(model.fullPath)
                readonly property bool  isExpandChild:    !isExpandRoot && (expandChildColor !== "transparent")

                color: isSelected
                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                       : gridMouse.containsMouse
                         ? Theme.surfaceHi
                         : isExpandRoot
                           ? Qt.rgba(expandRootColor.r,  expandRootColor.g,  expandRootColor.b,  0.22)
                           : isExpandChild
                             ? Qt.rgba(expandChildColor.r, expandChildColor.g, expandChildColor.b, 0.10)
                             : Theme.surface
                radius: 10
                border.color: isSelected
                              ? Theme.accent
                              : isExpandRoot
                                ? Qt.rgba(expandRootColor.r,  expandRootColor.g,  expandRootColor.b,  0.60)
                                : isExpandChild
                                  ? Qt.rgba(expandChildColor.r, expandChildColor.g, expandChildColor.b, 0.35)
                                  : (gridMouse.containsMouse ? Theme.borderHi : Theme.border)
                border.width: isSelected ? 2 : 1

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    opacity: (gridItem.isCut ? 0.55 : 1.0) * (model.isHidden ? 0.45 : 1.0)

                    Rectangle {
                        id: thumbContainer
                        width: 100; height: 100
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 8
                        color: (gridItem.isImage || gridItem.isVideo) ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.04)
                              : Qt.alpha(backend ? backend.extColour(model.name) : Theme.file, 0.15)
                        border.color: (gridItem.isImage || gridItem.isVideo) ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                      : Qt.alpha(backend ? backend.extColour(model.name) : Theme.file, 0.35)
                        border.width: 1

                        GlyphIcon {
                            anchors.centerIn: parent
                            visible: gridItem.isImage && gridThumb.status !== Image.Ready
                            name: "fileTypeImage"
                            size: 28
                            color: Theme.textFaint
                            opacity: 0.4
                        }

                        GlyphIcon {
                            anchors.centerIn: parent
                            visible: gridItem.isVideo && gridVideoThumb.status !== Image.Ready
                            name: "play"
                            size: 28
                            color: Theme.textFaint
                            opacity: 0.4
                        }

                        Image {
                            id: gridThumb
                            anchors.fill: parent
                            anchors.margins: 4
                            source: gridThumbUrl
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(200, 200)
                            smooth: false
                            asynchronous: true
                            cache: true
                            visible: gridItem.isImage
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            property string gridThumbUrl: ""
                            property bool isCached: false
                            Component.onCompleted: {
                                if (gridItem.isImage) {
                                    isCached = thumbnailCache.isCached(model.fullPath)
                                    if (isCached) {
                                        gridThumbUrl = thumbnailCache.get(model.fullPath)
                                    }
                                }
                            }
                            Timer {
                                id: thumbDelay
                                interval: 600
                                running: gridItem.isImage && !parent.isCached && parent.status !== Image.Ready && !parent.gridThumbUrl
                                onTriggered: {
                                    gridThumb.gridThumbUrl = thumbnailCache.get(model.fullPath)
                                }
                            }
                            Connections {
                                target: thumbnailCache
                                function onThumbnailReady(path, url) {
                                    if (path === model.fullPath) {
                                        gridThumb.gridThumbUrl = url
                                    }
                                }
                            }
                        }

                        Image {
                            id: gridVideoThumb
                            anchors.fill: parent
                            anchors.margins: 4
                            source: gridVideoThumbUrl
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(200, 200)
                            smooth: false
                            asynchronous: true
                            cache: true
                            visible: gridItem.isVideo
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            property string gridVideoThumbUrl: ""
                            property bool isCached: false
                            Component.onCompleted: {
                                if (gridItem.isVideo) {
                                    isCached = videoThumbnailCache.isCached(model.fullPath)
                                    if (isCached) {
                                        gridVideoThumbUrl = videoThumbnailCache.get(model.fullPath)
                                    }
                                }
                            }
                            Timer {
                                id: videoThumbDelay
                                interval: 600
                                running: gridItem.isVideo && !parent.isCached && parent.status !== Image.Ready && !parent.gridVideoThumbUrl
                                onTriggered: {
                                    gridVideoThumb.gridVideoThumbUrl = videoThumbnailCache.get(model.fullPath)
                                }
                            }
                            Connections {
                                target: videoThumbnailCache
                                function onThumbnailReady(path, url) {
                                    if (path === model.fullPath) {
                                        gridVideoThumb.gridVideoThumbUrl = url
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            visible: gridItem.isVideo && gridVideoThumb.status === Image.Ready
                            width: 28; height: 28; radius: 14
                            color: Qt.rgba(0, 0, 0, 0.55)
                            GlyphIcon { anchors.centerIn: parent; name: "play"; size: 14; color: "white" }
                        }

                        GlyphIcon {
                            anchors.centerIn: parent
                            visible: !gridItem.isImage && !gridItem.isVideo
                            name: model.isDir ? "folderFill" : (backend ? backend.extIcon(model.name) : "file")
                            size: 36
                            color: model.isDir ? Theme.folder : (backend ? backend.extColour(model.name) : Theme.file)
                        }

                    }

                    Loader {
                        width: 116
                        anchors.horizontalCenter: parent.horizontalCenter
                        sourceComponent: gridItem.editMode ? gridEditNameField : gridDisplayNameText

                        Component {
                            id: gridDisplayNameText
                            Text {
                                text: model.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Component {
                            id: gridEditNameField
                            TextField {
                                id: gridEditField
                                property bool canceling: false
                                text: gridItem.editName
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                horizontalAlignment: TextInput.AlignHCenter
                                background: Rectangle {
                                    color: Theme.bg1
                                    radius: 6
                                    border.color: Theme.accent
                                    border.width: 1
                                }
                                selectByMouse: true
                                Component.onCompleted: Qt.callLater(function() {
                                    gridEditField.forceActiveFocus()
                                    var dot = gridEditField.text.lastIndexOf(".")
                                    if (dot > 0) gridEditField.select(0, dot)
                                    else gridEditField.selectAll()
                                    root.activeEditField = gridEditField
                                })
                                Component.onDestruction: {
                                    if (root.activeEditField === gridEditField) root.activeEditField = null
                                }
                                onAccepted: {
                                    if (text !== model.name) {
                                        backend.renameItem(model.name, text)
                                    }
                                    gridItem.editMode = false
                                }
                                onActiveFocusChanged: {
                                    if (!activeFocus) {
                                        if (!canceling && text !== model.name) {
                                            backend.renameItem(model.name, text)
                                        }
                                        gridItem.editMode = false
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: model.sizeText
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    id: gridChevBtn
                    visible: model.isDir
                    z: 10
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    width: 22; height: 22; radius: 6
                    readonly property color activeColor: gridItem.isExpandRoot
                        ? Qt.rgba(gridItem.expandRootColor.r, gridItem.expandRootColor.g, gridItem.expandRootColor.b, 1)
                        : Qt.rgba(1, 1, 1, 1)
                    color: gridChevMa.containsMouse
                           ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.30)
                           : Qt.rgba(0, 0, 0, 0.40)
                    border.color: gridChevMa.containsMouse
                                  ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.70)
                                  : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    GlyphIcon {
                        anchors.centerIn: parent
                        name: "chevronRight"
                        size: 9
                        color: "white"
                        rotation: gridArea.isExpanded(model.fullPath) ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: gridChevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            mouse.accepted = true
                            gridArea.toggleExpand(model.fullPath)
                        }
                    }

                    ToolTip.visible: gridChevMa.containsMouse
                    ToolTip.text: gridArea.isExpanded(model.fullPath) ? "Collapse" : "Expand"
                    ToolTip.delay: 500
                }

                MouseArea {
                    id: gridMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    drag.target: gridDragItem

                    onPressed: function(mouse) {
                        root.commitActiveEdit()
                        gridView.forceActiveFocus()
                        if (mouse.button === Qt.LeftButton && !(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                            if (!root.isSelected(index)) {
                                root.selectIndex(index, false)
                            }
                        }
                    }

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            if (!root.isSelected(index)) {
                                root.selectIndex(index, false)
                            }
                            gridContextMenu.x = mouse.x
                            gridContextMenu.y = mouse.y
                            gridContextMenu.targetName = model.name
                            gridContextMenu.targetPath = model.fullPath
                            gridContextMenu.targetIsDir = model.isDir
                            gridContextMenu.targetIsArchive = [".rar",".zip",".7z",".tar",".gz",".bz2",".xz",".iso",".cab",".arj",".lzh",".ace",".tar.gz",".tar.bz2",".tar.xz"].some(function(ext) { return model.name.toLowerCase().endsWith(ext) })
                            gridContextMenu.selectedArchives = root._selectedArchivePaths()
                            gridContextMenu.open()
                        } else if (mouse.button === Qt.LeftButton) {
                            if (mouse.modifiers & Qt.ShiftModifier && root.lastSelectedIndex >= 0) {
                                root.selectRange(root.lastSelectedIndex, index)
                            } else if (mouse.modifiers & Qt.ControlModifier) {
                                root.selectIndex(index, true)
                            } else {
                                root.selectIndex(index, false)
                            }
                        }
                    }
                    onDoubleClicked: function() {
                        if (model.isDir) {
                            backend.openItem(model.fullPath)
                        } else {
                            backend.openItem(model.fullPath)
                        }
                    }
                    ToolTip.visible: containsMouse
                    ToolTip.delay:   700
                    ToolTip.text:    model.name + "\n" + model.fullPath
                }

                MouseArea {
                    z: gridMouse.z + 1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 40
                    acceptedButtons: Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            emptySpaceContextMenu.x = gridMouse.mapToItem(root, mouse.x, mouse.y).x
                            emptySpaceContextMenu.y = gridMouse.mapToItem(root, mouse.x, mouse.y).y
                            emptySpaceContextMenu.open()
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    enabled: model.isDir
                    onDropped: function(drop) {
                        if (drop.hasUrls) {
                            backend.handleDrop(drop.urls, model.fullPath, drop.proposedAction)
                            drop.accept()
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.accent
                        opacity: parent.containsDrag ? 0.2 : 0
                        radius: 10
                    }
                }

                Item {
                    id: gridDragItem
                    anchors.fill: parent
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                    Drag.mimeData: { "text/uri-list": root.getSelectedUrlsAsText(model.fullPath) }
                    Binding {
                        target: gridDragItem
                        property: "Drag.active"
                        value: gridMouse.drag.active
                        delayed: true
                    }
                }

                Menu {
                    id: gridContextMenu
                    property string targetName: ""
                    property string targetPath: ""
                    property bool targetIsDir: false
                    property bool targetIsArchive: false
                    property var selectedArchives: []

                    background: Rectangle {
                        color: Theme.surface
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusSm
                        implicitWidth: 200
                    }

                    delegate: MenuItem {
                        id: menuItem
                        implicitWidth: 200
                        implicitHeight: 36

                        contentItem: Text {
                            text: menuItem.text
                            font: menuItem.font
                            color: menuItem.enabled ? Theme.text : Theme.textFaint
                            leftPadding: 12
                            rightPadding: 12
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            color: menuItem.highlighted ? Theme.surfaceHi : "transparent"
                            radius: 4
                            opacity: menuItem.enabled ? 1 : 0.5
                        }
                    }

                    MenuItem {
                        text: "Open"
                        onTriggered: backend.openItem(gridContextMenu.targetPath)
                    }
                    MenuItem {
                        text: "Open File Location"
                        visible: backend && backend.searchText.length > 0
                        height: visible ? implicitHeight : 0
                        onTriggered: {
                            var parentPath = gridContextMenu.targetPath.substring(0, gridContextMenu.targetPath.lastIndexOf("\\"))
                            if (parentPath.length === 0) parentPath = gridContextMenu.targetPath.substring(0, gridContextMenu.targetPath.lastIndexOf("/"))
                            if (parentPath.length > 0) {
                                backend.path = parentPath
                                backend.clearSearch()
                            }
                        }
                    }
                    MenuItem {
                        text: "Run as Administrator"
                        enabled: backend.canRunElevated(gridContextMenu.targetPath)
                        onTriggered: backend.openElevated(gridContextMenu.targetPath)
                    }
                    MenuItem {
                        text: "Open in New Tab"
                        visible: gridContextMenu.targetIsDir
                        height: gridContextMenu.targetIsDir ? implicitHeight : 0
                        onTriggered: tabBar.addTab(gridContextMenu.targetPath)
                    }
                    MenuItem {
                        text: "Preview"
                        onTriggered: previewPane.show(gridContextMenu.targetPath, gridContextMenu.targetName)
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: "Copy"
                        onTriggered: {
                            if (isSelected && root.selectedIndices.length > 1) {
                                var paths = []
                                for (var i = 0; i < root.selectedIndices.length; i++) {
                                    var idx = root.selectedIndices[i]
                                    var path = backend.model.data(backend.model.index(idx, 0), 267)
                                    if (path) paths.push(path)
                                }
                                backend.copyFiles(paths)
                            } else {
                                backend.copyFile(gridContextMenu.targetPath)
                            }
                        }
                    }
                    MenuItem {
                        text: "Cut"
                        onTriggered: {
                            if (isSelected && root.selectedIndices.length > 1) {
                                var paths = []
                                for (var i = 0; i < root.selectedIndices.length; i++) {
                                    var idx = root.selectedIndices[i]
                                    var path = backend.model.data(backend.model.index(idx, 0), 267)
                                    if (path) paths.push(path)
                                }
                                backend.cutFiles(paths)
                            } else {
                                backend.cutFile(gridContextMenu.targetPath)
                            }
                        }
                    }
                    MenuItem {
                        text: "Paste"
                        enabled: backend ? backend.canPaste : false
                        onTriggered: backend.pasteFile()
                    }
                    MenuItem {
                        text: "Copy and Paste"
                        onTriggered: {
                            if (isSelected && root.selectedIndices.length > 1) {
                                var paths = []
                                for (var i = 0; i < root.selectedIndices.length; i++) {
                                    var idx = root.selectedIndices[i]
                                    var path = backend.model.data(backend.model.index(idx, 0), 267)
                                    if (path) paths.push(path)
                                }
                                backend.copyAndPasteMultiple(paths)
                            } else {
                                backend.copyAndPaste(gridContextMenu.targetPath)
                            }
                        }
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: "Rename"
                        enabled: !(isSelected && root.selectedIndices.length > 1)
                        onTriggered: {
                            gridItem.editName = gridContextMenu.targetName
                            gridItem.editMode = true
                        }
                    }
                    MenuItem {
                        text: "Bulk Rename"
                        enabled: isSelected && root.selectedIndices.length > 1
                        onTriggered: root.bulkRenameRequested(root.getSelectedNames(), root.getSelectedFullPaths())
                    }
                    MenuItem {
                        text: "Delete"
                        onTriggered: {
                            if (isSelected && root.selectedIndices.length > 1) {
                                var paths = []
                                for (var i = 0; i < root.selectedIndices.length; i++) {
                                    var idx = root.selectedIndices[i]
                                    var path = backend.model.data(backend.model.index(idx, 0), 267)
                                    if (path) paths.push(path)
                                }
                                backend.deleteFiles(paths)
                                root.clearSelection()
                            } else {
                                backend.deleteFile(gridContextMenu.targetPath)
                            }
                        }
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: backend && backend.isBookmarked(gridContextMenu.targetPath) ? "Unfavourite" : "Favourite"
                        onTriggered: {
                            if (isSelected && root.selectedIndices.length > 1) {
                                var paths = []
                                for (var i = 0; i < root.selectedIndices.length; i++) {
                                    var idx = root.selectedIndices[i]
                                    var path = backend.model.data(backend.model.index(idx, 0), 267)
                                    if (path) paths.push(path)
                                }
                                backend.toggleBookmarks(paths)
                            } else {
                                backend.toggleBookmark(gridContextMenu.targetPath)
                            }
                        }
                    }
                    MenuItem {
                        text: "Reveal in Explorer"
                        onTriggered: backend.revealInExplorer(gridContextMenu.targetPath)
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: "Open with Rename"
                        onTriggered: backend.launchExternalApp(root.prismRenameExe,
                            isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [gridContextMenu.targetPath])
                    }
                    MenuItem {
                        text: "Open with CrossCheck"
                        enabled: gridContextMenu.targetIsDir
                        onTriggered: {
                            var paths = isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [gridContextMenu.targetPath]
                            console.log("CrossCheck triggered, exe:", root.prismCrossCheckExe, "paths:", paths)
                            backend.launchExternalApp(root.prismCrossCheckExe, paths)
                        }
                    }
                    MenuItem {
                        text: "Add to Timestamp"
                        onTriggered: backend.launchExternalApp(root.prismTimestampExe,
                            isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [gridContextMenu.targetPath])
                    }
                    Menu {
                        id: extractMenuGrid
                        title: gridContextMenu.selectedArchives.length > 1 ? "Extract " + gridContextMenu.selectedArchives.length + " archives with" : "Extract here with"
                        enabled: gridContextMenu.targetIsArchive || gridContextMenu.selectedArchives.length > 1
                        opacity: enabled ? 1 : 0
                        height: enabled ? implicitHeight : 0
                        background: Rectangle {
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusSm
                            implicitWidth: 200
                        }
                        delegate: MenuItem {
                            id: extractGridMenuItem
                            implicitWidth: 200
                            implicitHeight: 36
                            contentItem: Text {
                                text: extractGridMenuItem.text
                                font: extractGridMenuItem.font
                                color: extractGridMenuItem.enabled ? Theme.text : Theme.textFaint
                                leftPadding: 12
                                rightPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            background: Rectangle {
                                color: extractGridMenuItem.hovered ? Theme.accent : "transparent"
                                radius: Theme.radiusSm
                            }
                        }
                        MenuItem {
                            text: "7-Zip"
                            onTriggered: {
                                if (gridContextMenu.selectedArchives.length > 1) {
                                    backend.extractArchives(gridContextMenu.selectedArchives, "7z", false)
                                } else {
                                    backend.extractArchive(gridContextMenu.targetPath, "7z")
                                }
                            }
                        }
                        MenuItem {
                            text: "WinRAR"
                            onTriggered: {
                                if (gridContextMenu.selectedArchives.length > 1) {
                                    backend.extractWinRARShell(gridContextMenu.selectedArchives, false)
                                } else {
                                    backend.extractWinRARShell([gridContextMenu.targetPath], false)
                                }
                            }
                        }
                    }
                    Menu {
                        title: gridContextMenu.selectedArchives.length > 1 ? "Extract " + gridContextMenu.selectedArchives.length + " archives and delete with" : "Extract here and delete with"
                        enabled: gridContextMenu.targetIsArchive || gridContextMenu.selectedArchives.length > 1
                        opacity: enabled ? 1 : 0
                        height: enabled ? implicitHeight : 0
                        background: Rectangle {
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusSm
                            implicitWidth: 200
                        }
                        delegate: MenuItem {
                            id: extractDelGridMenuItem
                            implicitWidth: 200
                            implicitHeight: 36
                            contentItem: Text {
                                text: extractDelGridMenuItem.text
                                font: extractDelGridMenuItem.font
                                color: extractDelGridMenuItem.enabled ? Theme.text : Theme.textFaint
                                leftPadding: 12
                                rightPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            background: Rectangle {
                                color: extractDelGridMenuItem.hovered ? Theme.accent : "transparent"
                                radius: Theme.radiusSm
                            }
                        }
                        MenuItem {
                            text: "7-Zip"
                            onTriggered: {
                                if (gridContextMenu.selectedArchives.length > 1) {
                                    backend.extractArchives(gridContextMenu.selectedArchives, "7z", true)
                                } else {
                                    backend.extractArchive(gridContextMenu.targetPath, "7z", true)
                                }
                            }
                        }
                        MenuItem {
                            text: "WinRAR"
                            onTriggered: {
                                if (gridContextMenu.selectedArchives.length > 1) {
                                    backend.extractWinRARShell(gridContextMenu.selectedArchives, true)
                                } else {
                                    backend.extractWinRARShell([gridContextMenu.targetPath], true)
                                }
                            }
                        }
                    }
                    Menu {
                        title: "Add to archive with"
                        background: Rectangle {
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusSm
                            implicitWidth: 200
                        }
                        delegate: MenuItem {
                            id: archiveMenuItem
                            implicitWidth: 200
                            implicitHeight: 36
                            contentItem: Text {
                                text: archiveMenuItem.text
                                font: archiveMenuItem.font
                                color: archiveMenuItem.enabled ? Theme.text : Theme.textFaint
                                leftPadding: 12
                                rightPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            background: Rectangle {
                                color: archiveMenuItem.hovered ? Theme.accent : "transparent"
                                radius: Theme.radiusSm
                            }
                        }
                        MenuItem {
                            text: "7-Zip"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.openWithArchiver(paths, "7z")
                                } else {
                                    backend.openWithArchiver([gridContextMenu.targetPath], "7z")
                                }
                            }
                        }
                        MenuItem {
                            text: "WinRAR"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.openWithArchiver(paths, "winrar")
                                } else {
                                    backend.openWithArchiver([gridContextMenu.targetPath], "winrar")
                                }
                            }
                        }
                    }
                    Menu {
                        title: "Unlock file with"
                        background: Rectangle {
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusSm
                            implicitWidth: 200
                        }
                        delegate: MenuItem {
                            id: unlockMenuItem
                            implicitWidth: 200
                            implicitHeight: 36
                            contentItem: Text {
                                text: unlockMenuItem.text
                                font: unlockMenuItem.font
                                color: unlockMenuItem.enabled ? Theme.text : Theme.textFaint
                                leftPadding: 12
                                rightPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            background: Rectangle {
                                color: unlockMenuItem.hovered ? Theme.accent : "transparent"
                                radius: Theme.radiusSm
                            }
                        }
                        MenuItem {
                            text: "LockHunter"
                            onTriggered: backend.openWithLockHunter(gridContextMenu.targetPath)
                        }
                        MenuItem {
                            text: "IObit Unlocker"
                            onTriggered: backend.openWithIObitUnlocker(gridContextMenu.targetPath)
                        }
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: "Properties"
                        onTriggered: {
                            var p = backend.itemProperties(gridContextMenu.targetName)
                            propsDialog.props = p
                            propsDialog.open()
                        }
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                visible: (gridView.count === 0) && !(backend && backend.busy)
                width: 320; height: emptyGridCol.implicitHeight
                ColumnLayout {
                    id: emptyGridCol
                    anchors.centerIn: parent
                    spacing: 14
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 64; height: 64; radius: 18
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                        GlyphIcon { anchors.centerIn: parent; name: (backend && backend.path.length > 0) ? "filter" : "search"; size: 28; color: Theme.accent }
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: (backend && backend.path.length > 0) ? "No matches" : "Nothing scanned yet"
                        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 280
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: (backend && backend.path.length > 0)
                              ? "Try adjusting or resetting the filters."
                              : "Type a directory in the address bar, or click the folder icon, then press Enter."
                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                    }
                }
            }
        }
    }

    Item {
        id: listArea
        anchors {
            left: parent.left
            right: parent.right
            top: driveRootBanner.bottom
            bottom: parent.bottom
        }
        opacity: (backend && backend.viewMode === "list") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }

        property var expandedPaths: ({})
        property int expandVersion: 0
        property int nextColorIndex: 0
        readonly property var expandPalette: [
            Qt.rgba(0.38, 0.62, 1.00, 1),
            Qt.rgba(0.28, 0.78, 0.56, 1),
            Qt.rgba(0.90, 0.55, 0.18, 1),
            Qt.rgba(0.80, 0.35, 0.80, 1),
            Qt.rgba(0.92, 0.38, 0.38, 1),
            Qt.rgba(0.38, 0.80, 0.80, 1),
            Qt.rgba(0.70, 0.85, 0.25, 1),
            Qt.rgba(0.95, 0.60, 0.35, 1),
        ]

        Connections {
            target: backend ? backend.model : null
            function onModelReset() {
                listArea.expandedPaths = ({})
                listArea.nextColorIndex = 0
                listArea.expandVersion++
            }
        }

        function isExpanded(fullPath) {
            var _v = expandVersion
            return expandedPaths[fullPath] !== undefined
        }

        function expandColor(fullPath) {
            var _v = expandVersion
            var idx = expandedPaths[fullPath]
            if (idx === undefined) return null
            return expandPalette[idx % expandPalette.length]
        }

        function ancestorColor(fullPath) {
            var _v = expandVersion
            if (!fullPath) return null
            var sep1 = fullPath.lastIndexOf("\\")
            var sep2 = fullPath.lastIndexOf("/")
            var sep = Math.max(sep1, sep2)
            while (sep > 0) {
                var par = fullPath.substring(0, sep)
                var idx = expandedPaths[par]
                if (idx !== undefined) return expandPalette[idx % expandPalette.length]
                var s1 = par.lastIndexOf("\\")
                var s2 = par.lastIndexOf("/")
                sep = Math.max(s1, s2)
            }
            return null
        }

        function toggleExpand(fullPath) {
            if (!backend || !fullPath) return
            var ep = expandedPaths
            if (ep[fullPath] !== undefined) {
                backend.collapseFolder(fullPath)
                delete ep[fullPath]
                var prefixA = fullPath + "\\"
                var prefixB = fullPath + "/"
                var keys = Object.keys(ep)
                for (var i = 0; i < keys.length; i++) {
                    var k = keys[i]
                    if (k.indexOf(prefixA) === 0 || k.indexOf(prefixB) === 0) {
                        delete ep[k]
                    }
                }
                expandedPaths = ep
                expandVersion++
            } else {
                backend.expandFolder(fullPath)
            }
        }

        Connections {
            target: backend
            function onExpandFinished(fullPath, rowsAdded) {
                if (rowsAdded > 0) {
                    var ep = listArea.expandedPaths
                    ep[fullPath] = listArea.nextColorIndex
                    listArea.nextColorIndex++
                    listArea.expandedPaths = ep
                    listArea.expandVersion++
                }
            }
        }

        Rectangle {
            id: header
            anchors { left: parent.left; top: parent.top }
            width: root.previewShowing ? parent.width - root.previewWidth : parent.width
            height: 38
            color: Theme.surface

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1; color: Theme.divider
            }

            property string sortKey: (backend && backend.filters) ? (backend.filters.sort_by || "none") : "none"
            property string sortDir: (backend && backend.filters) ? (backend.filters.sort_dir || "asc")  : "asc"

            Connections {
                target: backend
                function onFiltersChanged() {
                    header.sortKey = backend.filters.sort_by || "none"
                    header.sortDir = backend.filters.sort_dir || "asc"
                }
            }

            component HeaderCell: Item {
                id: cell
                property string label: ""
                property string sortId: ""
                property bool   rightAlign: false
                property bool   fillWidth: false
                Layout.preferredWidth: fillWidth ? -1 : implicitWidth
                Layout.fillWidth: fillWidth

                readonly property bool active: header.sortKey === sortId
                readonly property bool asc:    header.sortDir === "asc"
                implicitWidth: cellRow.implicitWidth + 16
                implicitHeight: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: cellMouse.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 2; radius: 1
                        color: Theme.accent
                        visible: cell.active
                        opacity: 0.9
                    }
                }

                Row {
                    id: cellRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:  cell.rightAlign ? undefined : parent.left
                    anchors.right: cell.rightAlign ? parent.right : undefined
                    anchors.leftMargin:  cell.rightAlign ? 0 : 8
                    anchors.rightMargin: cell.rightAlign ? 8 : 0
                    spacing: 4

                    Text {
                        text: cell.label
                        color: cell.active ? Theme.accent : Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1.3
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Canvas {
                        id: arrowCanvas
                        visible: cell.active
                        width: 8; height: 8
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0,0,width,height)
                            ctx.fillStyle = Theme.accent
                            ctx.beginPath()
                            if (cell.asc) {
                                ctx.moveTo(0, 6); ctx.lineTo(4, 1); ctx.lineTo(8, 6)
                            } else {
                                ctx.moveTo(0, 2); ctx.lineTo(4, 7); ctx.lineTo(8, 2)
                            }
                            ctx.closePath(); ctx.fill()
                        }
                        Connections {
                            target: header
                            function onSortDirChanged() { arrowCanvas.requestPaint() }
                            function onSortKeyChanged() { arrowCanvas.requestPaint() }
                        }
                    }
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cell.active) {
                            backend.setSortDir(header.sortDir === "asc" ? "desc" : "asc")
                        } else {
                            backend.setSortBy(cell.sortId)
                            backend.setSortDir("asc")
                        }
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0

                HeaderCell { label: "NAME";    sortId: "name"; Layout.minimumWidth: 460; Layout.maximumWidth: 460 }
                HeaderCell { label: "SIZE";    sortId: "size"; Layout.minimumWidth: 100; Layout.maximumWidth: 100; rightAlign: true }
                HeaderCell { label: "TYPE";    sortId: "type"; Layout.minimumWidth: 110; Layout.maximumWidth: 110 }
                HeaderCell { label: "CREATED"; sortId: "date"; Layout.minimumWidth: 160; Layout.maximumWidth: 160 }
                HeaderCell { label: "PATH";    sortId: "path"; fillWidth: true }
            }
        }

        ListView {
            id: listView
            reuseItems: true
            anchors {
                left: parent.left; right: root.previewShowing ? undefined : parent.right
                top: header.bottom; bottom: parent.bottom
            }
            width: root.previewShowing ? parent.width - root.previewWidth : parent.width
            clip: true
            model: backend ? backend.model : null
            focus: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 1080
            footer: Item { height: 120 }

            WheelHandler {
                onWheel: function(event) {
                    var base = listScrollAnim.running ? listScrollAnim.to : listView.contentY
                    var target = Math.max(0, Math.min(base - event.angleDelta.y * 0.8,
                                                      listView.contentHeight - listView.height))
                    listScrollAnim.stop()
                    listScrollAnim.from = listView.contentY
                    listScrollAnim.to = target
                    listScrollAnim.start()
                    event.accepted = true
                }
            }
            NumberAnimation {
                id: listScrollAnim
                target: listView; property: "contentY"
                duration: 150; easing.type: Easing.OutQuad
            }

            MouseArea {
                id: listBackgroundMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                propagateComposedEvents: true
                onPressed: function(mouse) {
                    var cell = mouse.x < 10 ? null : listView.contentItem.childAt(mouse.x + listView.contentX, mouse.y + listView.contentY)
                    if (cell) {
                        mouse.accepted = false
                    } else {
                        if (mouse.button === Qt.RightButton) {
                            var pos = listBackgroundMouse.mapToItem(root, mouse.x, mouse.y)
                            emptySpaceContextMenu.x = pos.x
                            emptySpaceContextMenu.y = pos.y
                            emptySpaceContextMenu.open()
                            mouse.accepted = true
                        } else {
                            root.commitActiveEdit()
                            listView.forceActiveFocus()

                            root.dragActive = true
                            root.dragStartContentX = mouse.x + listView.contentX
                            root.dragStartContentY = mouse.y + listView.contentY
                            root.dragCurrentViewX = mouse.x
                            root.dragCurrentViewY = mouse.y

                            var curInRoot = listBackgroundMouse.mapToItem(root, mouse.x, mouse.y)
                            selectionBox.x = curInRoot.x
                            selectionBox.y = curInRoot.y
                            selectionBox.width = 0
                            selectionBox.height = 0
                            selectionBox.visible = true

                            if (mouse.modifiers & Qt.ControlModifier) {
                                root.dragStartSelection = root.selectedIndices.slice()
                            } else {
                                root.clearSelection()
                                root.dragStartSelection = []
                            }

                            mouse.accepted = true
                        }
                    }
                }
                onPositionChanged: function(mouse) {
                    if (root.dragActive) {
                        root.dragCurrentViewX = mouse.x
                        root.dragCurrentViewY = mouse.y
                        root.updateDragSelectionBox()
                    }
                }
                onReleased: function(mouse) {
                    if (root.dragActive) {
                        root.dragActive = false
                        selectionBox.visible = false
                    }
                }
                onClicked: function(mouse) { mouse.accepted = true }
                onDoubleClicked: function(mouse) { mouse.accepted = true }
                onPressAndHold: function(mouse) { mouse.accepted = true }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6; radius: 3
                    color: parent.pressed ? Theme.accent : Theme.borderHi
                    opacity: parent.active ? 0.9 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            DropArea {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 40; z: 100
                onContainsDragChanged: listAutoScrollUp.running = containsDrag
            }
            DropArea {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40; z: 100
                onContainsDragChanged: listAutoScrollDown.running = containsDrag
            }
            Timer {
                id: listAutoScrollUp
                interval: 16; repeat: true
                onTriggered: listView.contentY = Math.max(0, listView.contentY - 8)
            }
            Timer {
                id: listAutoScrollDown
                interval: 16; repeat: true
                onTriggered: listView.contentY = Math.min(listView.contentHeight - listView.height, listView.contentY + 8)
            }

            Keys.onUpPressed: function(event) {
                root.moveSelection(-1, listView, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onDownPressed: function(event) {
                root.moveSelection(1, listView, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_A) {
                    root.selectAll()
                    event.accepted = true
                } else if (event.key === Qt.Key_F2) {
                    if (root.selectedIndices.length > 1) {
                        root.bulkRenameRequested(root.getSelectedNames(), root.getSelectedFullPaths())
                    } else if (root.selectedIndices.length === 1 && root.lastSelectedIndex >= 0) {
                        root.renameRequestIndex = root.lastSelectedIndex
                    }
                    event.accepted = true
                }
            }

            delegate: Rectangle {
                id: rowItem
                x: 10
                width: listView.width - 10
                height: 36
                property bool editMode: false
                property string editName: ""

                Connections {
                    target: root
                    function onRenameRequestIndexChanged() {
                        if (root.renameRequestIndex === index && backend && backend.viewMode === "list") {
                            rowItem.editName = model.name
                            rowItem.editMode = true
                            root.renameRequestIndex = -1
                        }
                    }
                }
                property bool isSelected: root.isSelected(index)
                property bool isCut: backend && backend.clipboardCutPaths ? backend.clipboardCutPaths.indexOf(model.fullPath) !== -1 : false

                readonly property color expandRootColor:  listArea.expandColor(model.fullPath) || "transparent"
                readonly property color expandChildColor: listArea.ancestorColor(model.fullPath) || "transparent"
                readonly property bool  isExpandRoot:     listArea.isExpanded(model.fullPath)
                readonly property bool  isExpandChild:    !isExpandRoot && (expandChildColor !== "transparent")

                color: isSelected
                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                       : hover.containsMouse
                         ? Theme.surfaceHi
                         : isExpandRoot
                           ? Qt.rgba(expandRootColor.r, expandRootColor.g, expandRootColor.b, 0.18)
                           : isExpandChild
                             ? Qt.rgba(expandChildColor.r, expandChildColor.g, expandChildColor.b, 0.08)
                             : (index % 2 === 0 ? "transparent" : Theme.surface)

                Rectangle {
                    width: 3; height: parent.height
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                    visible: isSelected
                    scale: isSelected ? 1 : 0
                    transformOrigin: Item.Left
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    drag.target: listDragItem
                    onPressed: function(mouse) {
                        root.commitActiveEdit()
                        listView.forceActiveFocus()
                        if (mouse.button === Qt.LeftButton && !(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                            if (!root.isSelected(index)) {
                                root.selectIndex(index, false)
                            }
                        }
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            if (!root.isSelected(index)) {
                                root.selectIndex(index, false)
                            }
                            contextMenu.x = mouse.x
                            contextMenu.y = mouse.y
                            contextMenu.targetName = model.name
                            contextMenu.targetPath = model.fullPath
                            contextMenu.targetIsDir = model.isDir
                            contextMenu.isImage = [".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".tif",".heic",".heif",".svg",".ico",".avif",".cr2",".nef",".arw",".orf",".rw2",".dng",".pef",".sr2",".srf",".srw",".raf",".mrw",".nrw",".x3f"].some(function(ext) {
                                return model.name.toLowerCase().endsWith(ext)
                            })
                            contextMenu.targetIsArchive = [".rar",".zip",".7z",".tar",".gz",".bz2",".xz",".iso",".cab",".arj",".lzh",".ace",".tar.gz",".tar.bz2",".tar.xz"].some(function(ext) { return model.name.toLowerCase().endsWith(ext) })
                            contextMenu.selectedArchives = root._selectedArchivePaths()
                            contextMenu.open()
                        } else if (mouse.button === Qt.LeftButton) {
                            if ((mouse.modifiers & Qt.ShiftModifier) && root.lastSelectedIndex >= 0) {
                                root.selectRange(root.lastSelectedIndex, index)
                            } else if (mouse.modifiers & Qt.ControlModifier) {
                                root.selectIndex(index, true)
                            } else {
                                root.selectIndex(index, false)
                            }
                        }
                    }
                    onDoubleClicked: function() {
                        if (model.isDir) {
                            backend.openItem(model.fullPath)
                        } else {
                            backend.openItem(model.fullPath)
                        }
                    }

                    ToolTip.visible: containsMouse
                    ToolTip.delay:   700
                    ToolTip.text:    model.name + "\n" + model.fullPath

                    Menu {
                        id: contextMenu
                        property string targetName: ""
                        property string targetPath: ""
                        property bool isImage: false
                        property bool targetIsDir: false
                        property bool targetIsArchive: false
                        property var selectedArchives: []

                        background: Rectangle {
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusSm
                            implicitWidth: 200
                        }

                        delegate: MenuItem {
                            id: listItem
                            implicitWidth: 200
                            implicitHeight: 36

                            contentItem: Text {
                                text: listItem.text
                                font: listItem.font
                                color: listItem.enabled ? Theme.text : Theme.textFaint
                                leftPadding: 12
                                rightPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            background: Rectangle {
                                color: listItem.highlighted ? Theme.surfaceHi : "transparent"
                                radius: 4
                                opacity: listItem.enabled ? 1 : 0.5
                            }
                        }

                        MenuItem {
                            text: "Open"
                            onTriggered: backend.openItem(contextMenu.targetPath)
                        }
                        MenuItem {
                            text: "Open File Location"
                            visible: backend && backend.searchText.length > 0
                            height: visible ? implicitHeight : 0
                            onTriggered: {
                                var parentPath = contextMenu.targetPath.substring(0, contextMenu.targetPath.lastIndexOf("\\"))
                                if (parentPath.length === 0) parentPath = contextMenu.targetPath.substring(0, contextMenu.targetPath.lastIndexOf("/"))
                                if (parentPath.length > 0) {
                                    backend.path = parentPath
                                    backend.clearSearch()
                                }
                            }
                        }
                        MenuItem {
                            text: "Run as Administrator"
                            enabled: backend.canRunElevated(contextMenu.targetPath)
                            onTriggered: backend.openElevated(contextMenu.targetPath)
                        }
                        MenuItem {
                            text: "Open in New Tab"
                            visible: contextMenu.targetIsDir
                            height: contextMenu.targetIsDir ? implicitHeight : 0
                            onTriggered: tabBar.addTab(contextMenu.targetPath)
                        }
                        MenuItem {
                            text: "Preview"
                            onTriggered: previewPane.show(contextMenu.targetPath, contextMenu.targetName)
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Copy"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.copyFiles(paths)
                                } else {
                                    backend.copyFile(contextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Cut"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.cutFiles(paths)
                                } else {
                                    backend.cutFile(contextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Paste"
                            enabled: backend ? backend.canPaste : false
                            onTriggered: backend.pasteFile()
                        }
                        MenuItem {
                            text: "Copy and Paste"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.copyAndPasteMultiple(paths)
                                } else {
                                    backend.copyAndPaste(contextMenu.targetPath)
                                }
                            }
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Rename"
                            enabled: !(isSelected && root.selectedIndices.length > 1)
                            onTriggered: {
                                rowItem.editName = contextMenu.targetName
                                rowItem.editMode = true
                            }
                        }
                        MenuItem {
                            text: "Bulk Rename"
                            enabled: isSelected && root.selectedIndices.length > 1
                            onTriggered: root.bulkRenameRequested(root.getSelectedNames(), root.getSelectedFullPaths())
                        }
                        MenuItem {
                            text: "Delete"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.deleteFiles(paths)
                                    root.clearSelection()
                                } else {
                                    backend.deleteFile(contextMenu.targetPath)
                                }
                            }
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: backend && backend.isBookmarked(contextMenu.targetPath) ? "Unfavourite" : "Favourite"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.toggleBookmarks(paths)
                                } else {
                                    backend.toggleBookmark(contextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Reveal in Explorer"
                            onTriggered: backend.revealInExplorer(contextMenu.targetPath)
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Open with Rename"
                            onTriggered: backend.launchExternalApp(root.prismRenameExe,
                                isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [contextMenu.targetPath])
                        }
                        MenuItem {
                            text: "Open with CrossCheck"
                            enabled: contextMenu.targetIsDir
                            onTriggered: {
                                var paths = isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [contextMenu.targetPath]
                                console.log("CrossCheck triggered (list), exe:", root.prismCrossCheckExe, "paths:", paths)
                                backend.launchExternalApp(root.prismCrossCheckExe, paths)
                            }
                        }
                        MenuItem {
                            text: "Add to Timestamp"
                            onTriggered: backend.launchExternalApp(root.prismTimestampExe,
                                isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [contextMenu.targetPath])
                        }
                        Menu {
                            title: contextMenu.selectedArchives.length > 1 ? "Extract " + contextMenu.selectedArchives.length + " archives with" : "Extract here with"
                            enabled: contextMenu.targetIsArchive || contextMenu.selectedArchives.length > 1
                            opacity: enabled ? 1 : 0
                            height: enabled ? implicitHeight : 0
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radiusSm
                                implicitWidth: 200
                            }
                            delegate: MenuItem {
                                id: extractListMenuItem
                                implicitWidth: 200
                                implicitHeight: 36
                                contentItem: Text {
                                    text: extractListMenuItem.text
                                    font: extractListMenuItem.font
                                    color: extractListMenuItem.enabled ? Theme.text : Theme.textFaint
                                    leftPadding: 12
                                    rightPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: extractListMenuItem.hovered ? Theme.accent : "transparent"
                                    radius: Theme.radiusSm
                                }
                            }
                            MenuItem {
                                text: "7-Zip"
                                onTriggered: {
                                    if (contextMenu.selectedArchives.length > 1) {
                                        backend.extractArchives(contextMenu.selectedArchives, "7z", false)
                                    } else {
                                        backend.extractArchive(contextMenu.targetPath, "7z")
                                    }
                                }
                            }
                            MenuItem {
                                text: "WinRAR"
                                onTriggered: {
                                    if (contextMenu.selectedArchives.length > 1) {
                                        backend.extractWinRARShell(contextMenu.selectedArchives, false)
                                    } else {
                                        backend.extractWinRARShell([contextMenu.targetPath], false)
                                    }
                                }
                            }
                        }
                        Menu {
                            title: contextMenu.selectedArchives.length > 1 ? "Extract " + contextMenu.selectedArchives.length + " archives and delete with" : "Extract here and delete with"
                            enabled: contextMenu.targetIsArchive || contextMenu.selectedArchives.length > 1
                            opacity: enabled ? 1 : 0
                            height: enabled ? implicitHeight : 0
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radiusSm
                                implicitWidth: 200
                            }
                            delegate: MenuItem {
                                id: extractDelListMenuItem
                                implicitWidth: 200
                                implicitHeight: 36
                                contentItem: Text {
                                    text: extractDelListMenuItem.text
                                    font: extractDelListMenuItem.font
                                    color: extractDelListMenuItem.enabled ? Theme.text : Theme.textFaint
                                    leftPadding: 12
                                    rightPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: extractDelListMenuItem.hovered ? Theme.accent : "transparent"
                                    radius: Theme.radiusSm
                                }
                            }
                            MenuItem {
                                text: "7-Zip"
                                onTriggered: {
                                    if (contextMenu.selectedArchives.length > 1) {
                                        backend.extractArchives(contextMenu.selectedArchives, "7z", true)
                                    } else {
                                        backend.extractArchive(contextMenu.targetPath, "7z", true)
                                    }
                                }
                            }
                            MenuItem {
                                text: "WinRAR"
                                onTriggered: {
                                    if (contextMenu.selectedArchives.length > 1) {
                                        backend.extractWinRARShell(contextMenu.selectedArchives, true)
                                    } else {
                                        backend.extractWinRARShell([contextMenu.targetPath], true)
                                    }
                                }
                            }
                        }
                        Menu {
                            title: "Add to archive with"
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radiusSm
                                implicitWidth: 200
                            }
                            delegate: MenuItem {
                                id: archiveMenuItemList
                                implicitWidth: 200
                                implicitHeight: 36
                                contentItem: Text {
                                    text: archiveMenuItemList.text
                                    font: archiveMenuItemList.font
                                    color: archiveMenuItemList.enabled ? Theme.text : Theme.textFaint
                                    leftPadding: 12
                                    rightPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: archiveMenuItemList.hovered ? Theme.accent : "transparent"
                                    radius: Theme.radiusSm
                                }
                            }
                            MenuItem {
                                text: "7-Zip"
                                onTriggered: {
                                    if (isSelected && root.selectedIndices.length > 1) {
                                        var paths = []
                                        for (var i = 0; i < root.selectedIndices.length; i++) {
                                            var idx = root.selectedIndices[i]
                                            var path = backend.model.data(backend.model.index(idx, 0), 267)
                                            if (path) paths.push(path)
                                        }
                                        backend.openWithArchiver(paths, "7z")
                                    } else {
                                        backend.openWithArchiver([contextMenu.targetPath], "7z")
                                    }
                                }
                            }
                            MenuItem {
                                text: "WinRAR"
                                onTriggered: {
                                    if (isSelected && root.selectedIndices.length > 1) {
                                        var paths = []
                                        for (var i = 0; i < root.selectedIndices.length; i++) {
                                            var idx = root.selectedIndices[i]
                                            var path = backend.model.data(backend.model.index(idx, 0), 267)
                                            if (path) paths.push(path)
                                        }
                                        backend.openWithArchiver(paths, "winrar")
                                    } else {
                                        backend.openWithArchiver([contextMenu.targetPath], "winrar")
                                    }
                                }
                            }
                        }
                        Menu {
                            title: "Unlock file with"
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radiusSm
                                implicitWidth: 200
                            }
                            delegate: MenuItem {
                                id: unlockMenuItemList
                                implicitWidth: 200
                                implicitHeight: 36
                                contentItem: Text {
                                    text: unlockMenuItemList.text
                                    font: unlockMenuItemList.font
                                    color: unlockMenuItemList.enabled ? Theme.text : Theme.textFaint
                                    leftPadding: 12
                                    rightPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: unlockMenuItemList.hovered ? Theme.accent : "transparent"
                                    radius: Theme.radiusSm
                                }
                            }
                            MenuItem {
                                text: "LockHunter"
                                onTriggered: backend.openWithLockHunter(contextMenu.targetPath)
                            }
                            MenuItem {
                                text: "IObit Unlocker"
                                onTriggered: backend.openWithIObitUnlocker(contextMenu.targetPath)
                            }
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Properties"
                            onTriggered: {
                                var p = backend.itemProperties(contextMenu.targetName)
                                propsDialog.props = p
                                propsDialog.open()
                            }
                        }
                    }

                    Keys.onSpacePressed: {
                        if (!model.isDir) {
                            previewPane.show(model.fullPath, model.name)
                        }
                    }
                    Keys.onReturnPressed: backend.openItem(model.fullPath)
                    Keys.onPressed: {
                        if (event.key === Qt.Key_F2) {
                            rowItem.editName = model.name
                            rowItem.editMode = true
                            event.accepted = true
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    enabled: model.isDir
                    onDropped: function(drop) {
                        if (drop.hasUrls) {
                            backend.handleDrop(drop.urls, model.fullPath, drop.proposedAction)
                            drop.accept()
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.accent
                        opacity: parent.containsDrag ? 0.2 : 0
                        radius: 4
                    }
                }

                MouseArea {
                    z: hover.z + 1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 40
                    acceptedButtons: Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            emptySpaceContextMenu.x = hover.mapToItem(root, mouse.x, mouse.y).x
                            emptySpaceContextMenu.y = hover.mapToItem(root, mouse.x, mouse.y).y
                            emptySpaceContextMenu.open()
                        }
                    }
                }

                Item {
                    id: listDragItem
                    anchors.fill: parent
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                    Drag.mimeData: { "text/uri-list": root.getSelectedUrlsAsText(model.fullPath) }
                    Binding {
                        target: listDragItem
                        property: "Drag.active"
                        value: hover.drag.active
                        delayed: true
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 0
                    opacity: (rowItem.isCut ? 0.55 : 1.0) * (model.isHidden ? 0.45 : 1.0)

                    Item {
                        Layout.minimumWidth: 460; Layout.maximumWidth: 460
                        height: parent.height
                        clip: true

                        readonly property int rowIndentW: 16
                        readonly property int rowLevel: model.level || 0
                        readonly property bool rowExpanded: model.isDir === true && listArea.isExpanded(model.fullPath) === true

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8 + parent.rowLevel * parent.rowIndentW
                            anchors.right: parent.right; anchors.rightMargin: 4
                            spacing: 4

                            Item {
                                width: 18; height: 18
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    visible: model.isDir
                                    color: chevMa.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"

                                    GlyphIcon {
                                        anchors.centerIn: parent
                                        name: "chevronRight"
                                        size: 10
                                        color: chevMa.containsMouse ? Theme.text : Theme.textDim
                                        rotation: listArea.isExpanded(model.fullPath) ? 90 : 0
                                        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        id: chevMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function(mouse) {
                                            mouse.accepted = true
                                            listArea.toggleExpand(model.fullPath)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                property string extC: backend ? backend.extColour(model.name) : "#668888"
                                color: model.isDir
                                       ? (model.level === 0 ? Qt.rgba(0.96,0.72,0.38,0.18) : Qt.rgba(0.40,0.69,1.00,0.18))
                                       : Qt.alpha(extC, 0.18)
                                GlyphIcon {
                                    anchors.centerIn: parent
                                    name: model.isDir ? "folderFill" : (backend ? backend.extIcon(model.name) : "file")
                                    size: 16
                                    color: model.isDir
                                           ? (model.level === 0 ? Theme.folder : Theme.subfolder)
                                           : (backend ? backend.extColour(model.name) : Theme.file)
                                }
                            }
                            Text {
                                id: listNameText
                                width: parent.width - 32
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !rowItem.editMode
                                text: model.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: model.isDir ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                            TextField {
                                id: listEditField
                                width: parent.width - 32
                                anchors.verticalCenter: parent.verticalCenter
                                visible: rowItem.editMode
                                property bool canceling: false
                                property bool accepted: false
                                property string originalName: ""
                                text: rowItem.editName
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                background: Rectangle {
                                    color: Theme.bg1
                                    radius: 6
                                    border.color: Theme.accent
                                    border.width: 1
                                }
                                selectByMouse: true
                                onVisibleChanged: {
                                    if (visible) {
                                        listEditField.originalName = rowItem.editName
                                        listEditField.canceling = false
                                        listEditField.accepted = false
                                        Qt.callLater(function() {
                                            listEditField.forceActiveFocus()
                                            var dot = listEditField.text.lastIndexOf(".")
                                            if (dot > 0) listEditField.select(0, dot)
                                            else listEditField.selectAll()
                                            root.activeEditField = listEditField
                                        })
                                    } else {
                                        if (root.activeEditField === listEditField) root.activeEditField = null
                                    }
                                }
                                onAccepted: {
                                    accepted = true
                                    if (text !== originalName) {
                                        backend.renameItem(originalName, text)
                                    }
                                    rowItem.editMode = false
                                }
                                onActiveFocusChanged: {
                                    if (!activeFocus) {
                                        if (!canceling && !accepted && text !== originalName) {
                                            backend.renameItem(originalName, text)
                                        }
                                        rowItem.editMode = false
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.minimumWidth: 100; Layout.maximumWidth: 100
                        height: parent.height
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 8
                            text: model.sizeText
                            color: Theme.textDim
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                    }

                    Item {
                        Layout.minimumWidth: 110; Layout.maximumWidth: 110
                        height: parent.height
                        Rectangle {
                            id: typeChip
                            property color extColor: model.isDir ? Theme.accent : Qt.color(backend ? backend.extColour(model.name) : "#666888")
                            width: typeLabel.implicitWidth + 14; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            color:        model.isDir ? Qt.rgba(0.49,0.36,1.00,0.16) : Qt.rgba(extColor.r, extColor.g, extColor.b, 0.12)
                            border.color: model.isDir ? Qt.rgba(0.49,0.36,1.00,0.32) : Qt.rgba(extColor.r, extColor.g, extColor.b, 0.28)
                            border.width: 1
                            Text {
                                id: typeLabel
                                anchors.centerIn: parent
                                text: model.isDir ? "FOLDER" : (function() {
                                    var dot = model.name.lastIndexOf(".")
                                    return dot >= 0 ? model.name.substring(dot + 1).toUpperCase() : "FILE"
                                })()
                                color: typeChip.extColor
                                font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold
                            }
                        }
                    }

                    Item {
                        Layout.minimumWidth: 160; Layout.maximumWidth: 160
                        height: parent.height
                        clip: true
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8
                            text: model.created
                            color: Theme.textDim
                            font.family: Theme.fontMono; font.pixelSize: 11
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        height: parent.height
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.right: parent.right; anchors.rightMargin: 36
                            text: model.relPath
                            color: Theme.textFaint
                            font.family: Theme.fontFamily; font.pixelSize: 12
                            elide: Text.ElideLeft
                        }

                        Rectangle {
                            id: bookmarkBtn
                            width: 26; height: 26; radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 38
                            property bool starred: backend ? backend.isBookmarked(model.fullPath) : false
                            color: bookmarkMouse.containsMouse
                                   ? Qt.rgba(1.00,0.80,0.20,0.22)
                                   : (starred ? Qt.rgba(1.00,0.80,0.20,0.15) : Qt.rgba(1.00,0.80,0.20,0.07))
                            border.color: Qt.rgba(1.00,0.80,0.20, starred ? 0.6 : (bookmarkMouse.containsMouse ? 0.45 : 0.20))
                            border.width: 1
                            opacity: (hover.containsMouse || bookmarkMouse.containsMouse || starred) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                            Behavior on color   { ColorAnimation  { duration: 100 } }
                            Connections {
                                target: backend
                                function onBookmarksChanged() { bookmarkBtn.starred = backend.isBookmarked(model.fullPath) }
                            }
                            GlyphIcon {
                                anchors.centerIn: parent
                                name: bookmarkBtn.starred ? "star" : "starOutline"
                                size: 12
                                color: "#FFD60A"
                            }
                            MouseArea {
                                id: bookmarkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    backend.toggleBookmark(model.fullPath)
                                }
                            }
                            ToolTip.visible: bookmarkMouse.containsMouse
                            ToolTip.text:    bookmarkBtn.starred ? "Remove bookmark" : "Bookmark"
                            ToolTip.delay:   400
                        }

                        Rectangle {
                            id: revealBtn
                            width: 26; height: 26; radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 6
                            color: revealMouse.containsMouse
                                   ? Qt.rgba(0.49,0.36,1.00,0.22)
                                   : Qt.rgba(0.49,0.36,1.00,0.10)
                            border.color: Qt.rgba(0.49,0.36,1.00, revealMouse.containsMouse ? 0.5 : 0.25)
                            border.width: 1
                            opacity: (hover.containsMouse || revealMouse.containsMouse) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                            Behavior on color   { ColorAnimation  { duration: 100 } }
                            GlyphIcon {
                                anchors.centerIn: parent
                                name: "folder"; size: 12; color: Theme.accent
                            }
                            MouseArea {
                                id: revealMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    backend.revealInExplorer(model.fullPath)
                                }
                            }
                            ToolTip.visible: revealMouse.containsMouse
                            ToolTip.text:    "Reveal in Explorer"
                            ToolTip.delay:   400
                        }
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                visible: (listView.count === 0) && !(backend && backend.busy)
                width: 320; height: emptyCol.implicitHeight
                ColumnLayout {
                    id: emptyCol
                    anchors.centerIn: parent
                    spacing: 14
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 64; height: 64; radius: 18
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                        GlyphIcon { anchors.centerIn: parent; name: (backend && backend.path.length > 0) ? "filter" : "search"; size: 28; color: Theme.accent }
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: (backend && backend.path.length > 0) ? "No matches" : "Nothing scanned yet"
                        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 280
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: (backend && backend.path.length > 0)
                              ? "Try adjusting or resetting the filters."
                              : "Type a directory in the address bar, or click the folder icon, then press Enter."
                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                    }
                }
            }
        }
    }

    Item {
        id: treeArea
        anchors {
            left: parent.left
            right: parent.right
            top: driveRootBanner.bottom
            bottom: parent.bottom
        }
        opacity: (backend && backend.viewMode === "tree") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }

        property var collapsedPaths: ({})
        property int collapseVersion: 0

        Connections {
            target: backend ? backend.model : null
            function onModelReset() {
                treeArea.collapsedPaths = ({})
                treeArea.collapseVersion++
            }
        }

        function toggleCollapse(fullPath) {
            var cp = collapsedPaths
            if (cp[fullPath]) {
                delete cp[fullPath]
            } else {
                cp[fullPath] = true
            }
            collapsedPaths = cp
            collapseVersion++
        }

        function isHidden(idx, lvl) {
            if (lvl === 0) return false
            var _v = collapseVersion
            var m = backend.model
            var needed = lvl - 1
            for (var i = idx - 1; i >= 0; i--) {
                var iLvl = m.data(m.index(i, 0), 265)
                if (iLvl < lvl) {
                    var iPath = m.data(m.index(i, 0), 267)
                    if (collapsedPaths[iPath]) return true
                    lvl = iLvl
                    if (lvl === 0) break
                }
            }
            return false
        }

        Item {
            anchors.centerIn: parent
            visible: (treeList.count === 0) && !(backend && backend.busy)
            width: 320; height: emptyTreeCol.implicitHeight
            ColumnLayout {
                id: emptyTreeCol
                anchors.centerIn: parent
                spacing: 14
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 64; height: 64; radius: 18
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                    GlyphIcon { anchors.centerIn: parent; name: "search"; size: 28; color: Theme.accent }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: (backend && backend.path.length > 0) ? "No matches" : "Nothing scanned yet"
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 280
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: (backend && backend.path.length > 0)
                          ? "Try adjusting or resetting the filters."
                          : "Type a directory in the address bar, or click the folder icon, then press Enter."
                    color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                }
            }
        }

        ListView {
            id: treeList
            reuseItems: true
            anchors {
                left: parent.left; right: root.previewShowing ? undefined : parent.right
                top: parent.top; bottom: parent.bottom
            }
            width: root.previewShowing ? parent.width - root.previewWidth : parent.width
            clip: true
            model: backend ? backend.model : null
            focus: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 800
            footer: Item { height: 120 }

            WheelHandler {
                onWheel: function(event) {
                    var base = treeScrollAnim.running ? treeScrollAnim.to : treeList.contentY
                    var target = Math.max(0, Math.min(base - event.angleDelta.y * 0.8,
                                                      treeList.contentHeight - treeList.height))
                    treeScrollAnim.stop()
                    treeScrollAnim.from = treeList.contentY
                    treeScrollAnim.to = target
                    treeScrollAnim.start()
                    event.accepted = true
                }
            }
            NumberAnimation {
                id: treeScrollAnim
                target: treeList; property: "contentY"
                duration: 150; easing.type: Easing.OutQuad
            }

            MouseArea {
                id: treeBackgroundMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                propagateComposedEvents: true
                onPressed: function(mouse) {
                    var cell = mouse.x < 10 ? null : treeList.contentItem.childAt(mouse.x + treeList.contentX, mouse.y + treeList.contentY)
                    if (cell) {
                        mouse.accepted = false
                    } else {
                        if (mouse.button === Qt.RightButton) {
                            var pos = treeBackgroundMouse.mapToItem(root, mouse.x, mouse.y)
                            emptySpaceContextMenu.x = pos.x
                            emptySpaceContextMenu.y = pos.y
                            emptySpaceContextMenu.open()
                            mouse.accepted = true
                        } else {
                            root.commitActiveEdit()
                            treeList.forceActiveFocus()

                            root.dragActive = true
                            root.dragStartContentX = mouse.x + treeList.contentX
                            root.dragStartContentY = mouse.y + treeList.contentY
                            root.dragCurrentViewX = mouse.x
                            root.dragCurrentViewY = mouse.y

                            var curInRoot = treeBackgroundMouse.mapToItem(root, mouse.x, mouse.y)
                            selectionBox.x = curInRoot.x
                            selectionBox.y = curInRoot.y
                            selectionBox.width = 0
                            selectionBox.height = 0
                            selectionBox.visible = true

                            if (mouse.modifiers & Qt.ControlModifier) {
                                root.dragStartSelection = root.selectedIndices.slice()
                            } else {
                                root.clearSelection()
                                root.dragStartSelection = []
                            }

                            mouse.accepted = true
                        }
                    }
                }
                onPositionChanged: function(mouse) {
                    if (root.dragActive) {
                        root.dragCurrentViewX = mouse.x
                        root.dragCurrentViewY = mouse.y
                        root.updateDragSelectionBox()
                    }
                }
                onReleased: function(mouse) {
                    if (root.dragActive) {
                        root.dragActive = false
                        selectionBox.visible = false
                    }
                }
                onClicked: function(mouse) { mouse.accepted = true }
                onDoubleClicked: function(mouse) { mouse.accepted = true }
                onPressAndHold: function(mouse) { mouse.accepted = true }
            }

            Keys.onUpPressed: function(event) {
                root.moveSelection(-1, treeList, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onDownPressed: function(event) {
                root.moveSelection(1, treeList, event.modifiers & Qt.ShiftModifier)
                event.accepted = true
            }
            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_A) {
                    root.selectAll()
                    event.accepted = true
                } else if (event.key === Qt.Key_F2) {
                    if (root.selectedIndices.length > 1) {
                        root.bulkRenameRequested(root.getSelectedNames(), root.getSelectedFullPaths())
                    } else if (root.selectedIndices.length === 1 && root.lastSelectedIndex >= 0) {
                        root.renameRequestIndex = root.lastSelectedIndex
                    }
                    event.accepted = true
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6; radius: 3
                    color: parent.pressed ? Theme.accent : Theme.borderHi
                    opacity: parent.active ? 0.9 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitHeight: 6; radius: 3
                    color: parent.pressed ? Theme.accent : Theme.borderHi
                    opacity: parent.active ? 0.9 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            delegate: Item {
                readonly property int  lvl:       model.level
                readonly property bool isDir:     model.isDir
                readonly property string fp:      model.fullPath
                readonly property int  indentW:   20
                readonly property int  rowH:      32
                readonly property bool collapsed: isDir && treeArea.collapsedPaths[fp] === true
                readonly property bool hidden:    treeArea.isHidden(index, lvl)
                property bool editMode: false
                property string editName: ""
                property bool isSelected: root.isSelected(index)
                property bool isCut: backend && backend.clipboardCutPaths ? backend.clipboardCutPaths.indexOf(fp) !== -1 : false

                Connections {
                    target: root
                    function onRenameRequestIndexChanged() {
                        if (root.renameRequestIndex === index && backend && backend.viewMode === "tree") {
                            editMode = true
                            editName = model.name
                            root.renameRequestIndex = -1
                        }
                    }
                }

                x: 10
                width:  Math.max(treeList.width - 10,
                                 lvl * indentW + 6 + 22 + 7 + nameText.implicitWidth
                                 + sizeChip.width + 48)
                height: hidden ? 0 : rowH
                opacity: hidden ? 0 : (model.isHidden ? 0.45 : 1.0)
                clip:    true

                Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Repeater {
                    model: lvl
                    Rectangle {
                        x:      index * indentW + 9
                        y:      0
                        width:  1
                        height: rowH
                        color:  "#232840"
                        visible: !parent.hidden
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: lvl * indentW
                    radius: 6
                    color: isSelected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                           : (rowMouse.containsMouse
                              ? (isDir ? Qt.rgba(0.49,0.36,1.00,0.10) : Qt.rgba(0.48,0.84,0.64,0.07))
                              : "transparent")
                }
                Rectangle {
                    width: 3; height: parent.height
                    anchors.left: parent.left
                    anchors.leftMargin: lvl * indentW
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                    visible: isSelected
                    scale: isSelected ? 1 : 0
                    transformOrigin: Item.Left
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }

                DropArea {
                    anchors.fill: parent
                    anchors.leftMargin: lvl * indentW
                    enabled: isDir
                    onDropped: function(drop) {
                        if (drop.hasUrls) {
                            backend.handleDrop(drop.urls, fp, drop.proposedAction)
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

                Item {
                    id: treeDragItem
                    anchors.fill: parent
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                    Drag.mimeData: { "text/uri-list": root.getSelectedUrlsAsText(fp) }
                    Binding {
                        target: treeDragItem
                        property: "Drag.active"
                        value: rowMouse.drag.active
                        delayed: true
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    drag.target: treeDragItem
                    onPressed: function(mouse) {
                        root.commitActiveEdit()
                        treeList.forceActiveFocus()
                        if (mouse.button === Qt.LeftButton && !(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                            if (!root.isSelected(index)) {
                                root.selectIndex(index, false)
                            }
                        }
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            if (!root.isSelected(index)) {
                                root.selectIndex(index, false)
                            }
                            treeContextMenu.x = mouse.x
                            treeContextMenu.y = mouse.y
                            treeContextMenu.targetName = model.name
                            treeContextMenu.targetPath = fp
                            treeContextMenu.targetIsDir = model.isDir
                            treeContextMenu.isImage = [".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".tif",".heic",".heif",".svg",".ico",".avif",".cr2",".nef",".arw",".orf",".rw2",".dng",".pef",".sr2",".srf",".srw",".raf",".mrw",".nrw",".x3f"].some(function(ext) {
                                return model.name.toLowerCase().endsWith(ext)
                            })
                            treeContextMenu.targetIsArchive = [".rar",".zip",".7z",".tar",".gz",".bz2",".xz",".iso",".cab",".arj",".lzh",".ace",".tar.gz",".tar.bz2",".tar.xz"].some(function(ext) { return model.name.toLowerCase().endsWith(ext) })
                            treeContextMenu.selectedArchives = root._selectedArchivePaths()
                            treeContextMenu.open()
                        } else if (mouse.modifiers & Qt.ControlModifier) {
                            root.selectIndex(index, true)
                        } else if ((mouse.modifiers & Qt.ShiftModifier) && root.lastSelectedIndex >= 0) {
                            root.selectRange(root.lastSelectedIndex, index)
                        } else if (isDir) {
                            treeArea.toggleCollapse(fp)
                        } else {
                            root.selectIndex(index, false)
                        }
                    }
                    onDoubleClicked: function() {
                        if (!isDir) {
                            backend.openItem(fp)
                        }
                    }
                    ToolTip.visible: containsMouse && !isDir
                    ToolTip.delay:   700
                    ToolTip.text:    model.name + "\n" + fp

                    Menu {
                        id: treeContextMenu
                        property string targetName: ""
                        property string targetPath: ""
                        property bool isImage: false
                        property var selectedArchives: []
                        property bool targetIsDir: false
                        property bool targetIsArchive: false

                        background: Rectangle {
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusSm
                            implicitWidth: 200
                        }

                        delegate: MenuItem {
                            id: treeItem
                            implicitWidth: 200
                            implicitHeight: 36

                            contentItem: Text {
                                text: treeItem.text
                                font: treeItem.font
                                color: treeItem.enabled ? Theme.text : Theme.textFaint
                                leftPadding: 12
                                rightPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            background: Rectangle {
                                color: treeItem.highlighted ? Theme.surfaceHi : "transparent"
                                radius: 4
                                opacity: treeItem.enabled ? 1 : 0.5
                            }
                        }

                        MenuItem {
                            text: "Open"
                            onTriggered: backend.openItem(treeContextMenu.targetPath)
                        }
                        MenuItem {
                            text: "Open File Location"
                            visible: backend && backend.searchText.length > 0
                            height: visible ? implicitHeight : 0
                            onTriggered: {
                                var parentPath = treeContextMenu.targetPath.substring(0, treeContextMenu.targetPath.lastIndexOf("\\"))
                                if (parentPath.length === 0) parentPath = treeContextMenu.targetPath.substring(0, treeContextMenu.targetPath.lastIndexOf("/"))
                                if (parentPath.length > 0) {
                                    backend.path = parentPath
                                    backend.clearSearch()
                                }
                            }
                        }
                        MenuItem {
                            text: "Open in New Tab"
                            visible: treeContextMenu.targetIsDir
                            height: treeContextMenu.targetIsDir ? implicitHeight : 0
                            onTriggered: tabBar.addTab(treeContextMenu.targetPath)
                        }
                        MenuItem {
                            text: "Preview"
                            onTriggered: previewPane.show(treeContextMenu.targetPath, treeContextMenu.targetName)
                        }
                        MenuItem {
                            text: backend && backend.isBookmarked(treeContextMenu.targetPath) ? "Unfavourite" : "Favourite"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.toggleBookmarks(paths)
                                } else {
                                    backend.toggleBookmark(treeContextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Rename"
                            enabled: !(isSelected && root.selectedIndices.length > 1)
                            onTriggered: {
                                var delegate = parent.parent.parent
                                delegate.editMode = true
                                delegate.editName = treeContextMenu.targetName
                            }
                        }
                        MenuItem {
                            text: "Bulk Rename"
                            enabled: isSelected && root.selectedIndices.length > 1
                            onTriggered: root.bulkRenameRequested(root.getSelectedNames(), root.getSelectedFullPaths())
                        }
                        MenuItem {
                            text: "Reveal in Explorer"
                            onTriggered: backend.revealInExplorer(treeContextMenu.targetPath)
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Open with Rename"
                            onTriggered: backend.launchExternalApp(root.prismRenameExe,
                                isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [treeContextMenu.targetPath])
                        }
                        MenuItem {
                            text: "Open with CrossCheck"
                            enabled: treeContextMenu.targetIsDir
                            onTriggered: {
                                var paths = isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [treeContextMenu.targetPath]
                                console.log("CrossCheck triggered (tree), exe:", root.prismCrossCheckExe, "paths:", paths)
                                backend.launchExternalApp(root.prismCrossCheckExe, paths)
                            }
                        }
                        MenuItem {
                            text: "Add to Timestamp"
                            onTriggered: backend.launchExternalApp(root.prismTimestampExe,
                                isSelected && root.selectedIndices.length > 1 ? root._selectedPaths() : [treeContextMenu.targetPath])
                        }
                        Menu {
                            title: treeContextMenu.selectedArchives.length > 1 ? "Extract " + treeContextMenu.selectedArchives.length + " archives with" : "Extract here with"
                            enabled: treeContextMenu.targetIsArchive || treeContextMenu.selectedArchives.length > 1
                            opacity: enabled ? 1 : 0
                            height: enabled ? implicitHeight : 0
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radiusSm
                                implicitWidth: 200
                            }
                            delegate: MenuItem {
                                id: extractTreeMenuItem
                                implicitWidth: 200
                                implicitHeight: 36
                                contentItem: Text {
                                    text: extractTreeMenuItem.text
                                    font: extractTreeMenuItem.font
                                    color: extractTreeMenuItem.enabled ? Theme.text : Theme.textFaint
                                    leftPadding: 12
                                    rightPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: extractTreeMenuItem.hovered ? Theme.accent : "transparent"
                                    radius: Theme.radiusSm
                                }
                            }
                            MenuItem {
                                text: "7-Zip"
                                onTriggered: {
                                    if (treeContextMenu.selectedArchives.length > 1) {
                                        backend.extractArchives(treeContextMenu.selectedArchives, "7z", false)
                                    } else {
                                        backend.extractArchive(treeContextMenu.targetPath, "7z")
                                    }
                                }
                            }
                            MenuItem {
                                text: "WinRAR"
                                onTriggered: {
                                    if (treeContextMenu.selectedArchives.length > 1) {
                                        backend.extractWinRARShell(treeContextMenu.selectedArchives, false)
                                    } else {
                                        backend.extractWinRARShell([treeContextMenu.targetPath], false)
                                    }
                                }
                            }
                        }
                        Menu {
                            title: treeContextMenu.selectedArchives.length > 1 ? "Extract " + treeContextMenu.selectedArchives.length + " archives and delete with" : "Extract here and delete with"
                            enabled: treeContextMenu.targetIsArchive || treeContextMenu.selectedArchives.length > 1
                            opacity: enabled ? 1 : 0
                            height: enabled ? implicitHeight : 0
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radiusSm
                                implicitWidth: 200
                            }
                            delegate: MenuItem {
                                id: extractDelTreeMenuItem
                                implicitWidth: 200
                                implicitHeight: 36
                                contentItem: Text {
                                    text: extractDelTreeMenuItem.text
                                    font: extractDelTreeMenuItem.font
                                    color: extractDelTreeMenuItem.enabled ? Theme.text : Theme.textFaint
                                    leftPadding: 12
                                    rightPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: extractDelTreeMenuItem.hovered ? Theme.accent : "transparent"
                                    radius: Theme.radiusSm
                                }
                            }
                            MenuItem {
                                text: "7-Zip"
                                onTriggered: {
                                    if (treeContextMenu.selectedArchives.length > 1) {
                                        backend.extractArchives(treeContextMenu.selectedArchives, "7z", true)
                                    } else {
                                        backend.extractArchive(treeContextMenu.targetPath, "7z", true)
                                    }
                                }
                            }
                            MenuItem {
                                text: "WinRAR"
                                onTriggered: {
                                    if (treeContextMenu.selectedArchives.length > 1) {
                                        backend.extractWinRARShell(treeContextMenu.selectedArchives, true)
                                    } else {
                                        backend.extractWinRARShell([treeContextMenu.targetPath], true)
                                    }
                                }
                            }
                        }
                        MenuItem {
                            text: "Add to archive with 7-Zip..."
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.openWithArchiver(paths, "7z")
                                } else {
                                    backend.openWithArchiver([treeContextMenu.targetPath], "7z")
                                }
                            }
                        }
                        MenuItem {
                            text: "Add to archive with WinRAR..."
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.openWithArchiver(paths, "winrar")
                                } else {
                                    backend.openWithArchiver([treeContextMenu.targetPath], "winrar")
                                }
                            }
                        }
                        MenuItem {
                            text: "Copy"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.copyFiles(paths)
                                } else {
                                    backend.copyFile(treeContextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Cut"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.cutFiles(paths)
                                } else {
                                    backend.cutFile(treeContextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Paste"
                            enabled: backend ? backend.canPaste : false
                            onTriggered: backend.pasteFile()
                        }
                        MenuItem {
                            text: "Copy and Paste"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    backend.copyAndPasteMultiple(paths)
                                } else {
                                    backend.copyAndPaste(treeContextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Delete"
                            onTriggered: {
                                if (isSelected && root.selectedIndices.length > 1) {
                                    var paths = []
                                    for (var i = 0; i < root.selectedIndices.length; i++) {
                                        var idx = root.selectedIndices[i]
                                        var path = backend.model.data(backend.model.index(idx, 0), 267)
                                        if (path) paths.push(path)
                                    }
                                    if (paths.length > 0) backend.deleteFiles(paths)
                                    root.clearSelection()
                                } else {
                                    backend.deleteFile(treeContextMenu.targetPath)
                                }
                            }
                        }
                        MenuItem {
                            text: "Properties"
                            onTriggered: {
                                var p = backend.itemProperties(treeContextMenu.targetName)
                                propsDialog.props = p
                                propsDialog.open()
                            }
                        }
                    }

                    Keys.onSpacePressed: {
                        if (!isDir) previewPane.show(fp, model.name)
                    }
                    Keys.onReturnPressed: backend.openItem(fp)
                    Keys.onPressed: {
                        if (event.key === Qt.Key_F2) {
                            parent.editMode = true
                            parent.editName = model.name
                            event.accepted = true
                        }
                    }
                }

                MouseArea {
                    z: rowMouse.z + 1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 40
                    acceptedButtons: Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            emptySpaceContextMenu.x = rowMouse.mapToItem(root, mouse.x, mouse.y).x
                            emptySpaceContextMenu.y = rowMouse.mapToItem(root, mouse.x, mouse.y).y
                            emptySpaceContextMenu.open()
                        }
                    }
                }

                Rectangle {
                    id: treeRevealBtn
                    width: 26; height: 26; radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: 8
                    color: treeRevealMouse.containsMouse
                           ? Qt.rgba(0.49,0.36,1.00,0.22)
                           : Qt.rgba(0.49,0.36,1.00,0.10)
                    border.color: Qt.rgba(0.49,0.36,1.00, treeRevealMouse.containsMouse ? 0.5 : 0.25)
                    border.width: 1
                    opacity: (rowMouse.containsMouse || treeRevealMouse.containsMouse) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                    Behavior on color   { ColorAnimation  { duration: 100 } }
                    GlyphIcon {
                        anchors.centerIn: parent
                        name: "folder"; size: 12; color: Theme.accent
                    }
                    MouseArea {
                        id: treeRevealMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            mouse.accepted = true
                            backend.revealInExplorer(fp)
                        }
                    }
                    ToolTip.visible: treeRevealMouse.containsMouse
                    ToolTip.text:    "Reveal in Explorer"
                    ToolTip.delay:   400
                }

                Rectangle {
                    x:       lvl * indentW + 6
                    width:   3
                    height:  collapsed ? 8 : 16
                    radius:  2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: isDir
                    color:   collapsed ? Theme.textFaint : Theme.accent
                    opacity: rowMouse.containsMouse ? (isCut ? 0.55 : 1.0) : (isCut ? 0.25 : 0.45)
                    Behavior on height  { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on color   { ColorAnimation  { duration: 160 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    ToolTip.visible: rowMouse.containsMouse && isDir
                    ToolTip.text:    collapsed ? "Click to expand" : "Click to collapse"
                    ToolTip.delay:   500
                }

                Rectangle {
                    id: iconBadge
                    x:      lvl * indentW + 16
                    width:  24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    radius: isDir ? (lvl === 0 ? 7 : 5) : 5
                    property string extC: backend ? backend.extColour(model.name) : "#668888"
                    color: isDir
                           ? (lvl === 0 ? Qt.rgba(0.96,0.72,0.38,0.20) : Qt.rgba(0.40,0.69,1.00,0.18))
                           : Qt.alpha(extC, 0.18)
                    border.color: isDir
                           ? (lvl === 0 ? Qt.rgba(0.96,0.72,0.38,0.45) : Qt.rgba(0.40,0.69,1.00,0.35))
                           : Qt.alpha(extC, 0.40)
                    border.width: 1
                    opacity: isCut ? 0.55 : 1.0
                    GlyphIcon {
                        anchors.centerIn: parent
                        name: isDir ? "folderFill" : (backend ? backend.extIcon(model.name) : "file")
                        size: 14
                        color: isDir
                               ? (lvl === 0 ? Theme.folder : Theme.subfolder)
                               : (backend ? backend.extColour(model.name) : Theme.file)
                    }
                }

                Loader {
                    id: nameText
                    x:      iconBadge.x + iconBadge.width + 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200
                    sourceComponent: parent.editMode ? treeEditNameField : treeDisplayNameText
                    opacity: isCut ? 0.55 : 1.0

                    Component {
                        id: treeDisplayNameText
                        Text {
                            text:   model.name
                            color:  isDir ? (lvl === 0 ? Theme.folder : Theme.text) : Theme.textDim
                            font.family:    Theme.fontFamily
                            font.pixelSize: lvl === 0 ? 14 : 13
                            font.weight:    isDir ? Font.DemiBold : Font.Normal
                        }
                    }

                    Component {
                        id: treeEditNameField
                        TextField {
                            id: treeEditField
                            property bool canceling: false
                            text: parent.parent.editName
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: lvl === 0 ? 14 : 13
                            background: Rectangle {
                                color: Theme.bg1
                                radius: 6
                                border.color: Theme.accent
                                border.width: 1
                            }
                            selectByMouse: true
                            Component.onCompleted: Qt.callLater(function() {
                                treeEditField.forceActiveFocus()
                                var dot = treeEditField.text.lastIndexOf(".")
                                if (dot > 0) treeEditField.select(0, dot)
                                else treeEditField.selectAll()
                                root.activeEditField = treeEditField
                            })
                            Component.onDestruction: {
                                if (root.activeEditField === treeEditField) root.activeEditField = null
                            }
                            onAccepted: {
                                if (text !== model.name) {
                                    backend.renameItem(model.name, text)
                                }
                                parent.parent.editMode = false
                            }
                            onActiveFocusChanged: {
                                if (!activeFocus) {
                                    if (!canceling && text !== model.name) {
                                        backend.renameItem(model.name, text)
                                    }
                                    parent.parent.editMode = false
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: typeChip
                    property color extColor: model.isDir ? Theme.accent : Qt.color(backend ? backend.extColour(model.name) : "#666888")
                    x:      nameText.x + nameText.implicitWidth + 10
                    height: 17; width: typeChipLabel.implicitWidth + 10
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 8
                    color:  model.isDir ? Qt.rgba(0.49,0.36,1.00,0.16) : Qt.rgba(extColor.r, extColor.g, extColor.b, 0.12)
                    border.color: model.isDir ? Qt.rgba(0.49,0.36,1.00,0.32) : Qt.rgba(extColor.r, extColor.g, extColor.b, 0.28)
                    border.width: 1
                    visible: !isDir
                    opacity: isCut ? 0.55 : 1.0
                    Text {
                        id: typeChipLabel
                        anchors.centerIn: parent
                        text: (function() {
                            var dot = model.name.lastIndexOf(".")
                            return dot >= 0 ? model.name.substring(dot + 1).toUpperCase() : ""
                        })()
                        color: typeChip.extColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    id: sizeChip
                    x:      typeChip.visible ? typeChip.x + typeChip.width + 6 : nameText.x + nameText.implicitWidth + 10
                    height: 17; width: sizeChipLabel.implicitWidth + 12
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 8
                    color:  Qt.rgba(1,1,1,0.04)
                    border.color: Theme.border; border.width: 1
                    visible: model.sizeText !== "" && model.sizeText !== "—"
                    opacity: isCut ? 0.55 : 1.0
                    Text {
                        id: sizeChipLabel
                        anchors.centerIn: parent
                        text:  model.sizeText
                        color: Theme.textFaint
                        font.family:   Theme.fontMono
                        font.pixelSize: 10
                    }
                }

                Text {
                    anchors.right:          treeRevealBtn.left
                    anchors.rightMargin:    8
                    anchors.verticalCenter: parent.verticalCenter
                    text:    model.created
                    color:   Theme.textFaint
                    font.family:   Theme.fontMono
                    font.pixelSize: 10
                    opacity: (rowMouse.containsMouse && !treeRevealMouse.containsMouse) ? (isCut ? 0.35 : 0.65) : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
        }
    }

    Rectangle {
        id: busyOverlay
        anchors.fill: parent
        color: Qt.rgba(0.043, 0.051, 0.070, 0.60)
        visible: opacity > 0
        opacity: busyOverlay._show ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        property bool _show: false
        property bool wasCanceling: false

        Timer {
            id: busyDebounce
            interval: 500
            onTriggered: busyOverlay._show = (backend && backend.busy && !backend.expandBusy)
        }

        Connections {
            target: backend
            function onBusyChanged() {
                if (backend && backend.busy && !backend.expandBusy) {
                    busyDebounce.restart()
                } else {
                    busyOverlay._show = false
                }
            }
            function onCancelingChanged() {
                if (backend && backend.canceling) {
                    busyOverlay.wasCanceling = true
                }
            }
        }

        onOpacityChanged: {
            if (opacity === 0) {
                wasCanceling = false
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: 300
            spacing: 16

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: backend && backend.busy && !backend.expandBusy
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                visible: backend && !((backend && backend.canceling) || busyOverlay.wasCanceling)
                RowLayout {
                    spacing: 5
                    GlyphIcon { name: "folderFill"; size: 11; color: Theme.folder }
                    Label {
                        text: backend ? backend.scanProgress.folders : "0"
                        color: Theme.text
                        font.family: Theme.fontMono; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                }
                Label { text: "·"; color: Theme.textFaint; font.pixelSize: 13 }
                RowLayout {
                    spacing: 5
                    GlyphIcon { name: "file"; size: 11; color: Theme.file }
                    Label {
                        text: backend ? backend.scanProgress.files : "0"
                        color: Theme.text
                        font.family: Theme.fontMono; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 280
                visible: backend
                text: ((backend && backend.canceling) || busyOverlay.wasCanceling)
                      ? "canceling..."
                      : (backend && backend.scanProgress.current
                         ? backend.scanProgress.current : "Scanning…")
                color: Theme.textFaint
                font.family: Theme.fontFamily; font.pixelSize: 11
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                visible: backend && !((backend && backend.canceling) || busyOverlay.wasCanceling)
                Label {
                    text: Math.floor(root.elapsedSecs) + "s elapsed"
                    color: Theme.textFaint; font.family: Theme.fontMono; font.pixelSize: 10
                }
                Label {
                    visible: backend && backend.scanProgress.rate > 0
                    text: backend ? (backend.scanProgress.rate + " items/s") : ""
                    color: Theme.textFaint; font.family: Theme.fontMono; font.pixelSize: 10
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 200; height: 3; radius: 2
                color: Qt.rgba(1,1,1,0.08)
                clip: true
                Rectangle {
                    id: progressPill
                    width: 60; height: 3; radius: 2
                    color: Theme.accent
                    SequentialAnimation on x {
                        running: busyOverlay.opacity > 0 && !(backend && backend.scanPaused)
                        loops: Animation.Infinite
                        NumberAnimation { from: -60; to: 200; duration: 1100; easing.type: Easing.InOutSine }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                visible: backend && !((backend && backend.canceling) || busyOverlay.wasCanceling)

                Rectangle {
                    width: 90; height: 32; radius: 8
                    color: pauseMa.pressed ? Qt.rgba(1,0.78,0.20,0.30) : Qt.rgba(1,0.78,0.20,0.18)
                    border.color: Qt.rgba(1,0.78,0.20,0.50); border.width: 1
                    opacity: backend && backend.scanPaused ? 1 : 0.85

                    Label {
                        anchors.centerIn: parent
                        text: backend && backend.scanPaused ? "Resume" : "Pause"
                        color: Theme.warn
                        font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: pauseMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.togglePauseScan()
                    }
                }

                Rectangle {
                    width: 90; height: 32; radius: 8
                    color: cancelMa.pressed ? Qt.rgba(1,0.3,0.3,0.25) : Qt.rgba(1,0.3,0.3,0.12)
                    border.color: Qt.rgba(1,0.3,0.3,0.45); border.width: 1

                    Label {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.danger
                        font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.cancelScan()
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: backend && backend.scanPaused
                text: "⏸ PAUSED"
                color: Theme.warn
                font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
            }
        }
    }

    Rectangle {
        id: expandOverlay
        anchors.fill: parent
        color: Qt.rgba(0.043, 0.051, 0.070, 0.45)
        visible: opacity > 0
        opacity: (backend && backend.expandBusy) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: backend && backend.expandBusy
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: backend ? backend.status : "Expanding…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    Popup {
        id: archiveAppDialog
        modal: true
        anchors.centerIn: parent
        width: 360
        height: archiveDialogCol.implicitHeight + 48
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surface
            radius: 14
            border.color: Theme.borderHi
            border.width: 1
        }

        ColumnLayout {
            id: archiveDialogCol
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
                        color: archiveAppMouse.containsMouse ? Theme.surfaceHi : "transparent"
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
                            id: archiveAppMouse
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

    Popup {
        id: propsDialog
        modal: true
        anchors.centerIn: parent
        width: 360
        height: 400
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property var props: ({})

        background: Rectangle {
            color: Theme.surface; radius: 14
            border.color: Theme.borderHi; border.width: 1
        }

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
            anchors.margins: 24
            spacing: 10

            Label {
                text: "Properties"
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: [
                            { label: "Name", key: "name" },
                            { label: "Path", key: "path" },
                            { label: "Size", key: "size_text" },
                            { label: "Created", key: "created" },
                            { label: "Modified", key: "modified" },
                            { label: "Dimensions", key: "image_dims" },
                            { label: "Version", key: "exe_version" },
                            { label: "MD5", key: "md5" },
                            { label: "SHA256", key: "sha256" }
                        ]
                        RowLayout {
                            Layout.fillWidth: true
                            visible: propsDialog.props[modelData.key] !== undefined
                            Label {
                                text: modelData.label + ":"
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: 12
                                Layout.preferredWidth: 80
                            }
                            Label {
                                Layout.fillWidth: true
                                text: propsDialog.props[modelData.key] || ""
                                color: Theme.text
                                font.family: Theme.fontMono; font.pixelSize: 12
                                elide: Text.ElideNone
                                wrapMode: modelData.key === "sha256" ? Text.NoWrap : Text.WrapAnywhere
                                ToolTip.visible: modelData.key === "sha256" && mouseArea.containsMouse
                                ToolTip.text: propsDialog.props[modelData.key] || ""
                                ToolTip.delay: 400
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }
                }
            }

            Item { height: 6 }

            Rectangle {
                Layout.fillWidth: true; height: 32; radius: 8
                color: okMa.pressed ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                border.color: Theme.border; border.width: 1
                Label { anchors.centerIn: parent; text: "OK"; color: Theme.text; font.pixelSize: 12 }
                MouseArea {
                    id: okMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: propsDialog.close()
                }
            }
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 } }
    }

    Window {
        id: fsWindow
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        onVisibilityChanged: function(v) { if (v === Window.FullScreen) focusTimer.restart() }
        onActiveChanged:     { if (active) fsKeyItem.forceActiveFocus() }

        property string currentPath: ""
        property string currentName: ""
        property bool isImage: false
        property bool isText: false
        property bool isVideo: false
        property bool hudVisible: true
        property bool hudSuppressed: false
        property var siblingFiles: []
        property int currentIndex: -1

        readonly property var videoExts: [".mp4",".mkv",".avi",".mov",".wmv",".flv",".webm",".m4v",".mpg",".mpeg",".3gp",".ts",".m2ts",".vob",".ogv",".rm",".rmvb",".divx"]
        readonly property var imageExts: [".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".tif",".heic",".heif",".svg",".ico",".avif",".cr2",".nef",".arw",".orf",".rw2",".dng",".pef",".sr2",".srf",".srw",".raf",".mrw",".nrw",".x3f"]
        readonly property var textExts: []

        function showAtPosition(path, name, seekPos) {
            currentPath = path
            currentName = name
            fsEditName.text = name
            fsEditName.readOnly = true
            var lname = name.toLowerCase()
            isImage = imageExts.some(function(e) { return lname.endsWith(e) })
            isVideo = videoExts.some(function(e) { return lname.endsWith(e) })
            isText = false
            if (isVideo) {
                fsVideoPlayer.loadFile(path)
                if (seekPos > 0) {
                    fsSeekOnLoad = seekPos
                } else {
                    fsVideoPlayer.play()
                }
            } else {
                fsVideoPlayer.stop()
            }
            var allSiblings = backend ? backend.getSiblings(path) : []
            var viewableExts = imageExts.concat(videoExts).concat(textExts)
            siblingFiles = allSiblings.filter(function(f) {
                return viewableExts.some(function(e) { return f.toLowerCase().endsWith(e) })
            })
            currentIndex = siblingFiles.indexOf(name)
            hudVisible = true
            hudSuppressed = false
            hudTimer.restart()
            if (isVideo) {
                fsVideoPlayer.stop()
                fsWindow.visibility = Window.Hidden
                paneVideoPlayer.stop()
                paneVideoPlayer.launchFullscreen(path, seekPos > 0 ? seekPos : 0, siblingFiles, currentIndex)
                return
            }
            fsWindow.visibility = Window.FullScreen
            focusTimer.restart()
            fsVideoPlayer.setTopmost(true)
            fsVideoPlayer.placeBelow(fsWindow.winId)
            placeBelowTimer.restart()
        }

        function show(path, name) {
            showAtPosition(path, name, 0)
        }

        function showWithSiblings(path, name, siblings, idx) {
            showAtPosition(path, name, 0)
            siblingFiles = siblings
            currentIndex = idx
        }

        property real fsSeekOnLoad: -1

        Connections {
            target: fsVideoPlayer
            function onDurationChanged(dur) {
                if (fsWindow.fsSeekOnLoad > 0 && dur > 0) {
                    fsVideoPlayer.seek(fsWindow.fsSeekOnLoad)
                    fsVideoPlayer.play()
                    fsWindow.fsSeekOnLoad = -1
                }
            }
        }

        function hide() {
            fsVideoPlayer.stop()
            fsVideoPlayer.setTopmost(true)
            fsWindow.visibility = Window.Hidden
            currentPath = ""
            currentName = ""
            siblingFiles = []
            currentIndex = -1
        }

        function prevFile() {
            if (currentIndex > 0) {
                currentIndex--
                var newName = siblingFiles[currentIndex]
                var sep = currentPath.indexOf("\\") >= 0 ? "\\" : "/"
                var lastSepIndex = currentPath.lastIndexOf(sep)
                var newPath = currentPath.substring(0, lastSepIndex + 1) + newName
                show(newPath, newName)
            }
        }

        function nextFile() {
            if (currentIndex >= 0 && currentIndex < siblingFiles.length - 1) {
                currentIndex++
                var newName = siblingFiles[currentIndex]
                var sep = currentPath.indexOf("\\") >= 0 ? "\\" : "/"
                var lastSepIndex = currentPath.lastIndexOf(sep)
                var newPath = currentPath.substring(0, lastSepIndex + 1) + newName
                show(newPath, newName)
            }
        }

        function deleteCurrent() {
            if (backend && currentPath) {
                var deletedPath = currentPath
                var deletedName = currentName
                var deletedIndex = currentIndex
                var newSiblings = siblingFiles.filter(function(f) { return f !== deletedName })
                var newIndex = Math.max(0, Math.min(deletedIndex, newSiblings.length - 1))
                if (newSiblings.length === 0) {
                    backend.deleteFile(deletedPath)
                    hide()
                } else {
                    var nextName = newSiblings[newIndex]
                    if (!nextName) { backend.deleteFile(deletedPath); hide(); return }
                    var sep = deletedPath.indexOf("\\") >= 0 ? "\\" : "/"
                    var dir = deletedPath.substring(0, deletedPath.lastIndexOf(sep) + 1)
                    showWithSiblings(dir + nextName, nextName, newSiblings, newIndex)
                    backend.deleteFile(deletedPath)
                }
            }
        }

        function revealInExplorer() {
            if (backend && currentPath) {
                backend.revealInExplorer(currentPath)
            }
        }

        Timer {
            id: hudTimer
            interval: 1000
            onTriggered: { fsWindow.hudVisible = false; fsWindow.hudSuppressed = true; fsKeyItem.forceActiveFocus() }
        }

        Timer {
            id: placeBelowTimer
            interval: 100
            onTriggered: fsVideoPlayer.placeBelow(fsWindow.winId)
        }

        Timer {
            id: focusTimer
            interval: 150
            onTriggered: { fsWindow.raise(); fsWindow.requestActivate(); fsKeyItem.forceActiveFocus() }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            visible: !fsWindow.isVideo
        }

        Item {
            id: fsImageContainer
            anchors.fill: parent
            visible: fsWindow.isImage
            clip: true

            property real imgScale: 1.0
            property real imgX: 0
            property real imgY: 0
            readonly property real minScale: 1.0
            readonly property real maxScale: 32.0

            function resetZoom() {
                imgScale = 1.0
                imgX = 0
                imgY = 0
            }

            Connections {
                target: fsWindow
                function onCurrentPathChanged() { fsImageContainer.resetZoom() }
            }

            Image {
                id: fsImg
                x: fsImageContainer.imgX
                y: fsImageContainer.imgY
                width:  fsImageContainer.width
                height: fsImageContainer.height
                source: (fsWindow.isImage && fsWindow.currentPath) ? thumbnailCache.safeImageUrl(fsWindow.currentPath) : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
                cache: false
                scale: fsImageContainer.imgScale
                transformOrigin: Item.TopLeft

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
                Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
                Behavior on y     { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                drag.target: fsImageContainer.imgScale > 1.0 ? fsImg : undefined
                drag.minimumX: Math.min(0, fsImageContainer.width  - fsImg.width  * fsImageContainer.imgScale)
                drag.maximumX: 0
                drag.minimumY: Math.min(0, fsImageContainer.height - fsImg.height * fsImageContainer.imgScale)
                drag.maximumY: 0
                onPositionChanged: function(mouse) {
                    if (drag.active) {
                        fsImageContainer.imgX = fsImg.x
                        fsImageContainer.imgY = fsImg.y
                    }
                }
                onDoubleClicked: fsImageContainer.resetZoom()
                onWheel: function(wheel) {
                    var factor = wheel.angleDelta.y > 0 ? 1.18 : (1.0 / 1.18)
                    var newScale = Math.max(fsImageContainer.minScale,
                                           Math.min(fsImageContainer.maxScale,
                                                    fsImageContainer.imgScale * factor))
                    if (newScale === fsImageContainer.imgScale) return

                    var cursorX = wheel.x - fsImageContainer.imgX
                    var cursorY = wheel.y - fsImageContainer.imgY
                    var ratio   = newScale / fsImageContainer.imgScale
                    var newX = wheel.x - cursorX * ratio
                    var newY = wheel.y - cursorY * ratio

                    var scaledW = fsImg.width  * newScale
                    var scaledH = fsImg.height * newScale
                    newX = Math.min(0, Math.max(newX, fsImageContainer.width  - scaledW))
                    newY = Math.min(0, Math.max(newY, fsImageContainer.height - scaledH))
                    if (scaledW <= fsImageContainer.width)  newX = 0
                    if (scaledH <= fsImageContainer.height) newY = 0

                    fsImageContainer.imgScale = newScale
                    fsImageContainer.imgX = newX
                    fsImageContainer.imgY = newY
                    wheel.accepted = true
                }
            }
        }

        Rectangle {
            id: fsZoomBadge
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: fsZoomLabel.implicitWidth + 20
            height: 30
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.6)
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
            visible: fsWindow.isImage && fsImageContainer.imgScale > 1.001
            opacity: fsZoomBadgeTimer.running ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }

            Label {
                id: fsZoomLabel
                anchors.centerIn: parent
                text: {
                    var s = fsImageContainer.imgScale
                    return (Math.round(s * 10) / 10).toFixed(1).replace(/\.0$/, "") + "×"
                }
                color: "white"
                font.family: Theme.fontMono
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Timer {
                id: fsZoomBadgeTimer
                interval: 1500
            }

            Connections {
                target: fsImageContainer
                function onImgScaleChanged() {
                    if (fsImageContainer.imgScale > 1.001) fsZoomBadgeTimer.restart()
                }
            }
        }

        MpvVideo {
            id: fsVideoPlayer
            anchors.fill: parent
            visible: false
        }

        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: !fsWindow.isImage && !fsWindow.isVideo

            GlyphIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "file"
                size: 64
                color: Qt.rgba(1,1,1,0.3)
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: fsWindow.currentName
                color: Qt.rgba(1,1,1,0.5)
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
        }

        Item {
            id: fsKeyItem
            anchors.fill: parent
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_F2) {
                    fsWindow.hudVisible = true
                    fsWindow.hudSuppressed = false
                    fsEditName.readOnly = false
                    hudTimer.stop()
                    Qt.callLater(function() {
                        fsEditName.forceActiveFocus()
                        var dot = fsEditName.text.lastIndexOf(".")
                        if (dot > 0) fsEditName.select(0, dot)
                        else fsEditName.selectAll()
                    })
                    event.accepted = true
                }
            }
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                onPressed: function(mouse) { fsKeyItem.forceActiveFocus(); mouse.accepted = false }
                onClicked: fsKeyItem.forceActiveFocus()
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 20
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: function(mouse) {
                var inBottomZone = mouse.y > parent.height - 100
                if (inBottomZone) {
                    if (!fsWindow.hudVisible && !fsWindow.hudSuppressed) {
                        fsWindow.hudVisible = true
                    }
                    if (fsWindow.hudVisible) {
                        hudTimer.stop()
                    }
                } else {
                    fsWindow.hudSuppressed = false
                    if (fsWindow.hudVisible) {
                        hudTimer.restart()
                    }
                }
            }
        }

        Rectangle {
            anchors.top: parent.top; anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 80, 600)
            height: fsWindow.hudVisible ? 0 : 32
            visible: !fsWindow.hudVisible && height > 0
            radius: 6; color: Qt.rgba(0,0,0,0.5); opacity: 0.7
            z: 10
            Label {
                anchors.centerIn: parent; text: fsWindow.currentName
                color: "#ffffff"; font.pixelSize: 12; elide: Text.ElideMiddle; width: parent.width - 20
            }
            Behavior on height { NumberAnimation { duration: 200 } }
        }

        Rectangle {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: hudHint.implicitWidth + 20
            height: fsWindow.hudVisible ? 0 : 24
            visible: !fsWindow.hudVisible && height > 0
            radius: 4; color: Qt.rgba(0,0,0,0.5); opacity: 0.5
            z: 10
            Label { id: hudHint; anchors.centerIn: parent; text: "Move mouse to bottom for controls"; color: "#ffffff"; font.pixelSize: 10 }
            Behavior on height { NumberAnimation { duration: 200 } }
        }

        Rectangle {
            id: fsHudBar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: fsWindow.hudVisible ? 40 : -120
            width: fsWindow.isVideo ? Math.min(fsWindow.width - 80, 720) : fsHudLayout.implicitWidth + 24
            height: fsWindow.isVideo ? 88 : 48
            radius: Theme.radius
            color: Qt.rgba(0.08, 0.09, 0.13, 0.92)
            border.color: Qt.rgba(0.13, 0.16, 0.22, 0.5); border.width: 1
            opacity: fsWindow.hudVisible ? 1 : 0
            visible: opacity > 0.01
            z: 10
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on height { NumberAnimation { duration: 150 } }
            Behavior on width { NumberAnimation { duration: 150 } }

            RowLayout {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.topMargin: 8; anchors.leftMargin: 12; anchors.rightMargin: 12
                height: 28; spacing: 8; visible: fsWindow.isVideo

                Label {
                    text: fsVideoPlayer.playbackState === 1 ? "⏸" : "▶"
                    color: "white"; font.pixelSize: 14
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: fsVideoPlayer.playbackState === 1 ? fsVideoPlayer.pause() : fsVideoPlayer.play() }
                }

                Item {
                    Layout.fillWidth: true; height: 20
                    Rectangle {
                        id: fsSeekTrack
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.right: parent.right
                        height: 4; radius: 2; color: Qt.rgba(1,1,1,0.2)
                        Rectangle {
                            width: fsVideoPlayer.duration > 0 ? (fsVideoPlayer.position / fsVideoPlayer.duration) * parent.width : 0
                            height: parent.height; radius: 2; color: Theme.accent
                        }
                    }
                    Rectangle {
                        id: fsSeekHandle
                        anchors.verticalCenter: parent.verticalCenter
                        x: fsVideoPlayer.duration > 0 ? (fsVideoPlayer.position / fsVideoPlayer.duration) * (parent.width - width) : 0
                        width: 14; height: 14; radius: 7; color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onPressed: function(mouse) { fsVideoPlayer.seek(Math.floor((mouse.x / width) * fsVideoPlayer.duration)) }
                        onPositionChanged: function(mouse) {
                            if (pressed) { var p = Math.max(0, Math.min(mouse.x / width, 1)); fsVideoPlayer.seek(Math.floor(p * fsVideoPlayer.duration)) }
                        }
                    }
                }

                Label {
                    text: {
                        var pos = Math.floor(fsVideoPlayer.position / 1000)
                        var dur = Math.floor(fsVideoPlayer.duration / 1000)
                        var fmt = function(s) { return Math.floor(s/60) + ":" + ("0" + (s%60)).slice(-2) }
                        return fmt(pos) + "/" + fmt(dur)
                    }
                    color: Qt.rgba(1,1,1,0.7); font.pixelSize: 11; font.family: Theme.fontMono
                }
            }

            RowLayout {
                id: fsHudLayout
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 6; anchors.margins: 8; spacing: 4

                Rectangle {
                    width: 36; height: 36; radius: Theme.radiusSm
                    color: prevMa.pressed ? Theme.surfaceHi2 : (prevMa.containsMouse ? Theme.surfaceHi : "transparent")
                    border.color: prevMa.containsMouse ? Theme.borderHi : Theme.border; border.width: 1
                    enabled: fsWindow.currentIndex > 0; opacity: enabled ? 1 : 0.3
                    Behavior on color { ColorAnimation { duration: 100 } }
                    ToolTip.visible: prevMa.containsMouse; ToolTip.text: "Previous (←)"; ToolTip.delay: 300
                    GlyphIcon { anchors.centerIn: parent; name: "back"; size: 12; color: Theme.text }
                    MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fsWindow.prevFile() }
                }

                Rectangle {
                    width: 36; height: 36; radius: Theme.radiusSm
                    color: nextMa.pressed ? Theme.surfaceHi2 : (nextMa.containsMouse ? Theme.surfaceHi : "transparent")
                    border.color: nextMa.containsMouse ? Theme.borderHi : Theme.border; border.width: 1
                    enabled: fsWindow.currentIndex < fsWindow.siblingFiles.length - 1; opacity: enabled ? 1 : 0.3
                    Behavior on color { ColorAnimation { duration: 100 } }
                    ToolTip.visible: nextMa.containsMouse; ToolTip.text: "Next (→)"; ToolTip.delay: 300
                    GlyphIcon { anchors.centerIn: parent; name: "forward"; size: 12; color: Theme.text }
                    MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fsWindow.nextFile() }
                }

                Rectangle { width: 1; height: 24; color: Theme.divider }

                Rectangle {
                    width: 200; height: 36; radius: Theme.radiusSm
                    color: fsEditName.activeFocus ? Qt.rgba(0.11, 0.13, 0.19, 0.9) : Qt.rgba(0.09, 0.11, 0.16, 0.5)
                    border.color: fsEditName.activeFocus ? Theme.accent : Theme.border; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    TextField {
                        id: fsEditName
                        anchors.fill: parent; anchors.margins: 4
                        text: fsWindow.currentName; color: Theme.text
                        font.pixelSize: 11; font.family: Theme.fontFamily
                        background: null; horizontalAlignment: Text.AlignHCenter
                        selectByMouse: true; readOnly: true
                        onAccepted: {
                            if (text !== fsWindow.currentName && text !== "") {
                                var sep = fsWindow.currentPath.indexOf("\\") >= 0 ? "\\" : "/"
                                var lastSep = fsWindow.currentPath.lastIndexOf(sep)
                                var parentPath = fsWindow.currentPath.substring(0, lastSep + 1)
                                var success = backend.renameFile(fsWindow.currentPath, text)
                                if (success) {
                                    fsWindow.currentPath = parentPath + text
                                    fsWindow.currentName = text
                                    fsWindow.siblingFiles = backend ? backend.getSiblings(fsWindow.currentPath) : []
                                    fsWindow.currentIndex = fsWindow.siblingFiles.indexOf(text)
                                } else { text = fsWindow.currentName }
                            }
                            readOnly = true; hudTimer.restart()
                        }
                        onActiveFocusChanged: { if (!activeFocus) { readOnly = true; text = fsWindow.currentName } }
                    }
                    MouseArea {
                        anchors.fill: parent; enabled: fsEditName.readOnly; hoverEnabled: true
                        ToolTip.visible: containsMouse; ToolTip.text: "Click to rename"; ToolTip.delay: 300
                        onClicked: {
                            fsEditName.readOnly = false
                            fsEditName.forceActiveFocus()
                            var dot = fsEditName.text.lastIndexOf(".")
                            if (dot > 0) fsEditName.select(0, dot)
                            else fsEditName.selectAll()
                            hudTimer.stop()
                        }
                    }
                }

                Rectangle { width: 1; height: 24; color: Theme.divider }

                Rectangle {
                    width: 36; height: 36; radius: Theme.radiusSm
                    color: revealMa.pressed ? Theme.surfaceHi2 : (revealMa.containsMouse ? Theme.surfaceHi : "transparent")
                    border.color: revealMa.containsMouse ? Theme.borderHi : Theme.border; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    ToolTip.visible: revealMa.containsMouse; ToolTip.text: "Reveal in Explorer"; ToolTip.delay: 300
                    GlyphIcon { anchors.centerIn: parent; name: "folder"; size: 12; color: Theme.text }
                    MouseArea { id: revealMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fsWindow.revealInExplorer() }
                }

                Rectangle {
                    width: 36; height: 36; radius: Theme.radiusSm
                    color: delMa.pressed ? Qt.rgba(0.6, 0.2, 0.2, 0.8) : (delMa.containsMouse ? Qt.rgba(0.5, 0.15, 0.15, 0.6) : "transparent")
                    border.color: delMa.containsMouse ? Theme.danger : Theme.border; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    ToolTip.visible: delMa.containsMouse; ToolTip.text: "Delete (Del)"; ToolTip.delay: 300
                    GlyphIcon { anchors.centerIn: parent; name: "trash"; size: 12; color: delMa.containsMouse ? Theme.danger : Theme.textDim }
                    MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fsWindow.deleteCurrent() }
                }

                Rectangle {
                    width: 36; height: 36; radius: Theme.radiusSm
                    color: undoMa.pressed ? Qt.rgba(0.2, 0.5, 0.2, 0.8) : (undoMa.containsMouse ? Qt.rgba(0.15, 0.4, 0.15, 0.6) : "transparent")
                    border.color: undoMa.containsMouse ? Theme.success : Theme.border; border.width: 1
                    enabled: backend && backend.canUndo; opacity: enabled ? 1 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    ToolTip.visible: undoMa.containsMouse && enabled; ToolTip.text: "Undo (Ctrl+Z)"; ToolTip.delay: 300
                    GlyphIcon { anchors.centerIn: parent; name: "back"; size: 12; color: undoMa.containsMouse ? Theme.success : Theme.textDim }
                    MouseArea {
                        id: undoMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (enabled) {
                                var restoredPath = backend.undo()
                                if (restoredPath) {
                                    var sep = restoredPath.indexOf("\\") >= 0 ? "\\" : "/"
                                    var lastSep = restoredPath.lastIndexOf(sep)
                                    fsWindow.show(restoredPath, restoredPath.substring(lastSep + 1))
                                }
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 24; color: Theme.divider }

                Rectangle {
                    width: 36; height: 36; radius: Theme.radiusSm
                    color: exitMa.pressed ? Theme.surfaceHi2 : (exitMa.containsMouse ? Theme.surfaceHi : "transparent")
                    border.color: exitMa.containsMouse ? Theme.borderHi : Theme.border; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    ToolTip.visible: exitMa.containsMouse; ToolTip.text: "Exit (Esc)"; ToolTip.delay: 300
                    GlyphIcon { anchors.centerIn: parent; name: "close"; size: 12; color: Theme.text }
                    MouseArea { id: exitMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fsWindow.hide() }
                }
            }
        }
    }

    Rectangle {
        id: previewPane
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: showPreview ? (fullscreen ? parent.width : previewWidth) : 0
        visible: width > 10
        color: Theme.surface
        border.color: Theme.border; border.width: 1
        clip: true
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            propagateComposedEvents: false
            onWheel: function(wheel) { wheel.accepted = true }
        }

        property bool showPreview: false
        property bool fullscreen: false
        property int previewWidth: 380
        property string currentPath: ""
        property string currentName: ""
        property bool isText: false
        property bool isImage: false
        property bool isVideo: false
        property var siblingFiles: []
        property int currentIndex: -1

        readonly property var videoExts: [".mp4",".mkv",".avi",".mov",".wmv",".flv",".webm",".m4v",".mpg",".mpeg",".3gp",".ts",".m2ts",".vob",".ogv",".rm",".rmvb",".divx"]
        readonly property var imageExts: [".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".tif",".heic",".heif",".svg",".ico",".avif",".cr2",".nef",".arw",".orf",".rw2",".dng",".pef",".sr2",".srf",".srw",".raf",".mrw",".nrw",".x3f"]
        readonly property var textExts: []

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        function showWithSiblings(path, name, siblings, idx) {
            show(path, name)
            siblingFiles = siblings
            currentIndex = idx
        }

        function show(path, name) {
            currentPath = path
            currentName = name
            var lname = name.toLowerCase()
            isImage = imageExts.some(function(e) { return lname.endsWith(e) })
            isVideo = videoExts.some(function(e) { return lname.endsWith(e) })
            isText = false
            showPreview = true

            var allSiblings = backend ? backend.getSiblings(path) : []
            var viewableExts = imageExts.concat(videoExts)
            siblingFiles = allSiblings.filter(function(f) {
                return viewableExts.some(function(e) { return f.toLowerCase().endsWith(e) })
            })
            currentIndex = siblingFiles.indexOf(name)

            if (isVideo) {
                paneVideoPlayer.loadFile(path)
                paneVideoPlayer.play()
            } else {
                paneVideoPlayer.stop()
            }
        }

        function hide() {
            paneVideoPlayer.stop()
            showPreview = false
            fullscreen = false
            currentPath = ""
            currentName = ""
            siblingFiles = []
            currentIndex = -1
        }

        function toggleFullscreen() {
            fullscreen = !fullscreen
        }

        function openExclusiveFullscreen() {
            if (previewPane.isVideo) {
                var pos = paneVideoPlayer.getPosition()
                paneVideoPlayer.pause()
                paneVideoPlayer.launchFullscreen(currentPath, pos, previewPane.siblingFiles, previewPane.currentIndex)
            } else if (previewPane.isImage) {
                fsWindow.show(currentPath, currentName)
            }
        }

        Connections {
            target: paneVideoPlayer
            function onPlaylistPositionChanged(newPath, newIndex) {
                var sep = newPath.indexOf("\\") >= 0 ? "\\" : "/"
                var lastSep = newPath.lastIndexOf(sep)
                var newName = newPath.substring(lastSep + 1)
                var lname = newName.toLowerCase()
                var isVid = previewPane.videoExts.some(function(e) { return lname.endsWith(e) })
                if (!isVid) {
                    paneVideoPlayer.quitFullscreen()
                    fsWindow.show(newPath, newName)
                    return
                }
                previewPane.currentIndex = newIndex
                previewPane.currentPath = newPath
                previewPane.currentName = newName
                if (backend) backend.selectFile(newPath)
            }
            function onFullscreenDelete(path) {
                if (backend && path) backend.deleteFile(path)
            }
            function onFullscreenUndo() {
                if (!backend) return
                var restoredPath = backend.undo()
                if (restoredPath) {
                    var sep = restoredPath.indexOf("\\") >= 0 ? "\\" : "/"
                    var lastSep = restoredPath.lastIndexOf(sep)
                    var restoredName = restoredPath.substring(lastSep + 1)
                    if (paneVideoPlayer.fullscreenIsActive()) {
                        paneVideoPlayer.fullscreenLoadFile(restoredPath)
                    } else {
                        previewPane.show(restoredPath, restoredName)
                        paneVideoPlayer.launchFullscreen(restoredPath, 0, previewPane.siblingFiles, previewPane.currentIndex)
                    }
                }
            }
            function onEofReached() {
            }
        }

        function prevFile() {
            if (currentIndex > 0) {
                currentIndex--
                var newName = siblingFiles[currentIndex]
                var sep = currentPath.indexOf("\\") >= 0 ? "\\" : "/"
                var lastSepIndex = currentPath.lastIndexOf(sep)
                var newPath = currentPath.substring(0, lastSepIndex + 1) + newName
                show(newPath, newName)
                if (backend) backend.selectFile(newPath)
            }
        }

        function nextFile() {
            if (currentIndex >= 0 && currentIndex < siblingFiles.length - 1) {
                currentIndex++
                var newName = siblingFiles[currentIndex]
                var sep = currentPath.indexOf("\\") >= 0 ? "\\" : "/"
                var lastSepIndex = currentPath.lastIndexOf(sep)
                var newPath = currentPath.substring(0, lastSepIndex + 1) + newName
                show(newPath, newName)
                if (backend) backend.selectFile(newPath)
            }
        }

        function deleteCurrent() {
            if (backend && currentPath) {
                var deletedPath = currentPath
                var deletedName = currentName
                var deletedIndex = currentIndex
                var newSiblings = siblingFiles.filter(function(f) { return f !== deletedName })
                var newIndex = Math.max(0, Math.min(deletedIndex, newSiblings.length - 1))
                if (newSiblings.length === 0) {
                    backend.deleteFile(deletedPath)
                    hide()
                } else {
                    var nextName = newSiblings[newIndex]
                    if (!nextName) { backend.deleteFile(deletedPath); hide(); return }
                    var sep = deletedPath.indexOf("\\") >= 0 ? "\\" : "/"
                    var dir = deletedPath.substring(0, deletedPath.lastIndexOf(sep) + 1)
                    showWithSiblings(dir + nextName, nextName, newSiblings, newIndex)
                    backend.deleteFile(deletedPath)
                }
            }
        }

        MouseArea {
            id: resizeHandle
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 6
            cursorShape: Qt.SizeHorCursor
            enabled: !previewPane.fullscreen && previewPane.showPreview
            visible: enabled

            property int startX: 0
            property int startWidth: 0

            onPressed: function(mouse) {
                startX = mouse.x
                startWidth = previewPane.width
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var newWidth = startWidth - (mouse.x - startX)
                    previewWidth = Math.max(200, Math.min(800, newWidth))
                }
            }
        }

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: previewPane.isVideo ? 80 : 44
            color: Theme.bg1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        text: previewPane.currentName
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: fsMa.pressed ? Qt.rgba(1,1,1,0.15) : (fsMa.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.06))
                        border.color: Theme.border; border.width: 1
                        GlyphIcon { anchors.centerIn: parent; name: "expand"; size: 12; color: Theme.textDim }
                        ToolTip.visible: fsMa.containsMouse
                        ToolTip.text: "Fill pane (Tab)"
                        ToolTip.delay: 600
                        MouseArea {
                            id: fsMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: previewPane.toggleFullscreen()
                        }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: exFsMa.pressed ? Qt.rgba(1,1,1,0.15) : (exFsMa.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.06))
                        border.color: Theme.border; border.width: 1
                        GlyphIcon { anchors.centerIn: parent; name: "maximize"; size: 12; color: Theme.textDim }
                        ToolTip.visible: exFsMa.containsMouse
                        ToolTip.text: "Fullscreen (F11)"
                        ToolTip.delay: 600
                        MouseArea {
                            id: exFsMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: previewPane.openExclusiveFullscreen()
                        }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: closeMa.pressed ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.06)
                        border.color: Theme.border; border.width: 1
                        GlyphIcon { anchors.centerIn: parent; name: "close"; size: 12; color: Theme.textDim }
                        ToolTip.visible: closeMa.containsMouse
                        ToolTip.text: "Close preview (Esc)"
                        ToolTip.delay: 600
                        MouseArea {
                            id: closeMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: previewPane.hide()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: previewPane.isVideo

                    Rectangle {
                        width: 22; height: 22; radius: 4
                        color: vidPrevMa.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                        GlyphIcon { anchors.centerIn: parent; name: "back"; size: 10; color: Theme.textDim }
                        ToolTip.visible: vidPrevMa.containsMouse
                        ToolTip.text: "Previous file (Down)"
                        ToolTip.delay: 600
                        MouseArea { id: vidPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: previewPane.prevFile() }
                    }

                    Rectangle {
                        width: 26; height: 26; radius: 4
                        color: vidPlayMa.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                        GlyphIcon {
                            anchors.centerIn: parent
                            name: paneVideoPlayer.playbackState === 1 ? "pause" : "play"
                            size: 13
                            color: Theme.textDim
                        }
                        ToolTip.visible: vidPlayMa.containsMouse
                        ToolTip.text: paneVideoPlayer.playbackState === 1 ? "Pause (Space)" : "Play (Space)"
                        ToolTip.delay: 600
                        MouseArea { id: vidPlayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: paneVideoPlayer.togglePause() }
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 4
                        color: vidNextMa.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                        GlyphIcon { anchors.centerIn: parent; name: "forward"; size: 10; color: Theme.textDim }
                        ToolTip.visible: vidNextMa.containsMouse
                        ToolTip.text: "Next file (Up)"
                        ToolTip.delay: 600
                        MouseArea { id: vidNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: previewPane.nextFile() }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 18

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.right: parent.right
                            height: 3; radius: 2; color: Theme.border
                            Rectangle {
                                width: paneVideoPlayer.duration > 0 ? (paneVideoPlayer.position / paneVideoPlayer.duration) * parent.width : 0
                                height: parent.height; radius: 2; color: Theme.accent
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: paneVideoPlayer.duration > 0 ? (paneVideoPlayer.position / paneVideoPlayer.duration) * (parent.width - width) : 0
                            width: 10; height: 10; radius: 5; color: Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(mouse) {
                                paneVideoPlayer.seek(Math.floor((mouse.x / width) * paneVideoPlayer.duration))
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var pos = Math.max(0, Math.min(mouse.x / width, 1))
                                    paneVideoPlayer.seek(Math.floor(pos * paneVideoPlayer.duration))
                                }
                            }
                        }
                    }

                    Label {
                        text: {
                            var pos = Math.floor(paneVideoPlayer.position)
                            var dur = Math.floor(paneVideoPlayer.duration)
                            var fmt = function(s) { return Math.floor(s/60) + ":" + ("0" + (s%60)).slice(-2) }
                            return fmt(pos) + "/" + fmt(dur)
                        }
                        color: Theme.textDim; font.pixelSize: 9; font.family: Theme.fontMono
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 4
                        color: muteMa.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                        GlyphIcon {
                            anchors.centerIn: parent
                            name: paneVideoPlayer.muted ? "speakerMute" : "speaker"
                            size: 11
                            color: paneVideoPlayer.muted ? Theme.accent : Theme.textDim
                        }
                        ToolTip.visible: muteMa.containsMouse
                        ToolTip.text: paneVideoPlayer.muted ? "Unmute (M)" : "Mute (M)"
                        ToolTip.delay: 600
                        MouseArea {
                            id: muteMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: paneVideoPlayer.toggleMute()
                        }
                    }

                    Item {
                        width: 60; height: 18

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.right: parent.right
                            height: 3; radius: 2; color: Theme.border

                            Rectangle {
                                width: (paneVideoPlayer.volume / 100) * parent.width
                                height: parent.height; radius: 2
                                color: paneVideoPlayer.muted ? Theme.textDim : Theme.accent
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.min((paneVideoPlayer.volume / 100) * (parent.width - width), parent.width - width)
                            width: 8; height: 8; radius: 4; color: Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(mouse) {
                                paneVideoPlayer.setVolume(Math.max(0, Math.min(100, (mouse.x / width) * 100)))
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed)
                                    paneVideoPlayer.setVolume(Math.max(0, Math.min(100, (mouse.x / width) * 100)))
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.top: parent.top; anchors.topMargin: previewPane.isVideo ? 80 : 44
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            color: Theme.bg1
            radius: 8

            Item {
                id: paneImageContainer
                anchors.fill: parent
                anchors.margins: 8
                visible: previewPane.isImage
                clip: true

                property real imgScale: 1.0
                property real imgX: 0
                property real imgY: 0
                readonly property real minScale: 1.0
                readonly property real maxScale: 32.0

                function resetZoom() { imgScale = 1.0; imgX = 0; imgY = 0 }

                Connections {
                    target: previewPane
                    function onCurrentPathChanged() { paneImageContainer.resetZoom() }
                }

                Image {
                    id: paneImg
                    x: paneImageContainer.imgX
                    y: paneImageContainer.imgY
                    width:  paneImageContainer.width
                    height: paneImageContainer.height
                    source: (previewPane.isImage && previewPane.currentPath) ? thumbnailCache.safeImageUrl(previewPane.currentPath) : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    cache: false
                    scale: paneImageContainer.imgScale
                    transformOrigin: Item.TopLeft

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
                    Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
                    Behavior on y     { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    drag.target: paneImageContainer.imgScale > 1.0 ? paneImg : undefined
                    drag.minimumX: Math.min(0, paneImageContainer.width  - paneImg.width  * paneImageContainer.imgScale)
                    drag.maximumX: 0
                    drag.minimumY: Math.min(0, paneImageContainer.height - paneImg.height * paneImageContainer.imgScale)
                    drag.maximumY: 0
                    onPositionChanged: function(mouse) {
                        if (drag.active) {
                            paneImageContainer.imgX = paneImg.x
                            paneImageContainer.imgY = paneImg.y
                        }
                    }
                    onDoubleClicked: paneImageContainer.resetZoom()
                    onWheel: function(wheel) {
                        var factor = wheel.angleDelta.y > 0 ? 1.18 : (1.0 / 1.18)
                        var newScale = Math.max(paneImageContainer.minScale,
                                               Math.min(paneImageContainer.maxScale,
                                                        paneImageContainer.imgScale * factor))
                        if (newScale === paneImageContainer.imgScale) return

                        var cursorX = wheel.x - paneImageContainer.imgX
                        var cursorY = wheel.y - paneImageContainer.imgY
                        var ratio   = newScale / paneImageContainer.imgScale
                        var newX = wheel.x - cursorX * ratio
                        var newY = wheel.y - cursorY * ratio

                        var scaledW = paneImg.width  * newScale
                        var scaledH = paneImg.height * newScale
                        newX = Math.min(0, Math.max(newX, paneImageContainer.width  - scaledW))
                        newY = Math.min(0, Math.max(newY, paneImageContainer.height - scaledH))
                        if (scaledW <= paneImageContainer.width)  newX = 0
                        if (scaledH <= paneImageContainer.height) newY = 0

                        paneImageContainer.imgScale = newScale
                        paneImageContainer.imgX = newX
                        paneImageContainer.imgY = newY
                        wheel.accepted = true
                    }
                }
            }

            Rectangle {
                id: paneZoomBadge
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                width: paneZoomLabel.implicitWidth + 16
                height: 24
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                visible: previewPane.isImage && paneImageContainer.imgScale > 1.001
                opacity: paneZoomBadgeTimer.running ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }

                Label {
                    id: paneZoomLabel
                    anchors.centerIn: parent
                    text: {
                        var s = paneImageContainer.imgScale
                        return (Math.round(s * 10) / 10).toFixed(1).replace(/\.0$/, "") + "×"
                    }
                    color: "white"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Timer { id: paneZoomBadgeTimer; interval: 1500 }

                Connections {
                    target: paneImageContainer
                    function onImgScaleChanged() {
                        if (paneImageContainer.imgScale > 1.001) paneZoomBadgeTimer.restart()
                    }
                }
            }

            MpvVideo {
                id: paneVideoPlayer
                anchors.fill: parent
                anchors.margins: 8
                visible: previewPane.isVideo
                onPlaybackStateChanged: {
                    if (playbackState !== 0) videoLoadingOverlay.visible = false
                }
                onFileLoaded: {
                    videoLoadingOverlay.visible = true
                }
            }

            Rectangle {
                id: videoLoadingOverlay
                anchors.fill: parent
                anchors.margins: 8
                color: "#000000"
                visible: false
                radius: 4

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Canvas {
                        id: spinnerCanvas
                        width: 40; height: 40
                        anchors.horizontalCenter: parent.horizontalCenter

                        property real angle: 0

                        Timer {
                            interval: 16
                            running: videoLoadingOverlay.visible
                            repeat: true
                            onTriggered: {
                                spinnerCanvas.angle += 0.1
                                if (spinnerCanvas.angle > Math.PI * 2)
                                    spinnerCanvas.angle -= Math.PI * 2
                                spinnerCanvas.requestPaint()
                            }
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width / 2, cy = height / 2, r = 16

                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12)
                            ctx.lineWidth = 3
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.arc(cx, cy, r, angle, angle + 2.1)
                            ctx.strokeStyle = Theme.accent
                            ctx.lineWidth = 3
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Loading..."
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !previewPane.isImage && !previewPane.isVideo

                GlyphIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "file"; size: 48; color: Theme.textFaint
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No preview available"
                    color: Theme.textDim
                    font.family: Theme.fontFamily; font.pixelSize: 12
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: previewPane.currentName
                    color: Theme.textFaint
                    font.family: Theme.fontFamily; font.pixelSize: 10
                }
            }
        }

    }

    function isTextInputFocused() {
        var fo = window.activeFocusItem
        if (!fo) return false
        return fo.hasOwnProperty("echoMode")
    }

    function pathName(p) {
        var s = p.indexOf("\\") >= 0 ? "\\" : "/"
        return p.substring(p.lastIndexOf(s) + 1)
    }

    Shortcut {
        sequence: "Escape"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.activeEditField) { root.cancelActiveEdit(); return }
            if (fsWindow.visibility === Window.FullScreen) { fsWindow.hide(); return }
            if (previewPane.showPreview) { previewPane.hide(); return }
            if (root.selectedIndices.length > 0) { root.clearSelection(); return }
        }
    }

    Shortcut {
        sequence: "Left"; context: Qt.ApplicationShortcut
        enabled: (fsWindow.visibility === Window.FullScreen || previewPane.showPreview) && !root.isTextInputFocused()
        onActivated: {
            if (fsWindow.visibility === Window.FullScreen) { fsWindow.prevFile(); return }
            if (previewPane.showPreview) previewPane.prevFile()
        }
    }
    Shortcut {
        sequence: "Right"; context: Qt.ApplicationShortcut
        enabled: (fsWindow.visibility === Window.FullScreen || previewPane.showPreview) && !root.isTextInputFocused()
        onActivated: {
            if (fsWindow.visibility === Window.FullScreen) { fsWindow.nextFile(); return }
            if (previewPane.showPreview) previewPane.nextFile()
        }
    }
    Shortcut {
        sequence: "Up"; context: Qt.ApplicationShortcut
        enabled: previewPane.showPreview && !root.isTextInputFocused()
        onActivated: {
            if (previewPane.showPreview) previewPane.prevFile()
        }
    }
    Shortcut {
        sequence: "Down"; context: Qt.ApplicationShortcut
        enabled: previewPane.showPreview && !root.isTextInputFocused()
        onActivated: {
            if (previewPane.showPreview) previewPane.nextFile()
        }
    }

    Shortcut {
        sequence: "Delete"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.isTextInputFocused()) return
            if (fsWindow.visibility === Window.FullScreen) { fsWindow.deleteCurrent(); return }
            if (previewPane.showPreview) { previewPane.deleteCurrent(); return }
            if (root.selectedIndices.length > 0) {
                var paths = []
                for (var i = 0; i < root.selectedIndices.length; i++) {
                    var path = backend.model.data(backend.model.index(root.selectedIndices[i], 0), 267)
                    if (path) paths.push(path)
                }
                if (paths.length > 0) backend.deleteFiles(paths)
                root.clearSelection()
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+C"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.isTextInputFocused()) return
            if (root.selectedIndices.length > 0) {
                var paths = []
                for (var i = 0; i < root.selectedIndices.length; i++) {
                    var path = backend.model.data(backend.model.index(root.selectedIndices[i], 0), 267)
                    if (path) paths.push(path)
                }
                if (paths.length > 0) {
                    backend.copyFiles(paths)
                }
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+X"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.isTextInputFocused()) return
            if (root.selectedIndices.length > 0) {
                var paths = []
                for (var i = 0; i < root.selectedIndices.length; i++) {
                    var path = backend.model.data(backend.model.index(root.selectedIndices[i], 0), 267)
                    if (path) paths.push(path)
                }
                if (paths.length > 0) {
                    backend.cutFiles(paths)
                }
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+V"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.isTextInputFocused()) return
            if (backend && backend.canPaste) {
                backend.pasteFile()
            }
        }
    }

    Connections {
        target: backend
        function onUndoDone(restoredPath) {
            if (!restoredPath) return
            var name = root.pathName(restoredPath)
            if (fsWindow.visibility === Window.FullScreen) {
                fsWindow.show(restoredPath, name)
            } else {
                previewPane.show(restoredPath, name)
            }
        }
    }

    Shortcut {
        sequence: "F11"; context: Qt.ApplicationShortcut
        onActivated: {
            if (previewPane.showPreview && fsWindow.visibility !== Window.FullScreen)
                previewPane.openExclusiveFullscreen()
        }
    }

    Shortcut {
        sequence: "Space"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.isTextInputFocused()) return
            if (previewPane.showPreview && previewPane.isVideo) paneVideoPlayer.togglePause()
        }
    }
    Shortcut {
        sequence: "P"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.isTextInputFocused()) return
            if (previewPane.showPreview && previewPane.isVideo) paneVideoPlayer.togglePause()
        }
    }

    Shortcut {
        sequence: "M"; context: Qt.ApplicationShortcut
        onActivated: {
            if (root.isTextInputFocused()) return
            if (previewPane.showPreview && previewPane.isVideo) paneVideoPlayer.toggleMute()
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: batchLayout.implicitWidth + 32
        height: 40
        radius: 20
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        visible: root.selectedIndices.length > 0
        z: 1000
        scale: visible ? 1 : 0.85
        opacity: visible ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            id: batchLayout
            anchors.centerIn: parent
            spacing: 16

            Label {
                text: root.selectedIndices.length + " selected"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle { width: 1; height: 20; color: Theme.divider; anchors.verticalCenter: parent.verticalCenter }

            Rectangle {
                width: 28; height: 28; radius: 6
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.accent
                    opacity: copyBtnMouse.containsMouse ? 0.15 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    name: "copy"
                    size: 13
                    color: copyBtnMouse.containsMouse ? Theme.accent : Theme.textDim
                }
                MouseArea {
                    id: copyBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var paths = []
                        for (var i = 0; i < root.selectedIndices.length; i++) {
                            var idx = root.selectedIndices[i]
                            var path = backend.model.data(backend.model.index(idx, 0), 267)
                            if (path) paths.push(path)
                        }
                        if (paths.length > 0) {
                            backend.copyFiles(paths)
                        }
                    }
                }
                ToolTip.visible: copyBtnMouse.containsMouse
                ToolTip.text: "Copy selected"
                ToolTip.delay: 400
            }

            Rectangle {
                width: 28; height: 28; radius: 6
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.accent
                    opacity: cutBtnMouse.containsMouse ? 0.15 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    name: "cut"
                    size: 13
                    color: cutBtnMouse.containsMouse ? Theme.accent : Theme.textDim
                }
                MouseArea {
                    id: cutBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var paths = []
                        for (var i = 0; i < root.selectedIndices.length; i++) {
                            var idx = root.selectedIndices[i]
                            var path = backend.model.data(backend.model.index(idx, 0), 267)
                            if (path) paths.push(path)
                        }
                        if (paths.length > 0) {
                            backend.cutFiles(paths)
                        }
                    }
                }
                ToolTip.visible: cutBtnMouse.containsMouse
                ToolTip.text: "Cut selected"
                ToolTip.delay: 400
            }

            Rectangle {
                width: 28; height: 28; radius: 6
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.accent
                    opacity: dupBtnMouse.containsMouse ? 0.15 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    name: "duplicate"
                    size: 13
                    color: dupBtnMouse.containsMouse ? Theme.accent : Theme.textDim
                }
                MouseArea {
                    id: dupBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var paths = []
                        for (var i = 0; i < root.selectedIndices.length; i++) {
                            var idx = root.selectedIndices[i]
                            var path = backend.model.data(backend.model.index(idx, 0), 267)
                            if (path) paths.push(path)
                        }
                        if (paths.length > 0) {
                            backend.copyAndPasteMultiple(paths)
                        }
                        root.clearSelection()
                    }
                }
                ToolTip.visible: dupBtnMouse.containsMouse
                ToolTip.text: "Duplicate selected"
                ToolTip.delay: 400
            }

            Rectangle {
                width: 28; height: 28; radius: 6
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.danger
                    opacity: delMouse.containsMouse ? 0.2 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    name: "trash"
                    size: 13
                    color: delMouse.containsMouse ? Theme.danger : Theme.textDim
                }
                MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var paths = []
                        for (var i = 0; i < root.selectedIndices.length; i++) {
                            var idx = root.selectedIndices[i]
                            var path = backend.model.data(backend.model.index(idx, 0), 267)
                            if (path) paths.push(path)
                        }
                        if (paths.length > 0) {
                            backend.deleteFiles(paths)
                        }
                        root.clearSelection()
                    }
                }
                ToolTip.visible: delMouse.containsMouse
                ToolTip.text: "Delete selected"
                ToolTip.delay: 400
            }

            Rectangle {
                width: 28; height: 28; radius: 6
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.text
                    opacity: clearMouse.containsMouse ? 0.1 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 13
                    color: clearMouse.containsMouse ? Theme.text : Theme.textDim
                }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.clearSelection()
                    }
                }
                ToolTip.visible: clearMouse.containsMouse
                ToolTip.text: "Clear selection"
                ToolTip.delay: 400
            }
        }
    }

    Connections {
        target: backend
        function onFileSelected(path) {
            if (!backend) return
            for (var i = 0; i < backend.model.rowCount(); i++) {
                var modelPath = backend.model.data(backend.model.index(i, 0), 257)
                if (modelPath === path) {
                    if (backend.viewMode === "list") {
                        listView.currentIndex = i
                        listView.positionViewAtIndex(i, ListView.Contain)
                    } else if (backend.viewMode === "grid") {
                        gridView.currentIndex = i
                        gridView.positionViewAtIndex(i, GridView.Contain)
                    } else if (backend.viewMode === "tree") {
                        treeList.currentIndex = i
                        treeList.positionViewAtIndex(i, ListView.Contain)
                    }
                    break
                }
            }
        }
        function onViewModeChanged() {
            if (backend.viewMode === "list") {
                listView.forceActiveFocus()
            } else if (backend.viewMode === "grid") {
                gridView.forceActiveFocus()
            } else if (backend.viewMode === "tree") {
                treeList.forceActiveFocus()
            }
        }
    }

    Menu {
        id: emptySpaceContextMenu

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: Theme.radiusSm
            implicitWidth: 200
        }

        delegate: MenuItem {
            id: emptyMenuItem
            implicitWidth: 200
            implicitHeight: 36

            contentItem: Text {
                text: emptyMenuItem.text
                font: emptyMenuItem.font
                color: emptyMenuItem.enabled ? Theme.text : Theme.textFaint
                leftPadding: 12
                rightPadding: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                color: emptyMenuItem.highlighted ? Theme.surfaceHi : "transparent"
                radius: 4
                opacity: emptyMenuItem.enabled ? 1 : 0.5
            }
        }

        MenuItem {
            text: "Refresh"
            enabled: backend ? (backend.path.length > 0 && !backend.busy) : false
            onTriggered: backend.scan()
        }
        MenuItem {
            text: "New Folder"
            enabled: backend ? (backend.path.length > 0 && !backend.busy) : false
            onTriggered: newFolderDialog.open()
        }
        MenuItem {
            text: "Paste"
            enabled: backend ? (backend.canPaste && !backend.busy) : false
            onTriggered: backend.pasteFile()
        }
        MenuItem {
            text: "Undo"
            enabled: backend ? backend.canUndo : false
            onTriggered: backend.undo()
        }
        MenuItem {
            text: "Reveal in Explorer"
            enabled: backend ? (backend.path.length > 0) : false
            onTriggered: backend.revealInExplorer(backend.path)
        }
        MenuItem {
            text: "Open with CrossCheck"
            enabled: backend ? (backend.path.length > 0) : false
            onTriggered: {
                console.log("Opening with CrossCheck from empty space menu")
                backend.launchExternalApp(root.prismCrossCheckExe, [backend.path])
            }
        }
        MenuItem {
            text: "Open Terminal Here"
            enabled: backend ? (backend.path.length > 0) : false
            onTriggered: backend.openTerminal(backend.path)
        }
        MenuItem {
            text: "Properties"
            enabled: backend ? (backend.path.length > 0) : false
            onTriggered: {
                var p = backend.itemProperties("")
                propsDialog.props = p
                propsDialog.open()
            }
        }
    }

    Rectangle {
        id: selectionBox
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
        border.color: Theme.accent
        border.width: 1
        visible: false
        z: 2000
    }

    Timer {
        id: autoScrollTimer
        interval: 30
        repeat: true
        running: root.dragActive
        onTriggered: {
            var viewMode = backend ? backend.viewMode : "list"
            if (viewMode === "analytics") return
            var view = (viewMode === "grid") ? gridView : ((viewMode === "tree") ? treeList : listView)

            var scrollSpeed = 16
            var threshold = 40
            var my = root.dragCurrentViewY

            if (my < threshold) {
                view.contentY = Math.max(0, view.contentY - scrollSpeed)
                root.updateDragSelectionBox()
            } else if (my > view.height - threshold) {
                var maxScroll = Math.max(0, view.contentHeight - view.height)
                view.contentY = Math.min(maxScroll, view.contentY + scrollSpeed)
                root.updateDragSelectionBox()
            }
        }
    }

    Rectangle {
        id: blankPlaceholder
        anchors.fill: parent
        color: Theme.bg1
        visible: !backend || !backend.path || backend.path.length === 0
        z: 100

        Column {
            anchors.centerIn: parent
            spacing: 16
            opacity: 0.6

            GlyphIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "folderFill"
                size: 64
                color: Theme.textFaint
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No folder selected"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Open a folder or type a path to begin"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    Component.onCompleted: {
        if (backend) {
            if (backend.viewMode === "list") {
                listView.forceActiveFocus()
            } else if (backend.viewMode === "grid") {
                gridView.forceActiveFocus()
            } else if (backend.viewMode === "tree") {
                treeList.forceActiveFocus()
            }
        }
    }
}
