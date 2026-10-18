import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry point and popup. All device I/O lives in bin/jbl-quantumd, which
// rewrites state.json on every change; this file only watches and renders it.
Panel {
  id: root
  moduleName: "cluxnei.jbl-quantum"
  ipcTarget: "cluxnei.jbl-quantum"
  manageIpc: false

  property var state: null
  property real now: Date.now() / 1000

  readonly property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/jbl-quantum/state.json"
  readonly property var stats: state && state.stats ? state.stats : ({})
  readonly property bool linked: state !== null && state.dongle === true && state.connected === true
  readonly property int battery: state && state.battery !== null && state.battery !== undefined ? state.battery : -1
  readonly property int lowLevel: setting("lowLevel", 20)
  readonly property bool low: linked && battery >= 0 && battery <= lowLevel && !state.charging
  readonly property bool hidden: setting("hideWhenAbsent", true) === true && (state === null || state.dongle !== true)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string barText: {
    var glyph = Model.barGlyph(state)
    if (!linked || battery < 0 || setting("showPercent", true) !== true) return glyph
    return glyph + " " + battery + "%"
  }
  readonly property string tooltip: {
    if (!linked) return "JBL Quantum · " + Model.statusLine(state)
    var extra = Model.remainingText(state)
    return "JBL Quantum · " + battery + "%" + (extra ? " · " + extra : "")
  }

  function useAsOutput() {
    // Both sink and mic source, matched by the USB device name PipeWire assigns.
    Quickshell.execDetached(["sh", "-c",
      "s=$(pactl list short sinks | awk '/JBL_Quantum/{print $2; exit}'); [ -n \"$s\" ] && pactl set-default-sink \"$s\"; " +
      "m=$(pactl list short sources | awk '/JBL_Quantum/ && !/monitor/{print $2; exit}'); [ -n \"$m\" ] && pactl set-default-source \"$m\""])
  }

  visible: !hidden
  implicitWidth: hidden ? 0 : button.implicitWidth
  implicitHeight: hidden ? 0 : button.implicitHeight

  onOpenedChanged: if (opened) {
    now = Date.now() / 1000
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    // text() is stale inside fileChanged; reload and parse in onLoaded.
    onFileChanged: reload()
    onLoaded: root.state = Model.parseState(text())
    onLoadFailed: root.state = null
  }

  // The daemon rewrites the file at least once a minute; if it stops, the
  // watcher can miss the file reappearing, so retry while there is no state.
  Timer {
    interval: 5000
    repeat: true
    running: root.state === null
    onTriggered: stateFile.reload()
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.opened
    onTriggered: root.now = Date.now() / 1000
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string { return root.tooltip }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    tooltipText: root.tooltip
    dimmed: !root.linked
    active: root.low
    onPressed: function(code) {
      if (code === Qt.MiddleButton) root.useAsOutput()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "o" || t === "O") root.useAsOutput()
        else if (t === "r" || t === "R") stateFile.reload()
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "JBL Quantum 360"
            meta: Model.statusLine(root.state)
            detail: root.linked && root.battery >= 0 ? root.battery + "%" : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.linked ? 1.0 : 0.5
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: Model.barGlyph(root.state)
                color: root.low ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          // Not running / not plugged: say how to fix it and stop there.
          Text {
            visible: root.state === null
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "Start the daemon:  systemctl --user enable --now jbl-quantum"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          // --- battery -------------------------------------------------------
          Column {
            visible: root.state !== null
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              height: Style.space(8)
              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              }
              Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * Math.max(0, root.battery) / 100
                color: root.low ? root.urgent : (root.linked ? Color.accent : root.dim)
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
              }
            }

            InfoPair {
              label: root.linked ? Model.remainingText(root.state) : "Last known"
              value: root.battery >= 0 ? root.battery + "%" : "—"
            }

            BatteryChart {
              width: parent.width
              height: Style.space(56)
              points: root.stats.spark || []
              now: root.now
              lineColor: Color.accent
              lowColor: root.urgent
              lowLevel: root.lowLevel
            }

            Row {
              width: parent.width
              Caption { text: "24h ago"; width: parent.width / 2 }
              Caption { text: "now"; width: parent.width / 2; horizontalAlignment: Text.AlignRight }
            }
          }

          PanelSeparator { visible: root.state !== null; foreground: root.foreground }

          // --- health --------------------------------------------------------
          Column {
            visible: root.state !== null
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader { text: "BATTERY HEALTH"; foreground: root.foreground; fontFamily: root.fontFamily }
            InfoPair { label: "Health"; value: Model.healthText(root.stats) }
            Caption { text: Model.healthNote(root.stats); width: parent.width; wrapMode: Text.WordWrap }
            InfoPair { label: "Drain rate"; value: root.stats.ratePerHour ? root.stats.ratePerHour + "%/h" : "—" }
            InfoPair { label: "Trend"; value: Model.baselineText(root.stats) }
            InfoPair { label: "Full cycles"; value: root.stats.cycles !== undefined ? String(root.stats.cycles) : "—" }
            InfoPair { label: "Charged while off"; value: String(root.stats.charges || 0) + "×" }
          }

          PanelSeparator { visible: root.state !== null; foreground: root.foreground }

          // --- usage ---------------------------------------------------------
          Column {
            visible: root.state !== null
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader { text: "USAGE"; foreground: root.foreground; fontFamily: root.fontFamily }
            InfoPair {
              visible: root.linked && !!root.state.sessionStart
              label: "This session"
              value: root.state && root.state.sessionStart ? Model.duration((root.now - root.state.sessionStart) / 60) : ""
            }
            InfoPair { label: "Today"; value: Model.duration(root.stats.todayMin) }
            InfoPair { label: "Last 7 days"; value: Model.duration(root.stats.weekMin) }
            InfoPair {
              label: "Tracked"
              value: (root.stats.totalHours || 0) + " h" + (root.stats.since ? " since " + root.stats.since : "")
            }

            // 7-day bars, tallest day fills the height.
            Row {
              id: bars
              width: parent.width
              height: Style.space(48)
              spacing: Style.space(6)
              topPadding: Style.space(6)
              readonly property var days: root.stats.days || []
              readonly property real peak: {
                var p = 1
                for (var i = 0; i < days.length; i++) p = Math.max(p, days[i].minutes)
                return p
              }
              Repeater {
                model: bars.days
                Column {
                  required property var modelData
                  required property int index
                  width: (bars.width - bars.spacing * 6) / 7
                  spacing: Style.space(2)
                  Item {
                    width: parent.width
                    height: bars.height - Style.space(20)
                    Rectangle {
                      anchors.bottom: parent.bottom
                      width: parent.width
                      height: Math.max(1, parent.height * modelData.minutes / bars.peak)
                      radius: Style.space(2)
                      color: index === bars.days.length - 1 ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)
                    }
                  }
                  Caption { text: Model.weekday(modelData.start); width: parent.width; horizontalAlignment: Text.AlignHCenter }
                }
              }
            }
          }

          PanelSeparator { visible: root.state !== null && root.state.dongle === true; foreground: root.foreground }

          // --- device --------------------------------------------------------
          Column {
            visible: root.state !== null && root.state.dongle === true
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader { text: "DEVICE"; foreground: root.foreground; fontFamily: root.fontFamily }
            InfoPair { visible: root.linked; label: "Boom mic"; value: root.state && root.state.mic ? "Attached" : "Detached" }
            InfoPair { visible: root.linked && root.state.volume !== null; label: "Dial level"; value: root.state ? root.state.volume + " / 16" : "" }
            InfoPair { label: "Dongle"; value: root.state && root.state.serial ? root.state.serial : "—" }

            CursorSurface {
              id: outputRow
              width: parent.width
              implicitHeight: outputLabel.implicitHeight + Style.spacing.rowPaddingX
              hasCursor: outputMouse.containsMouse
              foreground: root.foreground
              visible: root.state !== null && root.state.defaultSink !== true

              MouseArea {
                id: outputMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.useAsOutput()
              }
              Text {
                id: outputLabel
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                textFormat: Text.PlainText
                text: "󰓃  Use as audio output   (o)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }
        }
      }
    }
  }

  component InfoPair: Item {
    property string label: ""
    property string value: ""
    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)
    Text {
      id: labelText
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: parent.label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      id: valueText
      anchors.right: parent.right
      anchors.left: labelText.right
      anchors.leftMargin: Style.space(8)
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: parent.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideLeft
    }
  }

  component Caption: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
