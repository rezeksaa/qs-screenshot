import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property bool   selecting:    true
    property bool   confirmed:    false
    property real   selX:          0
    property real   selY:          0
    property real   selW:          0
    property real   selH:          0
    property int    shotCount:     0
    property string tmpPath:      "/tmp/qs_screenshot_preview_0.png"
    property bool   previewReady: false
    property string statusMsg:    ""
    property bool   statusOk:      true

    property string grimGeo:
        Math.round(selX) + "," + Math.round(selY) +
        " " + Math.round(selW) + "x" + Math.round(selH)

    PanelWindow {
        id: overlayWindow
        screen:  Quickshell.screens[0]
        visible: root.selecting
        color:   "transparent"
        WlrLayershell.layer:          WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusiveZone: -1
        anchors { top: true; bottom: true; left: true; right: true }

        Canvas {
            id: dimCanvas
            anchors.fill: parent
            property real rx: 0; property real ry: 0
            property real rw: 0; property real rh: 0
            property bool hasSel: false
            onPaint: {
                var c = getContext("2d")
                c.clearRect(0, 0, width, height)
                c.fillStyle = "rgba(0,0,0,0.55)"
                c.fillRect(0, 0, width, height)
                if (hasSel && rw > 0 && rh > 0) {
                    c.clearRect(rx, ry, rw, rh)
                    c.strokeStyle = "#a0a09a"
                    c.lineWidth   = 1.5
                    c.strokeRect(rx + 0.75, ry + 0.75, rw - 1.5, rh - 1.5)
                }
            }
        }

        Text {
            visible: selMouse.pressed
            color: "#d4d4ce"
            font { family: "monospace"; pixelSize: 13; weight: Font.Medium }
            style: Text.Outline; styleColor: "#000"
            x: Math.min(selMouse.pressX, selMouse.mouseX) + 8
            y: Math.min(selMouse.pressY, selMouse.mouseY) - 24
            text: Math.abs(Math.round(selMouse.mouseX - selMouse.pressX)) +
                  " x " +
                  Math.abs(Math.round(selMouse.mouseY - selMouse.pressY))
        }

        Text {
            anchors.centerIn: parent
            visible: !selMouse.pressed
            color: "#cceeeeea"
            font { family: "monospace"; pixelSize: 18 }
            text: "Drag to select   ·   Esc to cancel"
            style: Text.Outline; styleColor: "#000"
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Qt.quit()

            MouseArea {
                id: selMouse
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                property real pressX: 0; property real pressY: 0

                onPressed: (m) => {
                    pressX = m.x; pressY = m.y
                    dimCanvas.hasSel = true
                }
                onPositionChanged: (m) => {
                    dimCanvas.rx = Math.min(pressX, m.x)
                    dimCanvas.ry = Math.min(pressY, m.y)
                    dimCanvas.rw = Math.abs(m.x - pressX)
                    dimCanvas.rh = Math.abs(m.y - pressY)
                    dimCanvas.requestPaint()
                }
                onReleased: (m) => {
                    var x1 = Math.min(pressX, m.x), y1 = Math.min(pressY, m.y)
                    var x2 = Math.max(pressX, m.x), y2 = Math.max(pressY, m.y)
                    if (x2 - x1 < 4 || y2 - y1 < 4) {
                        dimCanvas.hasSel = false; dimCanvas.requestPaint(); return
                    }
                    root.selX = x1; root.selY = y1
                    root.selW = x2 - x1; root.selH = y2 - y1
                    root.selecting = false
                    root.shotCount += 1
                    root.tmpPath = "/tmp/qs_screenshot_preview_" + root.shotCount + ".png"
                    grimDelay.start()
                }
            }
        }

        Timer {
            id: grimDelay
            interval: 400
            repeat: false
            onTriggered: grimRegion.running = true
        }

        Process {
            id: grimRegion
            command: ["grim", "-g", root.grimGeo, root.tmpPath]
            running: false
            onExited: (code) => {
                if (code === 0) {
                    root.confirmed = true
                    previewDelay.start()
                } else {
                    root.confirmed    = true
                    root.previewReady = false
                }
            }
        }

        Timer {
            id: previewDelay
            interval: 50
            repeat: false
            onTriggered: root.previewReady = true
        }
    }

    FloatingWindow {
        id: pillWindow
        visible: root.confirmed
        color:   "transparent"
        width:   420
        height:  360
        title:   "Screenshot"

        Item {
            id: pill
            anchors.fill: parent
            focus: true

            opacity: 0; scale: 0.88
            Component.onCompleted: { opacity = 1; scale = 1 }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                x: 4; y: 14; width: parent.width; height: parent.height
                radius: 18; color: "#88000000"
            }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color:  "#f021211c"
                border.color: "#50807d74"; border.width: 1
            }

            Item {
                id: titleBar
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 38

                Row {
                    anchors.centerIn: parent; spacing: 5
                    Repeater {
                        model: 3
                        Rectangle { width: 5; height: 5; radius: 3; color: "#55807d74" }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: root.grimGeo
                    color: "#66a09d94"; font { pixelSize: 10; family: "monospace" }
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 22; height: 22; radius: 11
                    color: closeMa.containsMouse ? "#cca09d94" : "#4a807d74"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "×"; color: "#fff"
                        font { pixelSize: 13; weight: Font.Bold } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                }
            }

            readonly property real thumbW: width  - 40
            readonly property real thumbH: height - titleBar.height - 8 - 72

            Rectangle {
                id: thumbArea
                anchors { top: titleBar.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                width: pill.thumbW; height: pill.thumbH
                radius: 8; color: "#22ffffff"; clip: true

                Image {
                    id: preview
                    anchors.fill: parent
                    fillMode:     Image.PreserveAspectFit
                    smooth:        true
                    cache:         false
                    asynchronous: true
                    source:        ""

                    Connections {
                        target: root
                        function onPreviewReadyChanged() {
                            if (root.previewReady) {
                                preview.source = ""
                                preview.source = "file://" + root.tmpPath
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    visible: preview.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!root.previewReady)               return "Waiting for grim..."
                            if (preview.status === Image.Loading) return "Loading..."
                            if (preview.status === Image.Error)   return "Could not load image"
                            return ""
                        }
                        color: "#88a09d94"; font { family: "monospace"; pixelSize: 13 }
                    }
                }
            }

            Rectangle {
                anchors { bottom: btnRow.top; bottomMargin: 6; horizontalCenter: parent.horizontalCenter }
                visible: root.statusMsg !== ""
                height: 26; width: toastLabel.implicitWidth + 24; radius: 6
                color: root.statusOk ? "#cc2e2e29" : "#cc3a2e2e"
                border.color: root.statusOk ? "#66807d74" : "#66a05050"; border.width: 1
                Text {
                    id: toastLabel; anchors.centerIn: parent
                    text: root.statusMsg
                    color: root.statusOk ? "#cceeeeea" : "#ffddaa99"
                    font { pixelSize: 11; family: "monospace" }
                }
            }

            Row {
                id: btnRow
                anchors { bottom: parent.bottom; bottomMargin: 16; horizontalCenter: parent.horizontalCenter }
                spacing: 10

                SsButton { label: "Copy";    accentCol: "#6b6b65"
                    onClicked: { copyProc.startDetached()
                        root.statusOk = true; root.statusMsg = "Copied to clipboard!"; clearTimer.restart() } }
                SsButton { label: "Save";    accentCol: "#5a5a52"
                    onClicked: { saveProc.startDetached()
                        root.statusOk = true; root.statusMsg = "Saved to ~/Pictures/Screenshots/"; clearTimer.restart() } }
                SsButton { label: "Discard"; accentCol: "#7a3030"
                    onClicked: Qt.quit() }
            }

            Keys.onEscapePressed: Qt.quit()
        }

        Timer { id: clearTimer; interval: 3500; onTriggered: root.statusMsg = "" }
        Process { id: copyProc; command: ["sh", "-c", "wl-copy < \"" + root.tmpPath + "\""] }
        Process { id: saveProc; command: ["sh", "-c",
            "mkdir -p \"$HOME/Pictures/Screenshots\" && cp \"" + root.tmpPath + "\" " +
            "\"$HOME/Pictures/Screenshots/$(date +%s).png\""] }
    }

    component SsButton: Rectangle {
        id: btn
        property string label:     "Action"
        property color  accentCol: "#6b6b65"
        signal clicked
        width: 108; height: 36; radius: 9
        color: bma.containsPress ? Qt.darker(accentCol, 1.55)
             : bma.containsMouse ? Qt.darker(accentCol, 1.25)
             : Qt.rgba(accentCol.r * 0.14, accentCol.g * 0.14, accentCol.b * 0.14, 1.0)
        border.color: Qt.rgba(accentCol.r, accentCol.g, accentCol.b, 0.45); border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
        Text { anchors.centerIn: parent; text: btn.label; color: "#e8e8e2"
            font { pixelSize: 13; weight: Font.Medium; family: "monospace" } }
        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }
}