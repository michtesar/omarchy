import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property string state: "idle"

  active: state === "speaking"
  activeText: "󰕾"
  inactiveText: "󰔊"
  activeTooltipText: "Speaking · click to stop"
  inactiveTooltipText: "Text to speech"

  function update(raw) {
    var data = extractData(raw)
    state = String(data.alt || data.class || "idle")
  }

  Process {
    command: ["bash", "-c", "omarchy-utter-status"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.update(data) }
    }
  }

  onPressed: function() {
    if (!root.bar) return
    root.bar.run(root.active ? "omarchy-utter-stop" : "omarchy-utter-doctor")
  }
}
