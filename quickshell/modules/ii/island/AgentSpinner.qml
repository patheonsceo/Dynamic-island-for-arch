pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

// Pixel-art agent mascot + state glyph — frame-animated, state-tinted.
// Reference: Vibe Island compact notch (CLI-spinner style). modes:
//   working | running | waiting | permission | compact | done | idle
// Left: an 8×8 pixel "creature" doing a 2-frame wiggle. Right: a state glyph —
// bouncing bars while working, a pixel "?" while it needs you.
Item {
    id: root
    property string mode: "working"
    property int pixel: 2
    property bool animated: true

    readonly property color tint: {
        switch (root.mode) {
        case "working": return "#7AA2F7";    // blue
        case "running": return "#7EE787";    // green
        case "waiting": return "#E8A23D";     // orange
        case "permission": return "#E8A23D";  // orange — attention
        case "compact": return "#B58AF8";     // purple
        case "done": return "#7EE787";        // green
        default: return "#9AA0AA";            // idle grey
        }
    }
    readonly property bool showBars: root.mode === "working" || root.mode === "compact"
    readonly property bool showQuestion: root.mode === "permission" || root.mode === "waiting"

    // 4-frame running cycle (head/eyes/antennae steady; legs + arms move).
    readonly property var mascotFrames: [
        [0,0,1,0,0,1,0,0,
         0,1,1,1,1,1,1,0,
         1,1,0,1,1,0,1,1,
         1,1,1,1,1,1,1,1,
         1,0,1,1,1,1,0,1,
         0,0,1,1,1,1,0,0,
         0,1,0,0,0,0,1,0,
         1,0,0,0,0,0,0,1],
        [0,0,1,0,0,1,0,0,
         0,1,1,1,1,1,1,0,
         1,1,0,1,1,0,1,1,
         1,1,1,1,1,1,1,1,
         1,0,1,1,1,1,0,1,
         0,0,1,1,1,1,0,0,
         0,0,1,0,0,1,0,0,
         0,1,0,0,0,1,0,0],
        [0,0,1,0,0,1,0,0,
         0,1,1,1,1,1,1,0,
         1,1,0,1,1,0,1,1,
         1,1,1,1,1,1,1,1,
         1,0,1,1,1,1,0,1,
         0,0,1,1,1,1,0,0,
         0,0,0,1,1,0,0,0,
         0,0,1,0,0,1,0,0],
        [0,0,1,0,0,1,0,0,
         0,1,1,1,1,1,1,0,
         1,1,0,1,1,0,1,1,
         1,1,1,1,1,1,1,1,
         1,0,1,1,1,1,0,1,
         0,0,1,1,1,1,0,0,
         0,1,0,0,0,1,0,0,
         0,0,1,0,0,0,1,0]
    ]
    readonly property var qFrame: [
        0,1,1,1,0,
        1,0,0,0,1,
        0,0,0,1,0,
        0,0,1,0,0,
        0,0,1,0,0,
        0,0,0,0,0,
        0,0,0,0,0,
        0,0,1,0,0]

    property int frame: 0
    property int barFrame: 0
    // running cycle (mascot always lively); bars run a touch faster while working
    Timer { interval: 150; running: root.animated; repeat: true; onTriggered: root.frame = (root.frame + 1) % root.mascotFrames.length }
    Timer { interval: 170; running: root.animated && root.showBars; repeat: true; onTriggered: root.barFrame = (root.barFrame + 1) % 4 }

    function barH(i) {
        const tbl = [[0.35, 0.85, 0.30], [0.85, 0.40, 0.70], [0.50, 1.00, 0.40], [1.00, 0.30, 0.80]];
        return tbl[(root.barFrame + i * 2) % tbl.length][i];
    }

    implicitHeight: 8 * root.pixel
    implicitWidth: glyphRow.implicitWidth

    component PixelCanvas: Canvas {
        id: pc
        property var pixels: []
        property int gw: 8
        property int gh: 8
        property int cell: 2
        property color col: "#ffffff"
        implicitWidth: gw * cell
        implicitHeight: gh * cell
        onPixelsChanged: pc.requestPaint()
        onColChanged: pc.requestPaint()
        onPaint: {
            const ctx = pc.getContext("2d");
            ctx.clearRect(0, 0, pc.width, pc.height);
            ctx.fillStyle = pc.col;
            for (let y = 0; y < pc.gh; y++)
                for (let x = 0; x < pc.gw; x++)
                    if (pc.pixels[y * pc.gw + x] === 1)
                        ctx.fillRect(x * pc.cell, y * pc.cell, pc.cell, pc.cell);
        }
    }

    Row {
        id: glyphRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.pixel * 2 + 4

        PixelCanvas {
            anchors.verticalCenter: parent.verticalCenter
            gw: 8
            gh: 8
            cell: root.pixel
            col: root.tint
            pixels: root.mascotFrames[root.frame]
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBars
            spacing: root.pixel
            Repeater {
                model: 3
                delegate: Item {
                    required property int index
                    width: root.pixel
                    height: 8 * root.pixel
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        radius: width / 2
                        color: root.tint
                        height: Math.max(root.pixel, parent.height * root.barH(parent.index))
                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }

        PixelCanvas {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showQuestion
            gw: 5
            gh: 8
            cell: root.pixel
            col: root.tint
            pixels: root.qFrame
            opacity: root.frame === 0 ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }
    }
}
