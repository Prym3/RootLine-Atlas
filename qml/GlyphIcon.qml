import QtQuick

Item {
    id: root
    property string name: ""
    property color color: "#eef0f6"
    property int size: 16
    implicitWidth: size
    implicitHeight: size

    Canvas {
        id: c
        anchors.fill: parent
        antialiasing: true
        smooth: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = root.color
            ctx.fillStyle = root.color
            ctx.lineWidth = Math.max(1.4, root.size / 12)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            const w = width, h = height
            const cx = w / 2, cy = h / 2
            const s = Math.min(w, h)

            function path(fn) { ctx.beginPath(); fn(); ctx.stroke() }
            function fillPath(fn) { ctx.beginPath(); fn(); ctx.fill() }

            switch (root.name) {
            case "back":
                path(() => { ctx.moveTo(cx + s*0.18, cy - s*0.28); ctx.lineTo(cx - s*0.18, cy); ctx.lineTo(cx + s*0.18, cy + s*0.28) })
                break
            case "forward":
                path(() => { ctx.moveTo(cx - s*0.18, cy - s*0.28); ctx.lineTo(cx + s*0.18, cy); ctx.lineTo(cx - s*0.18, cy + s*0.28) })
                break
            case "up":
                path(() => { ctx.moveTo(cx - s*0.28, cy + s*0.12); ctx.lineTo(cx, cy - s*0.18); ctx.lineTo(cx + s*0.28, cy + s*0.12) })
                path(() => { ctx.moveTo(cx, cy - s*0.18); ctx.lineTo(cx, cy + s*0.30) })
                break
            case "reload":
                ctx.beginPath()
                ctx.arc(cx, cy, s*0.30, -Math.PI*0.25, Math.PI*1.4)
                ctx.stroke()
                fillPath(() => {
                    ctx.moveTo(cx + s*0.30, cy - s*0.30)
                    ctx.lineTo(cx + s*0.46, cy - s*0.14)
                    ctx.lineTo(cx + s*0.16, cy - s*0.14)
                    ctx.closePath()
                })
                break
            case "stop":
                ctx.fillRect(cx - s*0.20, cy - s*0.20, s*0.40, s*0.40)
                break
            case "plus":
                path(() => {
                    ctx.moveTo(cx - s*0.24, cy); ctx.lineTo(cx + s*0.24, cy)
                    ctx.moveTo(cx, cy - s*0.24); ctx.lineTo(cx, cy + s*0.24)
                })
                break
            case "close":
                path(() => {
                    ctx.moveTo(cx - s*0.20, cy - s*0.20); ctx.lineTo(cx + s*0.20, cy + s*0.20)
                    ctx.moveTo(cx + s*0.20, cy - s*0.20); ctx.lineTo(cx - s*0.20, cy + s*0.20)
                })
                break
            case "folder":
                ctx.lineWidth = Math.max(1.2, root.size / 14)
                path(() => {
                    ctx.moveTo(cx - s*0.34, cy - s*0.20)
                    ctx.lineTo(cx - s*0.10, cy - s*0.20)
                    ctx.lineTo(cx - s*0.02, cy - s*0.10)
                    ctx.lineTo(cx + s*0.34, cy - s*0.10)
                    ctx.lineTo(cx + s*0.34, cy + s*0.26)
                    ctx.lineTo(cx - s*0.34, cy + s*0.26)
                    ctx.closePath()
                })
                break
            case "folderFill":
                fillPath(() => {
                    ctx.moveTo(cx - s*0.34, cy - s*0.20)
                    ctx.lineTo(cx - s*0.10, cy - s*0.20)
                    ctx.lineTo(cx - s*0.02, cy - s*0.10)
                    ctx.lineTo(cx + s*0.34, cy - s*0.10)
                    ctx.lineTo(cx + s*0.34, cy + s*0.26)
                    ctx.lineTo(cx - s*0.34, cy + s*0.26)
                    ctx.closePath()
                })
                break
            case "folderPlus":
                path(() => {
                    ctx.moveTo(cx - s*0.34, cy - s*0.20)
                    ctx.lineTo(cx - s*0.10, cy - s*0.20)
                    ctx.lineTo(cx - s*0.02, cy - s*0.10)
                    ctx.lineTo(cx + s*0.20, cy - s*0.10)
                    ctx.lineTo(cx + s*0.20, cy - s*0.24)
                    ctx.lineTo(cx + s*0.26, cy - s*0.24)
                    ctx.lineTo(cx + s*0.26, cy - s*0.10)
                    ctx.lineTo(cx + s*0.34, cy - s*0.10)
                    ctx.lineTo(cx + s*0.34, cy + s*0.26)
                    ctx.lineTo(cx - s*0.34, cy + s*0.26)
                    ctx.closePath()
                })
                path(() => {
                    ctx.moveTo(cx + s*0.15, cy - s*0.24); ctx.lineTo(cx + s*0.31, cy - s*0.24)
                    ctx.moveTo(cx + s*0.23, cy - s*0.32); ctx.lineTo(cx + s*0.23, cy - s*0.16)
                })
                break
            case "file":
                path(() => {
                    ctx.moveTo(cx - s*0.22, cy - s*0.32)
                    ctx.lineTo(cx + s*0.10, cy - s*0.32)
                    ctx.lineTo(cx + s*0.24, cy - s*0.18)
                    ctx.lineTo(cx + s*0.24, cy + s*0.30)
                    ctx.lineTo(cx - s*0.22, cy + s*0.30)
                    ctx.closePath()
                })
                path(() => { ctx.moveTo(cx + s*0.10, cy - s*0.32); ctx.lineTo(cx + s*0.10, cy - s*0.18); ctx.lineTo(cx + s*0.24, cy - s*0.18) })
                break
            case "search":
                ctx.beginPath(); ctx.arc(cx - s*0.06, cy - s*0.06, s*0.22, 0, Math.PI*2); ctx.stroke()
                path(() => { ctx.moveTo(cx + s*0.12, cy + s*0.12); ctx.lineTo(cx + s*0.30, cy + s*0.30) })
                break
            case "download":
                path(() => { ctx.moveTo(cx, cy - s*0.30); ctx.lineTo(cx, cy + s*0.16) })
                path(() => { ctx.moveTo(cx - s*0.18, cy - s*0.04); ctx.lineTo(cx, cy + s*0.18); ctx.lineTo(cx + s*0.18, cy - s*0.04) })
                path(() => { ctx.moveTo(cx - s*0.30, cy + s*0.30); ctx.lineTo(cx + s*0.30, cy + s*0.30) })
                break
            case "eye":
                path(() => {
                    ctx.moveTo(cx - s*0.36, cy)
                    ctx.bezierCurveTo(cx - s*0.20, cy - s*0.30, cx + s*0.20, cy - s*0.30, cx + s*0.36, cy)
                    ctx.bezierCurveTo(cx + s*0.20, cy + s*0.30, cx - s*0.20, cy + s*0.30, cx - s*0.36, cy)
                    ctx.closePath()
                })
                ctx.beginPath(); ctx.arc(cx, cy, s*0.10, 0, Math.PI*2); ctx.stroke()
                break
            case "chevron":
                path(() => { ctx.moveTo(cx - s*0.10, cy - s*0.22); ctx.lineTo(cx + s*0.14, cy); ctx.lineTo(cx - s*0.10, cy + s*0.22) })
                break
            case "chevronDown":
                path(() => { ctx.moveTo(cx - s*0.22, cy - s*0.10); ctx.lineTo(cx, cy + s*0.14); ctx.lineTo(cx + s*0.22, cy - s*0.10) })
                break
            case "chevronLeft":
                path(() => { ctx.moveTo(cx + s*0.10, cy - s*0.22); ctx.lineTo(cx - s*0.14, cy); ctx.lineTo(cx + s*0.10, cy + s*0.22) })
                break
            case "chevronRight":
                path(() => { ctx.moveTo(cx - s*0.10, cy - s*0.22); ctx.lineTo(cx + s*0.14, cy); ctx.lineTo(cx - s*0.10, cy + s*0.22) })
                break
            case "filter":
                path(() => {
                    ctx.moveTo(cx - s*0.32, cy - s*0.24)
                    ctx.lineTo(cx + s*0.32, cy - s*0.24)
                    ctx.lineTo(cx + s*0.10, cy)
                    ctx.lineTo(cx + s*0.10, cy + s*0.28)
                    ctx.lineTo(cx - s*0.10, cy + s*0.18)
                    ctx.lineTo(cx - s*0.10, cy)
                    ctx.closePath()
                })
                break
            case "reset":
                ctx.beginPath()
                ctx.arc(cx, cy, s*0.28, Math.PI*0.25, Math.PI*1.75)
                ctx.stroke()
                fillPath(() => {
                    ctx.moveTo(cx - s*0.28, cy - s*0.28)
                    ctx.lineTo(cx - s*0.10, cy - s*0.28)
                    ctx.lineTo(cx - s*0.20, cy - s*0.10)
                    ctx.closePath()
                })
                break
            case "play":
                fillPath(() => {
                    ctx.moveTo(cx - s*0.16, cy - s*0.24)
                    ctx.lineTo(cx + s*0.24, cy)
                    ctx.lineTo(cx - s*0.16, cy + s*0.24)
                    ctx.closePath()
                })
                break
            case "pause":
                fillPath(() => { ctx.rect(cx - s*0.22, cy - s*0.24, s*0.14, s*0.48) })
                fillPath(() => { ctx.rect(cx + s*0.08, cy - s*0.24, s*0.14, s*0.48) })
                break
            case "close":
                path(() => { ctx.moveTo(cx - s*0.26, cy - s*0.26); ctx.lineTo(cx + s*0.26, cy + s*0.26) })
                path(() => { ctx.moveTo(cx + s*0.26, cy - s*0.26); ctx.lineTo(cx - s*0.26, cy + s*0.26) })
                break
            case "list":
                path(() => { ctx.moveTo(cx - s*0.32, cy - s*0.22); ctx.lineTo(cx + s*0.32, cy - s*0.22) })
                path(() => { ctx.moveTo(cx - s*0.32, cy);           ctx.lineTo(cx + s*0.32, cy) })
                path(() => { ctx.moveTo(cx - s*0.32, cy + s*0.22); ctx.lineTo(cx + s*0.32, cy + s*0.22) })
                break
            case "grid":
                fillPath(() => { ctx.rect(cx - s*0.30, cy - s*0.30, s*0.26, s*0.26) })
                fillPath(() => { ctx.rect(cx + s*0.04, cy - s*0.30, s*0.26, s*0.26) })
                fillPath(() => { ctx.rect(cx - s*0.30, cy + s*0.04, s*0.26, s*0.26) })
                fillPath(() => { ctx.rect(cx + s*0.04, cy + s*0.04, s*0.26, s*0.26) })
                break
            case "chart":
                fillPath(() => { ctx.rect(cx - s*0.28, cy + s*0.06, s*0.16, s*0.24) })
                fillPath(() => { ctx.rect(cx - s*0.04, cy - s*0.10, s*0.16, s*0.40) })
                fillPath(() => { ctx.rect(cx + s*0.20, cy - s*0.22, s*0.16, s*0.52) })
                break
            case "tree":
                fillPath(() => { ctx.arc(cx, cy - s*0.28, s*0.09, 0, Math.PI*2) })
                fillPath(() => { ctx.arc(cx - s*0.26, cy + s*0.20, s*0.09, 0, Math.PI*2) })
                fillPath(() => { ctx.arc(cx + s*0.26, cy + s*0.20, s*0.09, 0, Math.PI*2) })
                path(() => { ctx.moveTo(cx, cy - s*0.19); ctx.lineTo(cx, cy + s*0.02); ctx.lineTo(cx - s*0.26, cy + s*0.11) })
                path(() => { ctx.moveTo(cx, cy + s*0.02); ctx.lineTo(cx + s*0.26, cy + s*0.11) })
                break
            case "warn":
                path(() => {
                    ctx.moveTo(cx, cy - s*0.36)
                    ctx.lineTo(cx + s*0.38, cy + s*0.28)
                    ctx.lineTo(cx - s*0.38, cy + s*0.28)
                    ctx.closePath()
                })
                path(() => { ctx.moveTo(cx, cy - s*0.14); ctx.lineTo(cx, cy + s*0.08) })
                ctx.beginPath(); ctx.arc(cx, cy + s*0.17, s*0.045, 0, Math.PI*2); ctx.fill()
                break
            case "star":
                fillPath(() => {
                    var pts = 5, r1 = s*0.34, r2 = s*0.14, angle = -Math.PI/2
                    ctx.moveTo(cx + r1*Math.cos(angle), cy + r1*Math.sin(angle))
                    for (var i = 1; i < pts*2; i++) {
                        angle += Math.PI/pts
                        var r = (i % 2 === 0) ? r1 : r2
                        ctx.lineTo(cx + r*Math.cos(angle), cy + r*Math.sin(angle))
                    }
                    ctx.closePath()
                })
                break
            case "starOutline":
                path(() => {
                    var pts = 5, r1 = s*0.34, r2 = s*0.14, angle = -Math.PI/2
                    ctx.moveTo(cx + r1*Math.cos(angle), cy + r1*Math.sin(angle))
                    for (var i = 1; i < pts*2; i++) {
                        angle += Math.PI/pts
                        var r = (i % 2 === 0) ? r1 : r2
                        ctx.lineTo(cx + r*Math.cos(angle), cy + r*Math.sin(angle))
                    }
                    ctx.closePath()
                })
                break

            case "copy":
                path(() => {
                    ctx.rect(cx - s*0.08, cy - s*0.14, s*0.26, s*0.34)
                })
                path(() => {
                    ctx.moveTo(cx - s*0.22, cy + s*0.10)
                    ctx.lineTo(cx - s*0.22, cy - s*0.28)
                    ctx.lineTo(cx + s*0.04, cy - s*0.28)
                })
                break

            case "cut":
                ctx.beginPath(); ctx.arc(cx - s*0.14, cy + s*0.18, s*0.09, 0, Math.PI*2); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx + s*0.14, cy + s*0.18, s*0.09, 0, Math.PI*2); ctx.stroke()
                path(() => {
                    ctx.moveTo(cx - s*0.08, cy + s*0.12)
                    ctx.lineTo(cx, cy)
                    ctx.lineTo(cx + s*0.18, cy - s*0.28)
                })
                path(() => {
                    ctx.moveTo(cx + s*0.08, cy + s*0.12)
                    ctx.lineTo(cx, cy)
                    ctx.lineTo(cx - s*0.18, cy - s*0.28)
                })
                break

            case "duplicate":
                path(() => {
                    ctx.rect(cx - s*0.18, cy - s*0.18, s*0.24, s*0.30)
                })
                path(() => {
                    ctx.rect(cx - s*0.04, cy - s*0.04, s*0.24, s*0.30)
                })
                break

            case "fileTypeCode":
                path(() => { ctx.moveTo(cx - s*0.14, cy - s*0.22); ctx.lineTo(cx - s*0.30, cy); ctx.lineTo(cx - s*0.14, cy + s*0.22) })
                path(() => { ctx.moveTo(cx + s*0.14, cy - s*0.22); ctx.lineTo(cx + s*0.30, cy); ctx.lineTo(cx + s*0.14, cy + s*0.22) })
                path(() => { ctx.moveTo(cx - s*0.08, cy + s*0.26); ctx.lineTo(cx + s*0.08, cy - s*0.26) })
                break
            case "fileTypeData":
                path(() => { ctx.moveTo(cx - s*0.28, cy - s*0.20); ctx.lineTo(cx + s*0.28, cy - s*0.20) })
                path(() => { ctx.moveTo(cx - s*0.28, cy);           ctx.lineTo(cx + s*0.28, cy) })
                path(() => { ctx.moveTo(cx - s*0.28, cy + s*0.20); ctx.lineTo(cx + s*0.28, cy + s*0.20) })
                path(() => { ctx.moveTo(cx - s*0.28, cy - s*0.28); ctx.lineTo(cx - s*0.28, cy + s*0.28) })
                break
            case "fileTypeDoc":
                path(() => {
                    ctx.moveTo(cx - s*0.22, cy - s*0.32); ctx.lineTo(cx + s*0.10, cy - s*0.32)
                    ctx.lineTo(cx + s*0.24, cy - s*0.18); ctx.lineTo(cx + s*0.24, cy + s*0.32)
                    ctx.lineTo(cx - s*0.22, cy + s*0.32); ctx.closePath()
                })
                path(() => { ctx.moveTo(cx + s*0.10, cy - s*0.32); ctx.lineTo(cx + s*0.10, cy - s*0.18); ctx.lineTo(cx + s*0.24, cy - s*0.18) })
                path(() => { ctx.moveTo(cx - s*0.14, cy - s*0.06); ctx.lineTo(cx + s*0.14, cy - s*0.06) })
                path(() => { ctx.moveTo(cx - s*0.14, cy + s*0.06); ctx.lineTo(cx + s*0.14, cy + s*0.06) })
                path(() => { ctx.moveTo(cx - s*0.14, cy + s*0.18); ctx.lineTo(cx + s*0.08, cy + s*0.18) })
                break
            case "fileTypeImage":
                path(() => {
                    ctx.moveTo(cx - s*0.28, cy - s*0.24); ctx.lineTo(cx + s*0.28, cy - s*0.24)
                    ctx.lineTo(cx + s*0.28, cy + s*0.24); ctx.lineTo(cx - s*0.28, cy + s*0.24); ctx.closePath()
                })
                ctx.beginPath(); ctx.arc(cx - s*0.10, cy - s*0.08, s*0.08, 0, Math.PI*2); ctx.stroke()
                path(() => { ctx.moveTo(cx - s*0.28, cy + s*0.24); ctx.lineTo(cx - s*0.04, cy - s*0.02); ctx.lineTo(cx + s*0.14, cy + s*0.12); ctx.lineTo(cx + s*0.22, cy + s*0.02); ctx.lineTo(cx + s*0.28, cy + s*0.10) })
                break
            case "fileTypeVideo":
                path(() => {
                    ctx.moveTo(cx - s*0.28, cy - s*0.22); ctx.lineTo(cx + s*0.28, cy - s*0.22)
                    ctx.lineTo(cx + s*0.28, cy + s*0.22); ctx.lineTo(cx - s*0.28, cy + s*0.22); ctx.closePath()
                })
                fillPath(() => { ctx.moveTo(cx - s*0.10, cy - s*0.16); ctx.lineTo(cx + s*0.18, cy); ctx.lineTo(cx - s*0.10, cy + s*0.16); ctx.closePath() })
                break
            case "fileTypeAudio":
                path(() => { ctx.moveTo(cx, cy - s*0.28); ctx.lineTo(cx, cy + s*0.12) })
                path(() => { ctx.moveTo(cx, cy - s*0.28); ctx.lineTo(cx + s*0.22, cy - s*0.34); ctx.lineTo(cx + s*0.22, cy - s*0.06) })
                ctx.beginPath(); ctx.arc(cx - s*0.06, cy + s*0.18, s*0.10, 0, Math.PI*2); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx + s*0.16, cy + s*0.00, s*0.09, 0, Math.PI*2); ctx.stroke()
                break
            case "fileTypeArchive":
                path(() => {
                    ctx.moveTo(cx - s*0.22, cy - s*0.34); ctx.lineTo(cx + s*0.08, cy - s*0.34)
                    ctx.lineTo(cx + s*0.24, cy - s*0.18); ctx.lineTo(cx + s*0.24, cy + s*0.34)
                    ctx.lineTo(cx - s*0.22, cy + s*0.34); ctx.closePath()
                })
                path(() => { ctx.moveTo(cx + s*0.08, cy - s*0.34); ctx.lineTo(cx + s*0.08, cy - s*0.18); ctx.lineTo(cx + s*0.24, cy - s*0.18) })
                fillPath(() => { ctx.rect(cx - s*0.04, cy - s*0.26, s*0.08, s*0.08) })
                fillPath(() => { ctx.rect(cx - s*0.04, cy - s*0.12, s*0.08, s*0.08) })
                fillPath(() => { ctx.rect(cx - s*0.04, cy + s*0.02, s*0.08, s*0.08) })
                fillPath(() => { ctx.rect(cx - s*0.04, cy + s*0.16, s*0.08, s*0.08) })
                break
            case "fileTypeExe":
                ctx.beginPath(); ctx.arc(cx, cy, s*0.18, 0, Math.PI*2); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx, cy, s*0.30, 0, Math.PI*2); ctx.stroke()
                path(() => { ctx.moveTo(cx, cy - s*0.30); ctx.lineTo(cx, cy - s*0.38) })
                path(() => { ctx.moveTo(cx, cy + s*0.30); ctx.lineTo(cx, cy + s*0.38) })
                path(() => { ctx.moveTo(cx - s*0.30, cy); ctx.lineTo(cx - s*0.38, cy) })
                path(() => { ctx.moveTo(cx + s*0.30, cy); ctx.lineTo(cx + s*0.38, cy) })
                break
            case "fileTypeFont":
                path(() => { ctx.moveTo(cx, cy - s*0.30); ctx.lineTo(cx - s*0.22, cy + s*0.28); })
                path(() => { ctx.moveTo(cx, cy - s*0.30); ctx.lineTo(cx + s*0.22, cy + s*0.28); })
                path(() => { ctx.moveTo(cx - s*0.12, cy + s*0.06); ctx.lineTo(cx + s*0.12, cy + s*0.06) })
                break
            case "expand":
                path(() => { ctx.moveTo(cx - s*0.20, cy - s*0.20); ctx.lineTo(cx - s*0.08, cy - s*0.08) })
                path(() => { ctx.moveTo(cx + s*0.20, cy - s*0.20); ctx.lineTo(cx + s*0.08, cy - s*0.08) })
                path(() => { ctx.moveTo(cx - s*0.20, cy + s*0.20); ctx.lineTo(cx - s*0.08, cy + s*0.08) })
                path(() => { ctx.moveTo(cx + s*0.20, cy + s*0.20); ctx.lineTo(cx + s*0.08, cy + s*0.08) })
                path(() => { ctx.moveTo(cx - s*0.20, cy - s*0.20); ctx.lineTo(cx - s*0.08, cy - s*0.20); ctx.lineTo(cx - s*0.20, cy - s*0.08) })
                path(() => { ctx.moveTo(cx + s*0.20, cy - s*0.20); ctx.lineTo(cx + s*0.08, cy - s*0.20); ctx.lineTo(cx + s*0.20, cy - s*0.08) })
                path(() => { ctx.moveTo(cx - s*0.20, cy + s*0.20); ctx.lineTo(cx - s*0.08, cy + s*0.20); ctx.lineTo(cx - s*0.20, cy + s*0.08) })
                path(() => { ctx.moveTo(cx + s*0.20, cy + s*0.20); ctx.lineTo(cx + s*0.08, cy + s*0.20); ctx.lineTo(cx + s*0.20, cy + s*0.08) })
                break
            case "maximize":
                path(() => { ctx.rect(cx - s*0.24, cy - s*0.24, s*0.48, s*0.48) })
                path(() => { ctx.moveTo(cx + s*0.08, cy - s*0.20); ctx.lineTo(cx + s*0.20, cy - s*0.20); ctx.lineTo(cx + s*0.20, cy - s*0.08) })
                path(() => { ctx.moveTo(cx + s*0.10, cy - s*0.18); ctx.lineTo(cx + s*0.18, cy - s*0.10) })
                break
            case "rename":
                path(() => {
                    ctx.moveTo(cx + s*0.16, cy - s*0.24)
                    ctx.lineTo(cx + s*0.24, cy - s*0.16)
                    ctx.lineTo(cx - s*0.08, cy + s*0.16)
                    ctx.lineTo(cx - s*0.16, cy + s*0.08)
                    ctx.closePath()
                })
                path(() => { ctx.moveTo(cx - s*0.16, cy + s*0.08); ctx.lineTo(cx - s*0.24, cy + s*0.16); ctx.lineTo(cx - s*0.16, cy + s*0.24); ctx.lineTo(cx - s*0.08, cy + s*0.16) })
                path(() => { ctx.moveTo(cx + s*0.06, cy - s*0.06); ctx.lineTo(cx - s*0.06, cy + s*0.06) })
                break
            case "trash":
                path(() => { ctx.rect(cx - s*0.18, cy - s*0.12, s*0.36, s*0.06) })
                path(() => { ctx.rect(cx - s*0.14, cy - s*0.06, s*0.28, s*0.30) })
                path(() => { ctx.moveTo(cx - s*0.08, cy + s*0.04); ctx.lineTo(cx - s*0.08, cy + s*0.18) })
                path(() => { ctx.moveTo(cx, cy + s*0.04); ctx.lineTo(cx, cy + s*0.18) })
                path(() => { ctx.moveTo(cx + s*0.08, cy + s*0.04); ctx.lineTo(cx + s*0.08, cy + s*0.18) })
                break
            case "undo":
                ctx.beginPath()
                ctx.arc(cx + s*0.10, cy, s*0.20, Math.PI*0.5, Math.PI*1.5)
                ctx.stroke()
                path(() => { ctx.moveTo(cx + s*0.10, cy - s*0.20); ctx.lineTo(cx - s*0.06, cy - s*0.20); ctx.lineTo(cx - s*0.06, cy - s*0.06) })
                break
            case "speaker":
                fillPath(() => {
                    ctx.moveTo(cx - s*0.22, cy - s*0.12)
                    ctx.lineTo(cx - s*0.06, cy - s*0.12)
                    ctx.lineTo(cx + s*0.10, cy - s*0.26)
                    ctx.lineTo(cx + s*0.10, cy + s*0.26)
                    ctx.lineTo(cx - s*0.06, cy + s*0.12)
                    ctx.lineTo(cx - s*0.22, cy + s*0.12)
                    ctx.closePath()
                })
                ctx.beginPath(); ctx.arc(cx + s*0.10, cy, s*0.20, -Math.PI*0.45, Math.PI*0.45); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx + s*0.10, cy, s*0.32, -Math.PI*0.45, Math.PI*0.45); ctx.stroke()
                break
            case "speakerMute":
                fillPath(() => {
                    ctx.moveTo(cx - s*0.28, cy - s*0.12)
                    ctx.lineTo(cx - s*0.12, cy - s*0.12)
                    ctx.lineTo(cx + s*0.04, cy - s*0.26)
                    ctx.lineTo(cx + s*0.04, cy + s*0.26)
                    ctx.lineTo(cx - s*0.12, cy + s*0.12)
                    ctx.lineTo(cx - s*0.28, cy + s*0.12)
                    ctx.closePath()
                })
                path(() => { ctx.moveTo(cx + s*0.14, cy - s*0.14); ctx.lineTo(cx + s*0.30, cy + s*0.14) })
                path(() => { ctx.moveTo(cx + s*0.30, cy - s*0.14); ctx.lineTo(cx + s*0.14, cy + s*0.14) })
                break
            case "check":
                fillPath(() => {
                    ctx.moveTo(cx - s*0.3, cy)
                    ctx.lineTo(cx - s*0.1, cy + s*0.2)
                    ctx.lineTo(cx + s*0.3, cy - s*0.2)
                    ctx.lineTo(cx + s*0.3, cy - s*0.05)
                    ctx.lineTo(cx - s*0.1, cy + s*0.35)
                    ctx.lineTo(cx - s*0.3, cy + s*0.1)
                    ctx.closePath()
                })
                break
            }
        }
    }
    onColorChanged: c.requestPaint()
    onSizeChanged: c.requestPaint()
    onNameChanged: c.requestPaint()
}
