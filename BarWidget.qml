import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "herdr-overview"

  readonly property var popup: panelLoader.item
  readonly property bool opened: popup ? popup.opened === true : false
  readonly property string globalState: popup ? popup.globalState : "loading"
  readonly property int attentionCount: popup ? popup.attentionCount : 0
  readonly property int activeCount: popup ? popup.workingCount : 0
  readonly property string iconState: popup ? popup.iconState : "idle"
  readonly property color iconTint: globalState === "attention" ? Color.urgent
    : globalState === "working" ? Color.accent : Color.muted

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectPanel() {
    if (!popup) return
    popup.bar = root.bar
    popup.anchorItem = button
    popup.hostWidget = root
  }

  function open() { if (popup) popup.open() }
  function close() { if (popup) popup.close() }
  function toggle() { if (popup) popup.toggle() }
  function refresh() { if (popup) popup.refreshNow() }
  function closeForPopoutSwitch() { if (popup) popup.closeForPopoutSwitch() }

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  onBarChanged: injectPanel()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.iconState === "error" && root.attentionCount === 0
      ? "Herdr: one or more machines did not respond"
      : root.globalState === "attention"
      ? "Herdr: " + root.attentionCount + " need" + (root.attentionCount === 1 ? "s" : "") + " attention"
      : root.globalState === "working"
        ? "Herdr: " + root.activeCount + " agent" + (root.activeCount === 1 ? " running" : "s running")
        : "Herdr: no activity needing attention"
    iconComponent: Component {
      Item {
        implicitWidth: Style.space(21)
        implicitHeight: Style.space(21)

        HerdrMark {
          anchors.centerIn: parent
          width: Style.space(18)
          height: width
          tint: root.iconTint
          state: root.iconState
        }

        Rectangle {
          visible: root.attentionCount > 0
          anchors.right: parent.right
          anchors.top: parent.top
          width: Math.max(Style.space(10), badge.implicitWidth + Style.space(4))
          height: Style.space(10)
          radius: height / 2
          color: Color.urgent

          Text {
            id: badge
            anchors.centerIn: parent
            text: root.attentionCount > 9 ? "9+" : String(root.attentionCount)
            color: Color.background
            font.family: Style.font.family
            font.pixelSize: Math.max(7, Style.space(7))
            font.bold: true
          }
        }
      }
    }
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }
}
