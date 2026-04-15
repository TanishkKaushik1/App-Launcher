import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"

ShellRoot {
    id: root

    property bool   shown:          false
    property var    allApps:        []
    property var    filteredApps:   []
    property var    topApps:        []
    property string searchQuery:    ""
    property int    appsRevision:   0
    property var    visualizerData: new Array(32).fill(0)

    property color  surface:          "#10140f"
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  surfaceContainer: "#1c211b"
    property color  primaryContainer: "#215025"
    property color  tertiary:         "#a1ced5"
    property string activeFont:       "Inter Nerd Font"

    // ── Matugen ──────────────────────────────────────────────────────────────
    Process {
        id: matugenProc
        command: ["sh", "-c", "jq -c . /home/tanishk/.config/niri-rice/matugen/colors.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let c = JSON.parse(text.trim()).colors
                    if (!c) return
                    if (c.surface)           root.surface          = c.surface
                    if (c.on_surface)        root.fgColor          = c.on_surface
                    if (c.primary)           root.primary          = c.primary
                    if (c.surface_container) root.surfaceContainer = c.surface_container
                    if (c.primary_container) root.primaryContainer = c.primary_container
                    if (c.tertiary)          root.tertiary         = c.tertiary
                } catch(e) {}
            }
        }
    }
    Process {
        id: matugenWatcher
        command: ["sh", "-c", "inotifywait -m -e modify /home/tanishk/.config/niri-rice/matugen/colors.json 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: _ => { matugenProc.running = false; matugenProc.running = true }
        }
    }
    Timer {
        interval: 500; running: true; repeat: false
        onTriggered: { matugenProc.running = false; matugenProc.running = true }
    }

    // ── Visualizer ───────────────────────────────────────────────────────────
    Process {
        id: vizProc
        command: ["/home/tanishk/.config/niri-rice/qs-visualizer/target/release/qs-visualizer"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let p = JSON.parse(data.trim())
                    if (Array.isArray(p) && p.length === 32) root.visualizerData = p
                } catch(e) {}
            }
        }
    }

    // ── App list — StdioCollector waits for full output ───────────────────────
    property string listBuffer: ""

    Process {
        id: listProc
        command: ["/home/tanishk/.config/niri-rice/app-launcher/list-apps.sh"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.listBuffer += data
            }
        }
        onRunningChanged: {
            if (!running && root.listBuffer !== "") {
                console.log("listProc done, buffer length:", root.listBuffer.length)
                try {
                    let apps = JSON.parse(root.listBuffer.trim())
                    if (Array.isArray(apps) && apps.length > 0) {
                        console.log("Loaded", apps.length, "apps")
                        root.allApps = apps
                        root.applyFilter()
                        topProc.running = false
                        topProc.running = true
                    } else {
                        console.log("bad response:", root.listBuffer.substring(0, 100))
                    }
                } catch(e) {
                    console.log("parse error:", e, root.listBuffer.substring(0, 100))
                }
                root.listBuffer = ""
            }
        }
    }

    property string topBuffer: ""

    Process {
        id: topProc
        command: ["/home/tanishk/.config/niri-rice/app-launcher/top-apps.sh"]
        running: false
        stdout: SplitParser {
            onRead: data => { root.topBuffer += data }
        }
        onRunningChanged: {
            if (!running && root.topBuffer !== "") {
                try {
                    let names = JSON.parse(root.topBuffer.trim())
                    if (Array.isArray(names)) {
                        root.topApps = names
                            .map(n => root.allApps.find(a => a.name === n))
                            .filter(a => a !== undefined)
                    }
                } catch(e) {}
                root.topBuffer = ""
            }
        }
    }

    Process { id: launchProc; running: false }

    // ── IPC ───────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.shown) root.close()
            else            root.open()
        }
    }

    function open() {
        root.shown = true
        console.log('open() called, starting listProc')
        listProc.running = false
        openTimer.start()
    }

    Timer {
        id: openTimer
        interval: 50
        repeat: false
        onTriggered: {
            console.log('openTimer fired, listProc.running =', listProc.running)
            listProc.running = true
            console.log('listProc.running set to true')
        }
    }

    function close() {
        root.shown        = false
        root.searchQuery  = ""
        root.allApps      = []
        root.filteredApps = []
        root.topApps      = []
    }

    function applyFilter() {
        if (!Array.isArray(root.allApps)) return
        let apps = root.allApps.slice()
        if (root.searchQuery !== "") {
            let q = root.searchQuery.toLowerCase()
            apps = apps.filter(a =>
                a.name.toLowerCase().includes(q) ||
                (a.comment && a.comment.toLowerCase().includes(q))
            )
        }
        root.filteredApps = apps
        root.appsRevision += 1
        console.log("applyFilter: set", apps.length, "apps, revision:", root.appsRevision)
    }

    function launch(app) {
        launchProc.running = false
        launchProc.command = ["python3",
            "/home/tanishk/.config/niri-rice/app-launcher/ipc.py",
            '{"command":"launch","exec":"' + app.exec.replace(/"/g, '\\"') +
            '","name":"' + app.name.replace(/"/g, '\\"') + '"}'
        ]
        launchProc.running = true
        root.close()
    }

    // ── Keep-alive ────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { bottom: true; left: true }
            implicitWidth: 1; implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        }
    }

    // ── Launcher window ───────────────────────────────────────────────────────
    LauncherWindow {
        shown:            root.shown
        filteredApps:     root.filteredApps
        appsRevision:     root.appsRevision
        topApps:          root.topApps
        visualizerData:   root.visualizerData
        searchQuery:      root.searchQuery
        surface:          root.surface
        fgColor:          root.fgColor
        primary:          root.primary
        surfaceContainer: root.surfaceContainer
        primaryContainer: root.primaryContainer
        tertiary:         root.tertiary
        activeFont:       root.activeFont

        onSearchChanged:   function(q)   { root.searchQuery = q; root.applyFilter() }
        onLaunchRequested: function(app) { root.launch(app) }
        onCloseRequested:  function()    { root.close() }
    }
}
