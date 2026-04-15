import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    property var    filteredApps: []
    property int    appsRevision:  0
    property var safeApps: appsRevision >= 0 && Array.isArray(filteredApps) ? filteredApps : []
    onAppsRevisionChanged: console.log("AppGrid sees revision:", appsRevision, "filteredApps.length:", Array.isArray(filteredApps) ? filteredApps.length : "NOT ARRAY")
    property string searchQuery:  ""
    property bool   shown:        false
    property color  surface:          "#10140f"
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  surfaceContainer: "#1c211b"
    property color  primaryContainer: "#215025"
    property string activeFont:       "Inter Nerd Font"

    signal searchChanged(string q)
    signal launchRequested(var app)
    signal closeRequested()

    color: Qt.rgba(surface.r, surface.g, surface.b, 0.75)
    radius: 22

    // Flat left edge to join SidePanel
    layer.enabled: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // ── Search bar ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: 22
            color: surfaceContainer
            border.color: searchField.activeFocus
                ? Qt.rgba(primary.r, primary.g, primary.b, 0.7)
                : Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.leftMargin:  14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: "󰍉"
                    color: primary
                    font.family: activeFont
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - 36
                    height: 44

                    Text {
                        visible: searchField.text === ""
                        text: "Search apps..."
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.3)
                        font.pixelSize: 13
                        font.family: activeFont
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 13
                        font.family: activeFont
                        color: fgColor
                        focus: shown

                        onTextChanged: searchChanged(text)
                        Keys.onEscapePressed: closeRequested()
                        Keys.onReturnPressed: {
                            if (Array.isArray(filteredApps) && filteredApps.length > 0)
                                launchRequested(filteredApps[0])
                        }
                    }
                }
            }
        }

        // ── App count ─────────────────────────────────────────────────────────
        Text {
            text: (appsRevision >= 0 && Array.isArray(filteredApps) ? filteredApps.length : 0) + " apps"
            color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.3)
            font.family: activeFont
            font.pixelSize: 10
            Layout.leftMargin: 4
        }

        // ── App grid ──────────────────────────────────────────────────────────
        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            GridView {
                id: grid
                width: parent.width
                cellWidth:  Math.floor(width / 5)
                cellHeight: 110
                model: appsRevision >= 0 && Array.isArray(filteredApps) ? filteredApps : []
                clip: true

                delegate: AppCard {
                    width:  grid.cellWidth
                    height: grid.cellHeight
                    appData: modelData
                    fgColor:        fgColor
                    primary:        primary
                    primaryContainer: primaryContainer
                    activeFont:     activeFont
                    onClicked: launchRequested(modelData)
                }
            }
        }

    }

    // ── Reset search when hidden ──────────────────────────────────────────────
    onShownChanged: {
        if (!shown) searchField.text = ""
        else        searchField.forceActiveFocus()
    }
}
