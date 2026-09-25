import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "herdr-overview"
  ipcTarget: "herdr-overview"
  manageIpc: false

  property Item anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property string helperPath: (Quickshell.env("HOME") || "")
    + "/.config/omarchy/plugins/herdr-overview/bin/herdr-overview"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Util.alpha(foreground, 0.63)
  readonly property color subtle: Util.alpha(foreground, 0.09)

  property var snapshot: ({})
  property bool loading: true
  property string loadError: ""
  property string processOutput: ""

  readonly property var totals: snapshot && snapshot.totals ? snapshot.totals : ({})
  readonly property var machines: snapshot && snapshot.machines ? snapshot.machines : []
  readonly property int workingCount: Number(totals.working || 0)
  readonly property int reviewCount: Number(totals.review || 0)
  readonly property int waitingCount: Number(totals.waiting || 0)
  readonly property int idleCount: Number(totals.idle || 0)
  readonly property int otherCount: Number(totals.other || 0)
  readonly property int allCount: Number(totals.all || 0)
  readonly property int attentionCount: reviewCount + waitingCount
  readonly property bool available: snapshot && snapshot.available === true
  readonly property bool partial: snapshot && snapshot.partial === true
  readonly property string iconState: loadError !== "" ? "error"
    : waitingCount > 0 ? "waiting"
    : reviewCount > 0 ? "review"
    : partial ? "error"
    : workingCount > 0 ? "working" : "idle"
  readonly property string globalState: iconState === "error" || iconState === "waiting" || iconState === "review" ? "attention"
    : iconState === "working" ? "working" : "idle"
  readonly property color stateTint: globalState === "attention" ? Color.urgent
    : globalState === "working" ? Color.accent : Color.muted
  readonly property string statusTitle: loadError !== "" ? "Herdr status is unavailable"
    : !available || allCount === 0 ? "No Herdr agents yet"
    : waitingCount > 0 ? waitingCount + " need" + (waitingCount === 1 ? "s" : "") + " input"
    : reviewCount > 0 ? reviewCount + " output" + (reviewCount === 1 ? " needs" : "s need") + " review"
    : partial ? "Some machines did not respond"
    : workingCount > 0 ? workingCount + " agent" + (workingCount === 1 ? " running" : "s running")
    : "Everything is quiet"
  readonly property string statusDetail: loadError !== "" ? "Refresh to retry the local status check."
    : !available ? "Agents appear here when Herdr publishes activity."
    : waitingCount > 0 ? "A decision or response is needed to continue."
    : reviewCount > 0 ? "Inspect the completed output before moving on."
    : partial ? "Counts include machines that responded."
    : workingCount > 0 ? "Status refreshes automatically while work continues."
    : "There is no output or input waiting."

  function agentState(agent) {
    var value = String(agent && (agent.state || agent.status) || "").toLowerCase()
    if (value === "working") return "working"
    if (value === "done" || value === "review") return "review"
    if (value === "blocked" || value === "waiting" || value === "attention") return "waiting"
    if (value === "idle") return "idle"
    return "other"
  }
  function stateLabel(state) {
    if (state === "working") return "RUNNING"
    if (state === "review") return "REVIEW OUTPUT"
    if (state === "waiting") return "NEEDS INPUT"
    if (state === "idle") return "IDLE"
    return "OTHER"
  }
  function agentTint(state) {
    return state === "working" ? Color.accent
      : state === "review" || state === "waiting" ? Color.urgent : Color.muted
  }
  function machineSpaces(machine) { return machine && machine.spaces ? machine.spaces : [] }
  function spaceWorktrees(space) { return space && space.worktrees ? space.worktrees : [] }
  function spaceChildNoun(space) {
    var rows = spaceWorktrees(space)
    if (rows.length === 0) return "worktree"
    for (var i = 0; i < rows.length; i++) {
      if (String(rows[i].kind || "") !== "workspace") return "worktree"
    }
    return "workspace"
  }
  function worktreeAgents(worktree) { return worktree && worktree.agents ? worktree.agents : [] }
  function countLabel(value, noun) { return value + " " + noun + (value === 1 ? "" : "s") }
  function machineAvailabilityLabel(machine) {
    var error = String(machine && machine.error || "").toLowerCase()
    return error.indexOf("timed out") >= 0 ? "TIMED OUT" : "UNAVAILABLE"
  }
  function machineIconState(machine) {
    if (!machine || machine.available === false || !!machine.error) return "error"
    var t = machine.totals || ({})
    if (Number(t.waiting || 0) > 0) return "waiting"
    if (Number(t.review || 0) > 0) return "review"
    if (Number(t.working || 0) > 0) return "working"
    return "idle"
  }

  function refreshNow() {
    if (statusProcess.running) return
    processOutput = ""
    loadError = ""
    statusProcess.running = true
  }
  function applySnapshot(output) {
    var parsed
    try { parsed = JSON.parse(String(output || "")) }
    catch (error) { loadError = "Herdr returned invalid status data."; return }
    if (!parsed || typeof parsed !== "object") { loadError = "Herdr returned no usable status data."; return }
    snapshot = parsed
    if (parsed.error) loadError = String(parsed.error)
  }
  function open() {
    root.controller.show()
    root.refreshNow()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  Component.onCompleted: refreshNow()
  Connections {
    target: hostWidget
    function onBarChanged() { root.bar = hostWidget ? hostWidget.bar : null }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440), Style.space(500))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(590))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(key) { if (key === "r" || key === "R") root.refreshNow() }

      Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: flick.width
          spacing: Style.space(17)

          Row {
            width: parent.width
            spacing: Style.space(13)
            Item {
              width: Style.space(40); height: width
              Rectangle { anchors.centerIn: parent; width: Style.space(34); height: width; radius: width / 2; color: Util.alpha(root.stateTint, 0.12) }
              HerdrMark { anchors.centerIn: parent; width: Style.space(24); height: width; tint: root.stateTint; state: root.iconState }
              Rectangle {
                width: Style.space(7); height: width; radius: width / 2
                color: root.stateTint; anchors.right: parent.right; anchors.bottom: parent.bottom
                SequentialAnimation on opacity {
                  running: root.iconState === "working" && root.opened
                  loops: Animation.Infinite
                  NumberAnimation { to: 0.35; duration: 700 }
                  NumberAnimation { to: 1; duration: 700 }
                }
              }
            }
            Column {
              width: parent.width - Style.space(53)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)
              Text { width: parent.width; text: root.statusTitle; textFormat: Text.PlainText; color: root.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.title; font.bold: true; elide: Text.ElideRight }
              Text { width: parent.width; text: root.statusDetail; textFormat: Text.PlainText; color: root.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            Repeater {
              model: [
                { label: "RUNNING", value: root.workingCount, tint: Color.accent, state: "working" },
                { label: "REVIEW", value: root.reviewCount, tint: Color.urgent, state: "review" },
                { label: "WAITING", value: root.waitingCount, tint: Color.urgent, state: "waiting" }
              ]
              delegate: Row {
                required property var modelData
                width: (parent.width - Style.space(16)) / 3
                spacing: Style.space(6)
                HerdrMark { width: Style.space(14); height: width; tint: modelData.tint; state: modelData.state; anchors.verticalCenter: parent.verticalCenter }
                Column {
                  width: parent.width - Style.space(20)
                  spacing: 0
                  Text { text: modelData.value; color: modelData.tint; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                  Text { width: parent.width; text: modelData.label; color: root.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.5; elide: Text.ElideRight }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground; strength: 0.10 }

          Item {
            visible: root.loading && root.machines.length === 0
            width: parent.width; height: Style.space(76)
            Column {
              anchors.centerIn: parent; spacing: Style.space(6)
              Text { text: "Reading local activity…"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
              Text { text: "Your machine overview will appear in a moment."; color: root.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
            }
          }
          Item {
            visible: root.loadError !== ""
            width: parent.width; height: errorCopy.implicitHeight + Style.space(22)
            Rectangle { anchors.fill: parent; radius: Style.cornerRadius; color: Util.alpha(Color.urgent, 0.10) }
            Row {
              anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(13); anchors.rightMargin: Style.space(13); spacing: Style.space(8)
              HerdrMark { width: Style.space(15); height: width; tint: Color.urgent; state: "error"; anchors.verticalCenter: parent.verticalCenter }
              Text { id: errorCopy; width: parent.width - Style.space(23); text: root.loadError; textFormat: Text.PlainText; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
            }
          }
          Item {
            visible: !root.loading && root.loadError === "" && (!root.available || root.machines.length === 0)
            width: parent.width; height: emptyCopy.implicitHeight + Style.space(28)
            Column {
              anchors.centerIn: parent; width: parent.width - Style.space(32); spacing: Style.space(7)
              HerdrMark { anchors.horizontalCenter: parent.horizontalCenter; width: Style.space(22); height: width; tint: root.muted; state: "idle" }
              Text { id: emptyCopy; width: parent.width; text: "No Herdr activity yet. Once an agent starts, this panel groups worktrees inside each Space."; textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: root.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
            }
          }

          Column {
            visible: root.machines.length > 0
            width: parent.width
            spacing: Style.space(13)
            PanelSectionHeader { text: "MACHINES"; foreground: root.foreground }
            Repeater {
              model: root.machines
              delegate: Column {
                required property int index
                required property var modelData
                readonly property string machineState: root.machineIconState(modelData)
                readonly property bool machineUnavailable: modelData.available === false || !!modelData.error
                width: parent.width
                spacing: Style.space(8)

                Row {
                  width: parent.width; spacing: Style.space(8)
                  HerdrMark { width: Style.space(16); height: width; tint: root.agentTint(machineState); state: machineState; anchors.verticalCenter: parent.verticalCenter }
                  Text { width: Math.max(0, parent.width - machineMeta.implicitWidth - Style.space(32)); text: String(modelData.name || modelData.id || "Machine"); textFormat: Text.PlainText; color: root.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight }
                  Text {
                    id: machineMeta
                    text: machineUnavailable ? root.machineAvailabilityLabel(modelData) : root.countLabel(Number((modelData.totals || {}).all || 0), "agent")
                    color: root.agentTint(machineState)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.45
                  }
                }

                Text {
                  visible: machineUnavailable
                  width: parent.width - Style.space(24); anchors.left: parent.left; anchors.leftMargin: Style.space(24)
                  text: String(modelData.error || "This machine is unavailable.")
                  textFormat: Text.PlainText; color: root.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight
                }

                Column {
                  visible: root.machineSpaces(modelData).length > 0
                  width: parent.width - Style.space(24); anchors.left: parent.left; anchors.leftMargin: Style.space(24)
                  spacing: Style.space(9)
                  Repeater {
                    model: root.machineSpaces(modelData)
                    delegate: Column {
                      required property int index
                      required property var modelData
                      width: parent.width; spacing: Style.space(6)
                      Row {
                        width: parent.width; spacing: Style.space(7)
                        Rectangle { width: Style.space(5); height: width; radius: width / 2; color: root.agentTint(root.machineIconState({ totals: modelData.totals, available: true })); anchors.verticalCenter: parent.verticalCenter }
                        Text { width: Math.max(0, parent.width - spaceMeta.implicitWidth - Style.space(19)); text: String(modelData.name || "Space"); textFormat: Text.PlainText; color: root.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                        Text { id: spaceMeta; text: root.countLabel(root.spaceWorktrees(modelData).length, root.spaceChildNoun(modelData)); color: root.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                      Repeater {
                        model: root.spaceWorktrees(modelData)
                        delegate: Column {
                          required property var modelData
                          width: parent.width - Style.space(12); anchors.left: parent.left; anchors.leftMargin: Style.space(12); spacing: Style.space(5)
                          Row {
                            width: parent.width; spacing: Style.space(7)
                            Text { width: Math.max(0, parent.width - worktreeMeta.implicitWidth - Style.space(7)); text: String(modelData.name || modelData.path || "Worktree"); textFormat: Text.PlainText; color: root.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideMiddle }
                            Text { id: worktreeMeta; text: root.countLabel(root.worktreeAgents(modelData).length, "agent"); color: root.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                          }
                          Repeater {
                            model: root.worktreeAgents(modelData)
                            delegate: Rectangle {
                              required property var modelData
                              readonly property string agentState: root.agentState(modelData)
                              width: parent.width; height: agentCopy.implicitHeight + Style.space(16); radius: Style.cornerRadius; color: root.subtle
                              Row {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Style.space(10); anchors.rightMargin: Style.space(10); spacing: Style.space(8)
                                HerdrMark { width: Style.space(14); height: width; tint: root.agentTint(agentState); state: agentState; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                  id: agentCopy; width: parent.width - Style.space(22); spacing: Style.space(2)
                                  Row {
                                    width: parent.width
                                    Text { width: Math.max(0, parent.width - stateText.implicitWidth - Style.space(7)); text: String(modelData.name || "Agent"); textFormat: Text.PlainText; color: root.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                    Text { id: stateText; text: root.stateLabel(agentState); color: root.agentTint(agentState); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.4 }
                                  }
                                  Text { width: parent.width; text: String(modelData.summary || "No summary available"); textFormat: Text.PlainText; color: root.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
                PanelSeparator { visible: index < root.machines.length - 1; foreground: root.foreground; strength: 0.07 }
              }
            }
          }

          Text {
            visible: root.available
            width: parent.width
            text: root.allCount + " agents · " + (root.partial ? "partial snapshot" : "global snapshot")
              + (root.idleCount > 0 ? " · " + root.idleCount + " idle" : "")
              + (root.otherCount > 0 ? " · " + root.otherCount + " other" : "")
            textFormat: Text.PlainText; color: root.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  Timer {
    interval: root.opened ? 5000 : 12000
    running: true
    repeat: true
    onTriggered: root.refreshNow()
  }
  Process {
    id: statusProcess
    command: ["python3", root.helperPath]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.processOutput = String(text || "") }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) root.loadError = "Could not run the Herdr overview."
      else root.applySnapshot(root.processOutput)
    }
  }
}
