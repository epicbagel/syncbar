import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.epicbagel.syncbar"
  manageIpc: false

  readonly property var sync: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool showLabel: setting("showLabel", true) === true
  readonly property bool warnDisconnected: setting("warnDisconnected", true) === true

  // U+F0450, a circular arrow. One identity glyph with state carried by
  // colour, so the widget does not change shape as it works.
  readonly property string glyph: "󰑐"

  readonly property color stateColor: {
    if (!sync) return Qt.darker(barForeground, 1.6)
    if (sync.failed) return root.urgent
    if (sync.disconnected && root.warnDisconnected) return root.urgent
    if (sync.away) return Qt.darker(barForeground, 1.35)
    if (sync.syncing) return Color.accent
    return barForeground
  }

  // Text only when there is something to say. Every other label on the bar is
  // a value - 11m, 32.6G, 63C - so a widget that writes "ok" beside them is
  // both noise and the odd one out. Healthy means the icon alone.
  readonly property string shortLabel: {
    if (!sync) return ""
    if (sync.state === "nokey" || sync.state === "offline") return "off"
    if (sync.syncing) return sync.percent + "%"
    if (sync.disconnected) return sync.sinceSeen() !== "" ? sync.sinceSeen() : "0/" + sync.devicesTotal
    if (sync.errors > 0) return String(sync.errors)
    return ""
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: bar ? bar.barSize : Style.space(26)

  WidgetButton {
    id: button
    bar: root.bar
    anchors.centerIn: parent
    text: root.showLabel && root.shortLabel !== "" ? root.glyph + "  " + root.shortLabel : root.glyph
    tooltipText: root.sync ? root.sync.headline() : "Syncthing"
    foreground: root.stateColor
    onPressed: function (btn) {
      if (btn === Qt.MiddleButton && root.sync) root.sync.rescan()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    bar: root.bar
    anchorItem: button
    owner: root
    open: root.opened
    popoutSwitching: root.popoutSwitching
    popoutSwitchClosing: root.popoutSwitchClosing
    contentWidth: Style.space(330)
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))
    padding: Style.space(14)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(12)

      Text {
        width: parent.width
        text: root.sync ? root.sync.headline() : "Syncthing"
        color: root.sync && (root.sync.failed || (root.sync.disconnected && root.warnDisconnected))
               ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        wrapMode: Text.Wrap
      }

      // Progress only means something while there is something to catch up on.
      Rectangle {
        width: parent.width
        height: Style.space(3)
        radius: height / 2
        visible: !!root.sync && root.sync.syncing
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
        Rectangle {
          height: parent.height
          radius: parent.radius
          color: Color.accent
          width: parent.width * Math.max(0, Math.min(100, root.sync ? root.sync.percent : 0)) / 100
        }
      }

      PanelSeparator { width: parent.width }

      PanelSectionHeader {
        text: "FOLDERS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.sync ? root.sync.folders : []
        Row {
          required property var modelData
          width: column.width
          Text {
            width: parent.width * 0.55
            elide: Text.ElideRight
            text: modelData ? String(modelData.label) : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            width: parent.width * 0.45
            horizontalAlignment: Text.AlignRight
            text: {
              if (!modelData) return ""
              if (modelData.errors > 0) return modelData.errors + " errors"
              if (modelData.needFiles > 0)
                return modelData.needFiles + " behind"
              return String(modelData.state)
            }
            color: modelData && modelData.errors > 0 ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }
      }

      Text {
        visible: !!root.sync && root.sync.folders.length === 0
        width: parent.width
        text: root.sync && root.sync.reachable ? "No folders configured" : "Not reachable"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      PanelSeparator { width: parent.width }

      Row {
        width: parent.width
        Text {
          width: parent.width / 2
          text: "Peers connected"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          width: parent.width / 2
          horizontalAlignment: Text.AlignRight
          text: {
            if (!root.sync) return ""
            var base = root.sync.devicesConnected + " of " + root.sync.devicesTotal
            var seen = root.sync.sinceSeen()
            return root.sync.devicesConnected === 0 && seen !== "" ? base + "  ·  seen " + seen + " ago" : base
          }
          // Zero peers is the quiet failure this widget exists to catch.
          // Red only once it has been gone longer than the grace period.
          color: root.sync && root.sync.disconnected ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      Row {
        width: parent.width
        visible: !!root.sync && root.sync.version !== ""
        Text {
          width: parent.width / 2
          text: "Version"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          width: parent.width / 2
          horizontalAlignment: Text.AlignRight
          text: root.sync ? root.sync.version : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)
        Button {
          text: "Rescan"
          bordered: true
          enabled: !!root.sync && root.sync.reachable
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          onClicked: if (root.sync) root.sync.rescan()
        }
        Button {
          text: "Web UI"
          bordered: true
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          onClicked: {
            if (root.sync) root.sync.openUi()
            root.close()
          }
        }
      }
    }
  }
}
