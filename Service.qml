import QtQuick
import Quickshell
import Quickshell.Io

// Headless singleton. Syncthing's REST API is local HTTP and answers in
// milliseconds, so unlike a remote backup repository the whole picture can be
// polled: folder states, how far behind each one is, and how many peers are
// actually connected.
Item {
  id: root
  visible: false
  width: 0
  height: 0

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.epicbagel.syncbar"
  readonly property string sourceDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string bin: sourceDir ? sourceDir + "/bin/syncbar" : ""

  // ------------------------------------------------------------------- state
  property string state: "unknown"   // ok | syncing | disconnected | error | offline | nokey
  property bool running: false
  property bool reachable: false
  property string version: ""
  property var folders: []
  property int devicesTotal: 0
  property int devicesConnected: 0
  property real needBytes: 0
  property real globalBytes: 0
  property int percent: 100
  property int errors: 0

  readonly property bool syncing: state === "syncing"
  readonly property bool disconnected: state === "disconnected"
  readonly property bool failed: state === "error" || state === "offline" || state === "nokey"

  // ---------------------------------------------------------------- commands
  function run(args) {
    if (!bin) return
    Quickshell.execDetached([bin].concat(args))
    settle.restart()
  }
  function rescan() { run(["rescan"]) }
  function openUi() { run(["open"]) }

  // ------------------------------------------------------------- formatting
  function humanBytes(n) {
    var b = Number(n) || 0
    if (b <= 0) return "0 B"
    var u = ["B", "KB", "MB", "GB", "TB"]
    var i = Math.min(u.length - 1, Math.floor(Math.log(b) / Math.log(1024)))
    var v = b / Math.pow(1024, i)
    return (v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + u[i]
  }

  function headline() {
    if (state === "nokey") return "No API key found"
    if (state === "offline") return running ? "Syncthing not answering" : "Syncthing is not running"
    if (state === "error") return errors + (errors === 1 ? " folder error" : " folder errors")
    if (state === "syncing") return "Syncing, " + humanBytes(needBytes) + " to go"
    if (state === "disconnected") return "In sync, but no peer connected"
    return "In sync"
  }

  // ------------------------------------------------------------------ status
  function refresh() {
    if (!bin || proc.running) return
    proc.command = [bin, "status"]
    proc.running = true
  }

  Timer {
    interval: 5000
    repeat: true
    running: root.bin !== ""
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Timer { id: settle; interval: 800; onTriggered: root.refresh() }

  Process {
    id: proc
    stdout: StdioCollector {
      onStreamFinished: {
        var s
        try { s = JSON.parse(this.text) } catch (e) { return }
        if (!s || typeof s !== "object") return
        root.state = String(s.state || "unknown")
        root.running = s.running === true
        root.reachable = s.reachable === true
        root.version = String(s.version || "")
        root.folders = Array.isArray(s.folders) ? s.folders : []
        root.devicesTotal = Number(s.devices ? s.devices.total : 0) || 0
        root.devicesConnected = Number(s.devices ? s.devices.connected : 0) || 0
        root.needBytes = Number(s.needBytes) || 0
        root.globalBytes = Number(s.globalBytes) || 0
        root.percent = Number(s.percent)
        root.errors = Number(s.errors) || 0
      }
    }
  }

  onBinChanged: root.refresh()

  IpcHandler {
    target: "syncbar"
    function status(): string {
      return JSON.stringify({ state: root.state, percent: root.percent,
                              connected: root.devicesConnected, of: root.devicesTotal })
    }
    function rescan(): string { root.rescan(); return "ok" }
    function open(): string { root.openUi(); return "ok" }
  }
}
