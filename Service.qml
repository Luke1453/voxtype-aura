import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  // Palette for niri + noctalia ("Occult Umbral", dark).
  // Same values as ~/.config/omarchy/current/theme/colors.toml.
  readonly property color accent: "#BB3535"
  readonly property color urgent: "#C25B5B"
  readonly property color background: "#0A0A12"
  readonly property int cornerRadius: 9
  readonly property int gapsOut: 8

  function alpha(color, value) {
    return Qt.rgba(color.r, color.g, color.b, value)
  }

  property string state: "idle"
  property int animationFrame: 0
  property var audioSamples: []
  property int maxDurationSecs: 0
  property real recordingStartedAt: 0
  property real recordingElapsedSecs: 0

  readonly property real recordingProgress: maxDurationSecs > 0
    ? Math.max(0, 1 - recordingElapsedSecs / maxDurationSecs) : 0
  readonly property bool active: state === "recording" || state === "transcribing" || state === "success"
  readonly property color successColor: Qt.hsla(0.33, Math.max(0.35, accent.hslSaturation), accent.hslLightness, 1)
  readonly property color stateColor: state === "recording" ? urgent
    : state === "success" ? successColor : accent
  property string focusedScreenName: ""
  readonly property var activeScreen: {
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (Quickshell.screens[i].name === focusedScreenName) return Quickshell.screens[i]
    }
    return Quickshell.screens.length ? Quickshell.screens[0] : null
  }

  function update(raw) {
    if (!niriFocus.running) niriFocus.running = true
    try {
      var data = JSON.parse(String(raw || "{}"))
      var nextState = String(data.alt || data.class || "idle")
      if (nextState === "recording" || nextState === "transcribing") {
        if (nextState === "recording" && state !== "recording") {
          audioSamples = []
          recordingStartedAt = Date.now()
          recordingElapsedSecs = 0
          durationProcess.running = true
        }
        if (nextState === "transcribing" && state !== "transcribing") animationFrame = 0
        state = nextState
      } else if (state === "transcribing") {
        state = "success"
      } else if (state !== "success") {
        state = "idle"
      }
    } catch (error) {
      state = "idle"
    }
  }

  function updateAudio(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (state !== "recording" || typeof data.peak !== "number") return

      var next = audioSamples.slice()
      next.push(Math.max(0, Math.min(1, data.peak)))
      while (next.length > 40) next.shift()
      audioSamples = next
    } catch (error) {
    }
  }

  function barHeight(index) {
    if (state === "success") return 3.5

    if (state === "recording" && audioSamples.length) {
      var sampleIndex = Math.min(audioSamples.length - 1,
        Math.floor(index * (audioSamples.length - 1) / 15))
      return 3.5 + Math.min(1, audioSamples[sampleIndex] * 20) * 14
    }

    var distance = Math.abs(index - (animationFrame % 15))
    distance = Math.min(distance, 15 - distance)
    return 3.5 + Math.max(0, 14 - distance * 3.5)
  }

  Process {
    id: durationProcess

    command: ["voxtype", "config", "get", "audio.max_duration_secs"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var duration = Number(text.trim())
        root.maxDurationSecs = isFinite(duration) && duration > 0 ? duration : 0
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.maxDurationSecs = 0
    }
  }

  Process {
    id: statusProcess

    // Run voxtype directly: Omarchy removed its omarchy-voxtype-status wrapper
    // (basecamp/omarchy c248890). pdeathsig keeps the follower tied to the
    // shell so a restart does not orphan it under systemd.
    command: ["setpriv", "--pdeathsig", "TERM", "voxtype", "status", "--follow", "--extended", "--format", "json"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.update(data) }
    }
    onExited: function() {
      root.state = "idle"
      statusRetry.restart()
    }
  }

  Process {
    id: audioBridge

    command: ["voxtype-audio-bridge"]
    running: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.updateAudio(data) }
    }
    onExited: function() {
      audioRetry.restart()
    }
  }

  Timer {
    id: audioRetry

    interval: 1000
    onTriggered: audioBridge.running = true
  }

  Timer {
    id: statusRetry

    interval: 1000
    onTriggered: statusProcess.running = true
  }

  Process {
    id: niriFocus

    command: ["niri", "msg", "--json", "focused-output"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.focusedScreenName = String(JSON.parse(text).name || "")
        } catch (error) {
        }
      }
    }
  }

  Component.onCompleted: niriFocus.running = true

  Timer {
    interval: 50
    repeat: true
    running: root.state === "recording"
    onTriggered: root.recordingElapsedSecs = (Date.now() - root.recordingStartedAt) / 1000
  }

  Timer {
    interval: 80
    repeat: true
    running: root.state === "transcribing"
    onTriggered: root.animationFrame = (root.animationFrame + 1) % 120
  }

  Timer {
    interval: 1300
    running: root.state === "success"
    onTriggered: root.state = "idle"
  }

  PanelWindow {
    id: surface

    screen: root.activeScreen
    visible: root.active && root.activeScreen !== null
    implicitWidth: 225
    implicitHeight: 50
    anchors.bottom: true
    margins.bottom: root.gapsOut
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.namespace: "voxtype-aura"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      id: glowSource

      visible: false
      width: 205
      height: 33
      anchors.centerIn: parent
      radius: Math.min(height / 2, root.cornerRadius)
      color: root.stateColor
    }

    MultiEffect {
      anchors.fill: glowSource
      source: glowSource
      autoPaddingEnabled: true
      blurEnabled: true
      blur: 0.9
      blurMax: 18
      blurMultiplier: 1
      opacity: 0.42
      scale: 1.02
    }

    Rectangle {
      width: 205
      height: 33
      anchors.centerIn: parent
      radius: Math.min(height / 2, root.cornerRadius)
      color: root.alpha(root.background, 0.94)
      border.width: 1
      border.color: root.stateColor

      Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: parent.radius
        anchors.rightMargin: parent.radius
        anchors.bottomMargin: 2
        height: 2
        visible: root.state === "recording" && root.maxDurationSecs > 0

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width * root.recordingProgress
          height: parent.height
          radius: 1
          color: root.stateColor
        }
      }

      Item {
        anchors.fill: parent
        anchors.leftMargin: parent.radius
        anchors.rightMargin: parent.radius

        Row {
          anchors.fill: parent
          spacing: Math.max(2, (width - 16 * 4) / 15)

          Repeater {
            model: 16

            Rectangle {
              required property int index

              width: 4
              height: root.barHeight(index)
              anchors.verticalCenter: parent.verticalCenter
              radius: 2
              color: root.stateColor

              Behavior on height {
                NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
              }
            }
          }
        }
      }
    }
  }
}
