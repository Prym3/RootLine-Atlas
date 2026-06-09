import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: panel
    property bool panelCollapsed: false
    signal collapseRequested()
    color: Theme.bg0

    opacity: 0
    transform: Translate { id: panelSlide; x: -18 }
    SequentialAnimation {
        id: panelAppearAnim
        PauseAnimation { duration: 120 }
        ParallelAnimation {
            NumberAnimation { target: panel;      property: "opacity"; from: 0; to: 1;  duration: 340; easing.type: Easing.OutCubic }
            NumberAnimation { target: panelSlide; property: "x";      from: -18; to: 0; duration: 340; easing.type: Easing.OutCubic }
        }
    }

    function fmtList(arr) { return (arr && arr.length) ? arr.join(", ") : "" }

    function syncFromBackend() {
        var f = backend.filters
        typeCombo.currentIndex = Math.max(0, typeCombo.model.indexOf(f.filter_type))
        sortCombo.currentIndex = Math.max(0, sortCombo.model.indexOf(f.sort_by))
        minField.text          = f.min_size_text || ""
        maxField.text          = f.max_size_text || ""
        extInclude.text        = fmtList(f.extensions)
        extExclude.text        = fmtList(f.exclude_extensions)
        kwInclude.text         = fmtList(f.keywords)
        kwExclude.text         = fmtList(f.exclude_keywords)
    }

    Connections {
        target: backend
        function onFiltersChanged() {
            var f = backend.filters
            var isReset = (f.min_size === 0 && f.max_size === 0 &&
                           (!f.extensions || f.extensions.length === 0) &&
                           (!f.keywords   || f.keywords.length   === 0))
            if (isReset) panel.syncFromBackend()
        }
    }

    Component.onCompleted: { panelAppearAnim.start(); panel.syncFromBackend() }

    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 1; color: Theme.divider
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 18
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: Theme.accent
                    GlyphIcon { anchors.centerIn: parent; name: "filter"; size: 14; color: "#ffffff" }
                }

                Label {
                    text: "Filters"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 24; height: 24; radius: 4
                    color: filterCollapseMouse.containsMouse ? Theme.surfaceHi : "transparent"
                    GlyphIcon {
                        anchors.centerIn: parent
                        name: "chevronLeft"
                        size: 12
                        color: Theme.textDim
                    }
                    MouseArea {
                        id: filterCollapseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.collapseRequested()
                        ToolTip.visible: filterCollapseMouse.containsMouse
                        ToolTip.text: "Collapse filters"
                    }
                }

                Rectangle {
                    id: clearAllBtn
                    width: clearAllRow.implicitWidth + 16
                    height: 26; radius: 13
                    color: clearAllMouse.containsMouse
                           ? Qt.rgba(1, 0.35, 0.40, 0.18)
                           : Qt.rgba(1, 0.35, 0.40, 0.08)
                    border.color: Qt.rgba(1, 0.35, 0.40, clearAllMouse.containsMouse ? 0.45 : 0.22)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: clearAllRow
                        anchors.centerIn: parent
                        spacing: 5
                        GlyphIcon { name: "close"; size: 9; color: Theme.danger; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "Clear all"
                            color: Theme.danger
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: clearAllMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.resetFilters()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                SectionLabel { label: "Show" }
                ModernCombo {
                    id: typeCombo
                    Layout.fillWidth: true
                    model: ["all", "files", "folders"]
                    onActivated: backend.setFilterType(currentText)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                SectionLabel { label: "Size range" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    ModernField {
                        id: minField
                        Layout.fillWidth: true
                        placeholderText: "min  e.g. 500KB"
                    }
                    Text { text: "–"; color: Theme.textFaint; font.pixelSize: 13 }
                    ModernField {
                        id: maxField
                        Layout.fillWidth: true
                        placeholderText: "max  e.g. 2GB"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                SectionLabel { label: "Extensions" }
                ModernField {
                    id: extInclude
                    Layout.fillWidth: true
                    placeholderText: "include  e.g. .py, .txt"
                }
                ModernField {
                    id: extExclude
                    Layout.fillWidth: true
                    placeholderText: "exclude  e.g. .log, .tmp"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                SectionLabel { label: "Keywords" }
                ModernField {
                    id: kwInclude
                    Layout.fillWidth: true
                    placeholderText: "include  e.g. report"
                }
                ModernField {
                    id: kwExclude
                    Layout.fillWidth: true
                    placeholderText: "exclude  e.g. backup"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                SectionLabel { label: "Date range" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    ModernField {
                        id: minDateField
                        Layout.fillWidth: true
                        placeholderText: "from  YYYY-MM-DD"
                    }
                    Text { text: "–"; color: Theme.textFaint; font.pixelSize: 13 }
                    ModernField {
                        id: maxDateField
                        Layout.fillWidth: true
                        placeholderText: "to  YYYY-MM-DD"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                SectionLabel { label: "Sort by" }
                ModernCombo {
                    id: sortCombo
                    Layout.fillWidth: true
                    model: ["none", "name", "size", "date", "path", "type"]
                    onActivated: backend.setSortBy(currentText)
                }
            }

            Rectangle {
                id: applyBtn
                Layout.fillWidth: true
                height: 38; radius: Theme.radiusSm
                color: applyMouse.pressed ? Qt.darker(Theme.accent, 1.2) : applyMouse.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                RowLayout {
                    anchors.centerIn: parent; spacing: 7
                    GlyphIcon { name: "play"; size: 12; color: "#ffffff" }
                    Text {
                        text: "Apply & Scan"
                        color: "#ffffff"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.applyFilters(
                            minField.text, maxField.text,
                            extInclude.text, extExclude.text,
                            kwInclude.text, kwExclude.text,
                            typeCombo.currentText,
                            minDateField.text, maxDateField.text
                        )
                        backend.scan()
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }
    }
}
