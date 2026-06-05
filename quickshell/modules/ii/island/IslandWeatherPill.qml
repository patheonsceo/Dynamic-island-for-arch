pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

// Weather pill — Material weather icon + temperature (°C; metric per config).
// Uses the framework Weather service (wttr.in, IP-geolocated, auto-refreshing)
// and Icons.getWeatherIcon, so the glyph always renders (the wttr.in emoji was
// showing as tofu — no matching font). Degrades to a cloud + "--°" until loaded.
Rectangle {
    id: root
    radius: IslandStyle.radius
    color: IslandStyle.pillColor
    border.width: IslandStyle.borderWidth
    border.color: IslandStyle.pillBorder
    implicitWidth: row.implicitWidth + IslandStyle.hPadding * 2
    implicitHeight: IslandStyle.pillHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
            iconSize: 18
            fill: 1
            color: IslandStyle.textColor
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: (Weather.data.temp && Weather.data.temp !== "") ? Weather.data.temp : "--°"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: IslandStyle.textColor
        }
    }
}
