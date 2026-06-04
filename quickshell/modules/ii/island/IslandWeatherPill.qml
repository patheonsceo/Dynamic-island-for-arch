pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io

// Weather pill — emoji + temperature in °C via wttr.in (IP-geolocated).
// Refresh every 10 min; keep last good value; degrade gracefully offline.
Rectangle {
    id: root
    radius: IslandStyle.radius
    color: IslandStyle.pillColor
    border.width: IslandStyle.borderWidth
    border.color: IslandStyle.pillBorder
    implicitWidth: row.implicitWidth + IslandStyle.hPadding * 2
    implicitHeight: IslandStyle.pillHeight

    property string emoji: "⛅"
    property string temp: "--°"

    Process {
        id: wproc
        command: ["bash", "-c", "curl -s --max-time 10 'wttr.in/?format=%c|%t&m'"]
        stdout: SplitParser {
            onRead: data => {
                const s = data.trim();
                if (s.length === 0 || s.toLowerCase().includes("unknown") || s.toLowerCase().includes("sorry"))
                    return;
                const parts = s.split("|");
                if (parts.length >= 2) {
                    root.emoji = parts[0].trim();
                    root.temp = parts[1].trim();
                } else {
                    root.temp = s;
                }
            }
        }
    }
    Timer {
        interval: 600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: wproc.running = true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.emoji
            font.pixelSize: Appearance.font.pixelSize.normal
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temp
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: IslandStyle.textColor
        }
    }
}
