import QtQuick

Item {
    property var    appData
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  primaryContainer: "#215025"
    property string activeFont:       "Inter Nerd Font"

    signal clicked()

    Rectangle {
        anchors.fill:    parent
        anchors.margins: 5
        radius: 14
        color: hover.containsMouse
            ? Qt.rgba(primary.r, primary.g, primary.b, 0.13)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Column {
            anchors.centerIn: parent
            spacing: 8
            width: parent.width - 12

            // ── Icon ──────────────────────────────────────────────────────────
            Item {
                width: 48; height: 48
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    id: iconImg
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: (appData.icon && appData.icon !== "")
                        ? "file://" + appData.icon : ""
                    visible: source !== "" && status !== Image.Error
                }

                // Letter fallback
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    visible: !iconImg.visible || iconImg.status === Image.Error
                    color: primaryContainer
                    Text {
                        anchors.centerIn: parent
                        text: appData.name ? appData.name.charAt(0).toUpperCase() : "?"
                        color: primary
                        font.pixelSize: 22
                        font.bold: true
                    }
                }
            }

            // ── Name ──────────────────────────────────────────────────────────
            Text {
                text: appData.name || ""
                color: fgColor
                font.family: activeFont
                font.pixelSize: 11
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.parent.clicked()
        }
    }
}
