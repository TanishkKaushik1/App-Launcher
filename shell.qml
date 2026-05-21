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

    // ── System stats ──────────────────────────────────────────────────────────
    property real   cpuUsage:       0.0   // 0.0–1.0
    property real   ramUsage:       0.0   // 0.0–1.0
    property real   diskUsage:      0.0   // 0.0–1.0  (root filesystem)
    property real   netRxKbps:      0.0   // KB/s receive
    property real   netTxKbps:      0.0   // KB/s transmit
    property string uptimeStr:      ""
    property string dateStr:        ""

    property color  surface:          "#10140f"
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  surfaceContainer: "#1c211b"
    property color  primaryContainer: "#215025"
    property color  tertiary:         "#a1ced5"
    property string activeFont:       "Inter Nerd Font"

    // ── Matugen ───────────────────────────────────────────────────────────────
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

    // ── Visualizer ────────────────────────────────────────────────────────────
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

    // ── CPU stat poller ───────────────────────────────────────────────────────
    property real _cpuPrevIdle:  0
    property real _cpuPrevTotal: 0

    Process {
        id: cpuProc
        command: ["sh", "-c", "awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    let f = data.trim().split(" ").map(Number)
                    let idle  = f[3] + f[4]
                    let total = f[0]+f[1]+f[2]+f[3]+f[4]+f[5]+f[6]
                    let dIdle  = idle  - root._cpuPrevIdle
                    let dTotal = total - root._cpuPrevTotal
                    if (dTotal > 0)
                        root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle/dTotal))
                    root._cpuPrevIdle  = idle
                    root._cpuPrevTotal = total
                } catch(e) {}
            }
        }
    }

    // ── RAM stat poller ───────────────────────────────────────────────────────
    Process {
        id: ramProc
        command: ["sh", "-c", "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t,a}' /proc/meminfo"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    let f = data.trim().split(" ").map(Number)
                    if (f[0] > 0) root.ramUsage = Math.max(0, Math.min(1, (f[0]-f[1])/f[0]))
                } catch(e) {}
            }
        }
    }

    // ── Disk usage poller (root filesystem) ───────────────────────────────────
    Process {
        id: diskProc
        // df gives Use% as integer 0-100
        command: ["sh", "-c", "df / | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    let v = parseInt(data.trim())
                    if (!isNaN(v)) root.diskUsage = Math.max(0, Math.min(1, v/100))
                } catch(e) {}
            }
        }
    }

    // ── Network poller ────────────────────────────────────────────────────────
    // Reads /proc/net/dev twice 1s apart, computes KB/s delta
    property real _netPrevRx: 0
    property real _netPrevTx: 0

    Process {
        id: netProc
        // Sum all non-lo interfaces rx (col2) and tx (col10)
        command: ["sh", "-c",
            "awk '/^ *(eth|en|wl|wlan|wlp|eno|enp)/{rx+=$2;tx+=$10}END{print rx,tx}' /proc/net/dev"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    let f = data.trim().split(" ").map(Number)
                    let rx = f[0], tx = f[1]
                    if (root._netPrevRx > 0) {
                        // divide by 1024 for KB, divide by poll interval (2s)
                        root.netRxKbps = Math.max(0, (rx - root._netPrevRx) / 1024 / 2)
                        root.netTxKbps = Math.max(0, (tx - root._netPrevTx) / 1024 / 2)
                    }
                    root._netPrevRx = rx
                    root._netPrevTx = tx
                } catch(e) {}
            }
        }
    }

    // ── Uptime + date poller ──────────────────────────────────────────────────
    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/up //' && date '+%a, %d %b'"]
        running: false
        property string buf: ""
        stdout: SplitParser {
            onRead: data => { uptimeProc.buf += data + "\n" }
        }
        onRunningChanged: {
            if (!running && buf !== "") {
                let lines = buf.trim().split("\n")
                root.uptimeStr = lines[0] || ""
                root.dateStr   = lines[1] || ""
                buf = ""
            }
        }
    }

    // ── Single timer fires all pollers every 2 s ──────────────────────────────
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuProc.running    = false; cpuProc.running    = true
            ramProc.running    = false; ramProc.running    = true
            diskProc.running   = false; diskProc.running   = true
            netProc.running    = false; netProc.running    = true
            uptimeProc.running = false; uptimeProc.running = true
        }
    }

    // ── App list ──────────────────────────────────────────────────────────────
    property string listBuffer: ""

    Process {
        id: listProc
        command: ["/home/tanishk/.config/niri-rice/app-launcher/list-apps.sh"]
        running: false
        stdout: SplitParser {
            onRead: data => { root.listBuffer += data }
        }
        onRunningChanged: {
            if (!running && root.listBuffer !== "") {
                try {
                    let apps = JSON.parse(root.listBuffer.trim())
                    if (Array.isArray(apps) && apps.length > 0) {
                        root.allApps = apps
                        root.applyFilter()
                        topProc.running = false
                        topProc.running = true
                    }
                } catch(e) {}
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
        listProc.running = false
        openTimer.start()
    }

    Timer {
        id: openTimer; interval: 50; repeat: false
        onTriggered: { listProc.running = true }
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
        cpuUsage:         root.cpuUsage
        ramUsage:         root.ramUsage
        diskUsage:        root.diskUsage
        netRxKbps:        root.netRxKbps
        netTxKbps:        root.netTxKbps
        uptimeStr:        root.uptimeStr
        dateStr:          root.dateStr
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
