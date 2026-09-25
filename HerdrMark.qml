import QtQuick

// Font-independent status mark. Each state has a distinct silhouette so the
// overview stays readable at bar size even before color is perceived.
Item {
  id: root

  property color tint: "white"
  property string state: "idle" // working, review, waiting, idle, other, error
  implicitWidth: 20
  implicitHeight: 20

  // Working: three connected agents.
  Item {
    anchors.fill: parent
    visible: root.state === "working"
    Rectangle { x: root.width * 0.26; y: root.height * 0.35; width: root.width * 0.48; height: Math.max(1, root.width * 0.09); radius: height / 2; rotation: -31; transformOrigin: Item.Center; color: root.tint; opacity: 0.78 }
    Rectangle { x: root.width * 0.26; y: root.height * 0.56; width: root.width * 0.48; height: Math.max(1, root.width * 0.09); radius: height / 2; rotation: 31; transformOrigin: Item.Center; color: root.tint; opacity: 0.78 }
    Repeater {
      model: [{ x: 0.12, y: 0.39 }, { x: 0.65, y: 0.13 }, { x: 0.65, y: 0.65 }]
      delegate: Rectangle {
        required property int index
        required property var modelData
        x: root.width * modelData.x; y: root.height * modelData.y
        width: root.width * 0.24; height: width; radius: width / 2
        color: root.tint; opacity: 0.9
      }
    }
  }

  // Review: a document with two output lines.
  Item {
    anchors.fill: parent
    visible: root.state === "review"
    Rectangle { x: root.width * 0.24; y: root.height * 0.14; width: root.width * 0.52; height: root.height * 0.72; radius: root.width * 0.09; color: "transparent"; border.width: Math.max(1, root.width * 0.09); border.color: root.tint }
    Rectangle { x: root.width * 0.36; y: root.height * 0.39; width: root.width * 0.29; height: Math.max(1, root.width * 0.08); radius: height / 2; color: root.tint }
    Rectangle { x: root.width * 0.36; y: root.height * 0.59; width: root.width * 0.20; height: Math.max(1, root.width * 0.08); radius: height / 2; color: root.tint; opacity: 0.78 }
  }

  // Waiting: an hourglass, explicitly blocked on input.
  Item {
    anchors.fill: parent
    visible: root.state === "waiting"
    Rectangle { x: root.width * 0.22; y: root.height * 0.14; width: root.width * 0.56; height: Math.max(1, root.width * 0.10); radius: height / 2; color: root.tint }
    Rectangle { x: root.width * 0.22; y: root.height * 0.76; width: root.width * 0.56; height: Math.max(1, root.width * 0.10); radius: height / 2; color: root.tint }
    Rectangle { x: root.width * 0.28; y: root.height * 0.42; width: root.width * 0.48; height: Math.max(1, root.width * 0.08); radius: height / 2; rotation: 48; transformOrigin: Item.Center; color: root.tint }
    Rectangle { x: root.width * 0.28; y: root.height * 0.50; width: root.width * 0.48; height: Math.max(1, root.width * 0.08); radius: height / 2; rotation: -48; transformOrigin: Item.Center; color: root.tint }
  }

  // Idle: a quiet outlined circle.
  Rectangle {
    visible: root.state === "idle"
    anchors.centerIn: parent
    width: root.width * 0.60; height: width; radius: width / 2
    color: "transparent"; border.width: Math.max(1, root.width * 0.10); border.color: root.tint
  }

  // Other: an unclassified state, deliberately separate from quiet idle.
  Rectangle {
    visible: root.state === "other"
    anchors.centerIn: parent
    width: root.width * 0.62; height: Math.max(1, root.width * 0.10); radius: height / 2
    color: root.tint
  }

  // Error: a compact, unambiguous cross.
  Item {
    anchors.fill: parent
    visible: root.state === "error"
    Rectangle { anchors.centerIn: parent; width: root.width * 0.72; height: Math.max(1, root.width * 0.11); radius: height / 2; rotation: 45; color: root.tint }
    Rectangle { anchors.centerIn: parent; width: root.width * 0.72; height: Math.max(1, root.width * 0.11); radius: height / 2; rotation: -45; color: root.tint }
  }
}
