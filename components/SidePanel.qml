import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var    topApps:        []
    property var    visualizerData: new Array(32).fill(0)
    property real   cpuUsage:       0.0
    property real   ramUsage:       0.0
    property real   diskUsage:      0.0   // 0.0–1.0
    property real   netRxKbps:      0.0   // KB/s
    property real   netTxKbps:      0.0   // KB/s
    property string uptimeStr:      ""
    property string dateStr:        ""

    readonly property var safeViz: Array.isArray(visualizerData) && visualizerData.length === 32
        ? visualizerData : new Array(32).fill(0)

    readonly property bool isSilent: {
        var viz = safeViz, sum = 0
        for (var i = 0; i < viz.length; i++) sum += viz[i]
        return sum < 0.05
    }

    onSafeVizChanged: {
        waveCanvas.requestPaint()
        ghostCanvas.requestPaint()
        glowCanvas.requestPaint()
    }

    // Repaints for disk strip
    onDiskUsageChanged:  diskCanvas.requestPaint()
    onNetRxKbpsChanged:  netCanvas.requestPaint()
    onNetTxKbpsChanged:  netCanvas.requestPaint()

    property color  surface:          "#10140f"
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  surfaceContainer: "#1c211b"
    property color  primaryContainer: "#215025"
    property color  tertiary:         "#a1ced5"
    property string activeFont:       "Inter Nerd Font"

    signal launchRequested(var app)

    color: Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, 0.75)
    radius: 22
    layer.enabled: true

    // ── Smooth gauge transitions ──────────────────────────────────────────────
    property real smoothCpu:  cpuUsage
    property real smoothRam:  ramUsage
    property real smoothDisk: diskUsage
    Behavior on smoothCpu  { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on smoothRam  { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on smoothDisk { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    onSmoothCpuChanged:  { cpuGauge.requestPaint();  cpuRipple.requestPaint()  }
    onSmoothRamChanged:  { ramGauge.requestPaint();  ramRipple.requestPaint()  }
    onSmoothDiskChanged: { diskCanvas.requestPaint() }

    // ── Ripple ticker ─────────────────────────────────────────────────────────
    property real ripplePhase: 0.0
    NumberAnimation on ripplePhase {
        from: 0.0; to: 1.0; duration: 2200
        loops: Animation.Infinite; running: true
    }
    onRipplePhaseChanged: { cpuRipple.requestPaint(); ramRipple.requestPaint() }

    // ── Idle wave ticker ──────────────────────────────────────────────────────
    property real idlePhase: 0.0
    NumberAnimation on idlePhase {
        from: 0.0; to: Math.PI * 2; duration: 3500
        loops: Animation.Infinite; running: true
    }
    onIdlePhaseChanged: {
        if (isSilent) {
            waveCanvas.requestPaint()
            ghostCanvas.requestPaint()
            glowCanvas.requestPaint()
        }
    }

    // ── Net smoothing (log scale so idle doesn't look flat) ───────────────────
    function fmtNet(kbps) {
        if (kbps >= 1024) return (kbps/1024).toFixed(1) + " MB/s"
        if (kbps >= 1)    return kbps.toFixed(0)        + " KB/s"
        return "0 KB/s"
    }
    // Map KB/s to 0-1 on a log scale capped at 10 MB/s
    function netScale(kbps) {
        if (kbps <= 0) return 0
        return Math.min(1, Math.log10(1 + kbps) / Math.log10(1 + 10240))
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 0; spacing: 0

        // ── Image + Gauges + Visualizer ───────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height * 0.52
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(primary.r, primary.g, primary.b, 0.08)
            }

            Image {
                id: sideImage
                anchors.fill: parent
                source: "file:///home/tanishk/.config/niri-rice/app-launcher/side.png"
                fillMode: Image.PreserveAspectCrop; smooth: true

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: parent.height * 0.55
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(surface.r, surface.g, surface.b, 0.94) }
                    }
                }
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width; height: parent.height * 0.48
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(surface.r, surface.g, surface.b, 0.72) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // ── CPU gauge — top left ──────────────────────────────────────────
            Item {
                id: cpuBlock
                width: 110; height: 110
                anchors.top: parent.top; anchors.topMargin: 14
                anchors.left: parent.left; anchors.leftMargin: 14

                Canvas {
                    id: cpuRipple; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, val = smoothCpu
                        for (var r = 0; r < 3; r++) {
                            var phase = (ripplePhase + r*0.333) % 1.0
                            ctx.beginPath()
                            ctx.arc(cx, cy, 38+phase*18, 0, Math.PI*2)
                            ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, (1-phase)*(0.10+val*0.30))
                            ctx.lineWidth = 1.5; ctx.stroke()
                        }
                    }
                }
                Canvas {
                    id: cpuGauge; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, r = 34
                        var start = -Math.PI*0.75, sweep = Math.PI*1.5, val = smoothCpu
                        ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep)
                        ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.12)
                        ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        if (val > 0.005) {
                            var heat = Math.min(val*1.4, 1.0)
                            var ar = primary.r+(1.0-primary.r)*heat*0.6
                            var ag = primary.g+(0.65-primary.g)*heat*0.6
                            var ab = primary.b*(1.0-heat*0.7)
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.28)
                            ctx.lineWidth = 11; ctx.lineCap = "round"; ctx.stroke()
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 1.0)
                            ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        }
                        ctx.fillStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.90)
                        ctx.font = "bold 15px sans-serif"
                        ctx.textAlign = "center"; ctx.textBaseline = "middle"
                        ctx.fillText("▦", cx, cy-8)
                        ctx.font = "bold 11px sans-serif"
                        ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.90)
                        ctx.fillText(Math.round(val*100)+"%", cx, cy+8)
                    }
                }
                Text {
                    text: "CPU"; anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; bottomPadding: 2
                    font.family: activeFont; font.pixelSize: 9; font.weight: Font.Medium
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.45)
                }
            }

            // ── Centre: date + uptime ─────────────────────────────────────────
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 18
                width: parent.width - 268; height: 110

                Column {
                    anchors.centerIn: parent; spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dateStr !== "" ? dateStr : Qt.formatDate(new Date(), "ddd, dd MMM")
                        font.family: activeFont; font.pixelSize: 13; font.weight: Font.Medium
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.88)
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 36; height: 1
                        color: Qt.rgba(primary.r, primary.g, primary.b, 0.50)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: uptimeStr !== "" ? uptimeStr : ""
                        visible: uptimeStr !== ""
                        font.family: activeFont; font.pixelSize: 10
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.58)
                    }
                }
            }

            // ── RAM gauge — top right ─────────────────────────────────────────
            Item {
                id: ramBlock
                width: 110; height: 110
                anchors.top: parent.top; anchors.topMargin: 14
                anchors.right: parent.right; anchors.rightMargin: 14

                Canvas {
                    id: ramRipple; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, val = smoothRam
                        for (var r = 0; r < 3; r++) {
                            var phase = (ripplePhase + r*0.333 + 0.5) % 1.0
                            ctx.beginPath()
                            ctx.arc(cx, cy, 38+phase*18, 0, Math.PI*2)
                            ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, (1-phase)*(0.10+val*0.30))
                            ctx.lineWidth = 1.5; ctx.stroke()
                        }
                    }
                }
                Canvas {
                    id: ramGauge; anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width/2, cy = height/2, r = 34
                        var start = -Math.PI*0.75, sweep = Math.PI*1.5, val = smoothRam
                        ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep)
                        ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.12)
                        ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        if (val > 0.005) {
                            var heat = Math.min(val*1.3, 1.0)
                            var ar = tertiary.r+(1.0-tertiary.r)*heat*0.6
                            var ag = tertiary.g*(1.0-heat*0.55)
                            var ab = tertiary.b*(1.0-heat*0.75)
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.28)
                            ctx.lineWidth = 11; ctx.lineCap = "round"; ctx.stroke()
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 1.0)
                            ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                        }
                        ctx.fillStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.90)
                        ctx.font = "bold 15px sans-serif"
                        ctx.textAlign = "center"; ctx.textBaseline = "middle"
                        ctx.fillText("▤", cx, cy-8)
                        ctx.font = "bold 11px sans-serif"
                        ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.90)
                        ctx.fillText(Math.round(val*100)+"%", cx, cy+8)
                    }
                }
                Text {
                    text: "RAM"; anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; bottomPadding: 2
                    font.family: activeFont; font.pixelSize: 9; font.weight: Font.Medium
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.45)
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // ── Info strip — disk arc left, net speeds right ───────────────────
            // Sits in the dead zone between gauge row and wave
            // ══════════════════════════════════════════════════════════════════
            Item {
                anchors.left:   parent.left;  anchors.leftMargin:  12
                anchors.right:  parent.right; anchors.rightMargin: 12
                anchors.bottom: parent.bottom; anchors.bottomMargin: 70
                height: 52

                // ── Disk mini arc + label (left half) ─────────────────────────
                Item {
                    id: diskItem
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.45
                    height: parent.height

                    Canvas {
                        id: diskCanvas
                        width: 44; height: 44
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width/2, cy = height/2, r = 18
                            var start = -Math.PI*0.75, sweep = Math.PI*1.5
                            var val = smoothDisk

                            // Track
                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep)
                            ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.12)
                            ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()

                            // Fill — warms to amber when disk is nearly full
                            if (val > 0.005) {
                                var heat = Math.min((val - 0.5) * 2, 1.0)  // starts warming at 50%
                                heat = Math.max(0, heat)
                                var dr = primary.r + (1.0  - primary.r) * heat * 0.7
                                var dg = primary.g + (0.6  - primary.g) * heat * 0.7
                                var db = primary.b * (1.0  - heat * 0.8)
                                // glow
                                ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                                ctx.strokeStyle = Qt.rgba(dr, dg, db, 0.25)
                                ctx.lineWidth = 8; ctx.lineCap = "round"; ctx.stroke()
                                // sharp
                                ctx.beginPath(); ctx.arc(cx, cy, r, start, start+sweep*val)
                                ctx.strokeStyle = Qt.rgba(dr, dg, db, 1.0)
                                ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()
                            }

                            // Icon + pct inside
                            ctx.fillStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.85)
                            ctx.font = "bold 10px sans-serif"
                            ctx.textAlign = "center"; ctx.textBaseline = "middle"
                            ctx.fillText("◉", cx, cy-5)
                            ctx.font = "bold 8px sans-serif"
                            ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.85)
                            ctx.fillText(Math.round(val*100)+"%", cx, cy+6)
                        }
                    }

                    // Label to the right of disk arc
                    Column {
                        anchors.left: diskCanvas.right; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "disk"
                            font.family: activeFont; font.pixelSize: 9; font.weight: Font.Medium
                            color: Qt.rgba(primary.r, primary.g, primary.b, 0.70)
                        }
                        Text {
                            text: Math.round(smoothDisk * 100) + "% used"
                            font.family: activeFont; font.pixelSize: 8
                            color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.50)
                        }
                    }
                }

                // Thin vertical separator
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 32
                    color: Qt.rgba(1, 1, 1, 0.07)
                }

                // ── Network TX/RX (right half) ────────────────────────────────
                Item {
                    id: netItem
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.50
                    height: parent.height

                    Canvas {
                        id: netCanvas
                        width: 44; height: 44
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width/2, cy = height/2

                            // Two half-arcs: top = RX (down arrow), bottom = TX (up arrow)
                            // RX arc: top semicircle
                            var rxVal = netScale(netRxKbps)
                            var txVal = netScale(netTxKbps)

                            // RX track (top half)
                            ctx.beginPath()
                            ctx.arc(cx, cy, 18, -Math.PI, 0)
                            ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.10)
                            ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()

                            // RX fill
                            if (rxVal > 0.01) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, -Math.PI, -Math.PI + Math.PI*rxVal)
                                ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.28)
                                ctx.lineWidth = 8; ctx.lineCap = "round"; ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, -Math.PI, -Math.PI + Math.PI*rxVal)
                                ctx.strokeStyle = Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 1.0)
                                ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()
                            }

                            // TX track (bottom half)
                            ctx.beginPath()
                            ctx.arc(cx, cy, 18, 0, Math.PI)
                            ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.10)
                            ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()

                            // TX fill
                            if (txVal > 0.01) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, 0, Math.PI*txVal)
                                ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.28)
                                ctx.lineWidth = 8; ctx.lineCap = "round"; ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(cx, cy, 18, 0, Math.PI*txVal)
                                ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 1.0)
                                ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()
                            }

                            // Centre icon
                            ctx.fillStyle = Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.55)
                            ctx.font = "bold 11px sans-serif"
                            ctx.textAlign = "center"; ctx.textBaseline = "middle"
                            ctx.fillText("⇅", cx, cy)
                        }
                    }

                    // RX / TX text labels
                    Column {
                        anchors.left: netCanvas.right; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Row {
                            spacing: 4
                            Text {
                                text: "↓"
                                font.pixelSize: 9
                                color: Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.80)
                            }
                            Text {
                                text: fmtNet(netRxKbps)
                                font.family: activeFont; font.pixelSize: 9
                                color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.65)
                            }
                        }

                        Row {
                            spacing: 4
                            Text {
                                text: "↑"
                                font.pixelSize: 9
                                color: Qt.rgba(primary.r, primary.g, primary.b, 0.80)
                            }
                            Text {
                                text: fmtNet(netTxKbps)
                                font.family: activeFont; font.pixelSize: 9
                                color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.65)
                            }
                        }
                    }
                }
            }

            // ── Radial glow bloom behind wave ─────────────────────────────────
            Canvas {
                id: glowCanvas
                anchors.bottom: parent.bottom; anchors.bottomMargin: -10
                width: parent.width; height: 110
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var viz = safeViz, sum = 0
                    for (var k = 0; k < viz.length; k++) sum += viz[k]
                    var avg = isSilent ? 0.04 + 0.02*Math.sin(idlePhase) : sum/viz.length
                    var outerR = 140 + avg*80
                    var grad = ctx.createRadialGradient(width/2, height, 0, width/2, height, outerR)
                    grad.addColorStop(0.0,  Qt.rgba(primary.r, primary.g, primary.b, 0.20+avg*0.18))
                    grad.addColorStop(0.35, Qt.rgba(primary.r, primary.g, primary.b, 0.08+avg*0.08))
                    grad.addColorStop(1.0,  "transparent")
                    ctx.fillStyle = grad; ctx.fillRect(0, 0, width, height)
                }
            }

            // ── Ghost echo wave ───────────────────────────────────────────────
            Canvas {
                id: ghostCanvas
                anchors.bottom: parent.bottom; anchors.bottomMargin: 0
                width: parent.width; height: 64
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var viz = safeViz, n = viz.length, step = width/(n-1), baseline = height
                    var eff = []
                    for (var k = 0; k < n; k++)
                        eff.push(isSilent ? 0.04+0.03*Math.sin(idlePhase+k*0.4) : viz[k])
                    ctx.beginPath(); ctx.moveTo(0, baseline)
                    var x0 = 0, y0 = baseline - eff[0]*(height*0.85) + 10; ctx.lineTo(x0, y0)
                    for (var i = 1; i < n; i++) {
                        var x1 = i*step, y1 = baseline - eff[i]*(height*0.85) + 10
                        ctx.bezierCurveTo((x0+x1)/2, y0, (x0+x1)/2, y1, x1, y1)
                        x0 = x1; y0 = y1
                    }
                    ctx.lineTo(width, baseline); ctx.closePath()
                    var grad = ctx.createLinearGradient(0,0,0,height)
                    grad.addColorStop(0, Qt.rgba(primary.r, primary.g, primary.b, 0.14))
                    grad.addColorStop(1, Qt.rgba(primary.r, primary.g, primary.b, 0.0))
                    ctx.fillStyle = grad; ctx.fill()
                    ctx.beginPath(); x0 = 0; y0 = baseline - eff[0]*(height*0.85)+10; ctx.moveTo(x0,y0)
                    for (var j = 1; j < n; j++) {
                        var xj = j*step, yj = baseline - eff[j]*(height*0.85)+10
                        ctx.bezierCurveTo((x0+xj)/2, y0, (x0+xj)/2, yj, xj, yj)
                        x0 = xj; y0 = yj
                    }
                    ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 0.18)
                    ctx.lineWidth = 1.5; ctx.stroke()
                }
            }

            // ── Main wave ─────────────────────────────────────────────────────
            Canvas {
                id: waveCanvas
                anchors.bottom: parent.bottom; anchors.bottomMargin: 0
                width: parent.width; height: 64
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var viz = safeViz, n = viz.length, step = width/(n-1), baseline = height
                    var eff = []
                    for (var k = 0; k < n; k++)
                        eff.push(isSilent ? 0.06+0.04*Math.sin(idlePhase+k*0.4) : viz[k])
                    ctx.beginPath(); ctx.moveTo(0, baseline)
                    var x0 = 0, y0 = baseline - eff[0]*(height*0.85); ctx.lineTo(x0, y0)
                    for (var i = 1; i < n; i++) {
                        var x1 = i*step, y1 = baseline - eff[i]*(height*0.85)
                        ctx.bezierCurveTo((x0+x1)/2, y0, (x0+x1)/2, y1, x1, y1)
                        x0 = x1; y0 = y1
                    }
                    ctx.lineTo(width, baseline); ctx.closePath()
                    var grad = ctx.createLinearGradient(0,0,0,height)
                    grad.addColorStop(0, Qt.rgba(primary.r, primary.g, primary.b, isSilent ? 0.30 : 0.85))
                    grad.addColorStop(1, Qt.rgba(primary.r, primary.g, primary.b, 0.03))
                    ctx.fillStyle = grad; ctx.fill()
                    ctx.beginPath(); x0=0; y0=baseline-eff[0]*(height*0.85); ctx.moveTo(x0,y0)
                    for (var j = 1; j < n; j++) {
                        var xj = j*step, yj = baseline - eff[j]*(height*0.85)
                        ctx.bezierCurveTo((x0+xj)/2, y0, (x0+xj)/2, yj, xj, yj)
                        x0 = xj; y0 = yj
                    }
                    ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, isSilent ? 0.35 : 1.0)
                    ctx.lineWidth = isSilent ? 1.5 : 2; ctx.stroke()
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // ── Most used apps ────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 0

                Text {
                    text: "Frequent"
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.45)
                    font.family: activeFont; font.pixelSize: 10; font.weight: Font.Medium
                    bottomPadding: 10
                }

                Repeater {
                    model: topApps
                    Rectangle {
                        width: parent.width; height: 44; radius: 10
                        color: rowHover.containsMouse
                            ? Qt.rgba(primary.r, primary.g, primary.b, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8; spacing: 10
                            Image {
                                width: 26; height: 26
                                anchors.verticalCenter: parent.verticalCenter
                                fillMode: Image.PreserveAspectFit; smooth: true
                                source: modelData.icon !== "" ? "file://"+modelData.icon : ""
                                visible: modelData.icon !== "" && status !== Image.Error
                                Rectangle {
                                    visible: parent.status === Image.Error || modelData.icon === ""
                                    anchors.fill: parent; radius: 6; color: primaryContainer
                                    Text { anchors.centerIn: parent; text: modelData.name.charAt(0)
                                        color: primary; font.pixelSize: 13; font.bold: true }
                                }
                            }
                            Text {
                                text: modelData.name; color: fgColor
                                font.family: activeFont; font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight; width: parent.parent.width - 60
                            }
                        }
                        MouseArea {
                            id: rowHover; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: launchRequested(modelData)
                        }
                    }
                }

                Item {
                    visible: !Array.isArray(topApps) || topApps.length === 0
                    width: parent.width; height: 60
                    Text {
                        anchors.centerIn: parent; text: "No recent apps"
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.25)
                        font.family: activeFont; font.pixelSize: 11
                    }
                }
            }
        }
    }
}
