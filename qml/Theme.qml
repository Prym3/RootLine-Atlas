pragma Singleton
import QtQuick

QtObject {
    readonly property color bg0:        "#0b0d12"
    readonly property color bg1:        "#11141b"
    readonly property color surface:    "#161a23"
    readonly property color surfaceHi:  "#1c2230"
    readonly property color surfaceHi2: "#242b3b"
    readonly property color border:     "#222838"
    readonly property color borderHi:   "#2e3548"
    readonly property color divider:    "#1a1f2a"

    readonly property color text:       "#eef0f6"
    readonly property color textDim:    "#9097a8"
    readonly property color textFaint:  "#5b6273"

    readonly property color accent:     "#dc143c"
    readonly property color accent2:    "#ff8c42"
    readonly property color accentSoft: "#dc143c22"
    readonly property color folder:     "#ffb347"
    readonly property color subfolder:  "#ff7096"
    readonly property color file:       "#7adcb4"
    readonly property color danger:     "#ff4560"
    readonly property color warn:       "#f4c869"
    readonly property color success:    "#7adcb4"

    readonly property int  radius:      10
    readonly property int  radiusSm:    6
    readonly property int  radiusLg:    14
    readonly property int  pad:         16
    readonly property int  padSm:       10
    readonly property int  chrome:      52
    readonly property int  sidebar:     308

    readonly property string fontFamily: "Inter, Segoe UI Variable, Segoe UI, system-ui, -apple-system, sans-serif"
    readonly property string fontMono:   "JetBrains Mono, Cascadia Mono, Consolas, monospace"
}
