import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
    id: launcherItem

    property bool   shown:            false
    property int    appsRevision:     0
    property var    filteredApps:     []
    property var    topApps:          []
    property var    visualizerData:   new Array(32).fill(0)
    property string searchQuery:      ""
    property real   cpuUsage:         0.0
    property real   ramUsage:         0.0
    property real   diskUsage:        0.0
    property real   netRxKbps:        0.0
    property real   netTxKbps:        0.0
    property string uptimeStr:        ""
    property string dateStr:          ""
    property color  surface:          "#10140f"
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  surfaceContainer: "#1c211b"
    property color  primaryContainer: "#215025"
    property color  tertiary:         "#a1ced5"
    property string activeFont:       "Inter Nerd Font"

    signal searchChanged(string q)
    signal launchRequested(var app)
    signal closeRequested()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: launcherItem.shown
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            visible: launcherItem.shown

            MouseArea {
                anchors.fill: parent
                onClicked: launcherItem.closeRequested()

                Rectangle {
                    anchors.centerIn: parent
                    width:  Math.min(parent.width  * 0.65, 860)
                    height: Math.min(parent.height * 0.68, 580)
                    color:  "transparent"
                    radius: 22
                    layer.enabled: true
                    clip: true

                    MouseArea { anchors.fill: parent; onClicked: {} }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        SidePanel {
                            Layout.preferredWidth: 300
                            Layout.fillHeight:     true
                            topApps:          launcherItem.topApps
                            visualizerData:   launcherItem.visualizerData
                            cpuUsage:         launcherItem.cpuUsage
                            ramUsage:         launcherItem.ramUsage
                            diskUsage:        launcherItem.diskUsage
                            netRxKbps:        launcherItem.netRxKbps
                            netTxKbps:        launcherItem.netTxKbps
                            uptimeStr:        launcherItem.uptimeStr
                            dateStr:          launcherItem.dateStr
                            surface:          launcherItem.surface
                            fgColor:          launcherItem.fgColor
                            primary:          launcherItem.primary
                            surfaceContainer: launcherItem.surfaceContainer
                            primaryContainer: launcherItem.primaryContainer
                            tertiary:         launcherItem.tertiary
                            activeFont:       launcherItem.activeFont
                            onLaunchRequested: function(app) { launcherItem.launchRequested(app) }
                        }

                        AppGrid {
                            Layout.fillWidth:  true
                            Layout.fillHeight: true
                            filteredApps:     launcherItem.filteredApps
                            appsRevision:     launcherItem.appsRevision
                            searchQuery:      launcherItem.searchQuery
                            shown:            launcherItem.shown
                            surface:          launcherItem.surface
                            fgColor:          launcherItem.fgColor
                            primary:          launcherItem.primary
                            surfaceContainer: launcherItem.surfaceContainer
                            primaryContainer: launcherItem.primaryContainer
                            activeFont:       launcherItem.activeFont
                            onSearchChanged:   function(q)   { launcherItem.searchChanged(q) }
                            onLaunchRequested: function(app) { launcherItem.launchRequested(app) }
                            onCloseRequested:  function()    { launcherItem.closeRequested() }
                        }
                    }
                }
            }
        }
    }
}
