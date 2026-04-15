import QtQuick
import QtQuick.Layouts

Rectangle {
    property var    topApps:      []
    property var    visualizerData: new Array(32).fill(0)
    // Safe accessor at root level — always accessible from any child
    readonly property var safeViz: Array.isArray(visualizerData) && visualizerData.length === 32
        ? visualizerData : new Array(32).fill(0)
    onSafeVizChanged: waveCanvas.requestPaint()
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

    // Clip left side rounded, right side flat
    layer.enabled: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Image + Visualizer ────────────────────────────────────────────────
        Item {
            Layout.fillWidth:  true
            Layout.preferredHeight: parent.height * 0.52
            clip: true

            // Background fallback color
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(primary.r, primary.g, primary.b, 0.08)
            }

            // Wallpaper/custom image
            Image {
                id: sideImage
                anchors.fill: parent
                source: "file:///home/tanishk/.config/niri-rice/app-launcher/side.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true

                // Dark gradient at bottom so visualizer is readable
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * 0.45
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(surface.r, surface.g, surface.b, 0.9) }
                    }
                }
            }

            // ── Wave visualizer ───────────────────────────────────────────────
            Canvas {
                id: waveCanvas
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                width: parent.width
                height: 64

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var viz = safeViz
                    if (!viz || viz.length === 0) return

                    var n = viz.length
                    var step = width / (n - 1)
                    var baseline = height

                    // Filled wave
                    ctx.beginPath()
                    ctx.moveTo(0, baseline)

                    // First point
                    var x0 = 0
                    var y0 = baseline - viz[0] * (height * 0.85)
                    ctx.lineTo(x0, y0)

                    // Smooth curve through all points using bezier
                    for (var i = 1; i < n; i++) {
                        var x1 = i * step
                        var y1 = baseline - viz[i] * (height * 0.85)
                        var cpx = (x0 + x1) / 2
                        ctx.bezierCurveTo(cpx, y0, cpx, y1, x1, y1)
                        x0 = x1
                        y0 = y1
                    }

                    ctx.lineTo(width, baseline)
                    ctx.closePath()

                    // Gradient fill
                    var grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, Qt.rgba(primary.r, primary.g, primary.b, 0.85))
                    grad.addColorStop(1, Qt.rgba(primary.r, primary.g, primary.b, 0.05))
                    ctx.fillStyle = grad
                    ctx.fill()

                    // Stroke line on top
                    ctx.beginPath()
                    x0 = 0
                    y0 = baseline - viz[0] * (height * 0.85)
                    ctx.moveTo(x0, y0)
                    for (var j = 1; j < n; j++) {
                        var xj = j * step
                        var yj = baseline - viz[j] * (height * 0.85)
                        var cpxj = (x0 + xj) / 2
                        ctx.bezierCurveTo(cpxj, y0, cpxj, yj, xj, yj)
                        x0 = xj
                        y0 = yj
                    }
                    ctx.strokeStyle = Qt.rgba(primary.r, primary.g, primary.b, 1.0)
                    ctx.lineWidth = 2
                    ctx.stroke()
                }

            }
        }

        // ── Divider ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // ── Most used apps ────────────────────────────────────────────────────
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 0

                Text {
                    text: "Frequent"
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.45)
                    font.family: activeFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    bottomPadding: 10
                }

                Repeater {
                    model: topApps

                    Rectangle {
                        width:  parent.width
                        height: 44
                        radius: 10
                        color:  rowHover.containsMouse
                            ? Qt.rgba(primary.r, primary.g, primary.b, 0.12)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 10

                            Image {
                                width: 26; height: 26
                                anchors.verticalCenter: parent.verticalCenter
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: modelData.icon !== ""
                                    ? "file://" + modelData.icon : ""
                                visible: modelData.icon !== "" && status !== Image.Error

                                Rectangle {
                                    visible: parent.status === Image.Error || modelData.icon === ""
                                    anchors.fill: parent
                                    radius: 6
                                    color: primaryContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name.charAt(0)
                                        color: primary
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }
                            }

                            Text {
                                text: modelData.name
                                color: fgColor
                                font.family: activeFont
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: parent.parent.width - 60
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launchRequested(modelData)
                        }
                    }
                }

                // Placeholder when no frequent apps yet
                Item {
                    visible: !Array.isArray(topApps) || topApps.length === 0
                    width: parent.width
                    height: 60
                    Text {
                        anchors.centerIn: parent
                        text: "No recent apps"
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.25)
                        font.family: activeFont
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
