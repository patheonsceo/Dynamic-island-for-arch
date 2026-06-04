pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Power surface (USECASE 1): in-notch session actions. Mouse + keyboard
// (←/→ to move, Enter to activate, Esc to close).
//
// SAFETY: Logout/Reboot/Shut down hit the REAL machine even from the nested
// dev window. Wired but DO NOT trigger them while developing.
FocusScope {
    id: surf
    focus: true

    readonly property var actions: [
        { "icon": "lock", "label": "Lock", "destructive": false, "night": false, "cmd": ["loginctl", "lock-session"] },
        { "icon": "nightlight", "label": "Night", "destructive": false, "night": true, "cmd": [] },
        { "icon": "logout", "label": "Log out", "destructive": true, "night": false, "cmd": ["hyprctl", "dispatch", "exit"] },
        { "icon": "restart_alt", "label": "Reboot", "destructive": true, "night": false, "cmd": ["systemctl", "reboot"] },
        { "icon": "power_settings_new", "label": "Shut down", "destructive": true, "night": false, "cmd": ["systemctl", "poweroff"] }
    ]
    property int sel: 0

    function activate(i) {
        const a = surf.actions[i];
        if (a.night) {
            Hyprsunset.toggleTemperature();
            return;
        }
        if (a.cmd && a.cmd.length > 0)
            Quickshell.execDetached(a.cmd);
        Island.close();
    }

    Keys.onLeftPressed: surf.sel = (surf.sel + surf.actions.length - 1) % surf.actions.length
    Keys.onRightPressed: surf.sel = (surf.sel + 1) % surf.actions.length
    Keys.onReturnPressed: surf.activate(surf.sel)
    Keys.onEnterPressed: surf.activate(surf.sel)
    Keys.onEscapePressed: Island.close()

    RowLayout {
        anchors.centerIn: parent
        spacing: 10
        Repeater {
            model: surf.actions
            delegate: Rectangle {
                id: btn
                required property int index
                required property var modelData
                readonly property bool active: surf.sel === btn.index
                implicitWidth: 52
                implicitHeight: 62
                radius: 12
                color: active ? (modelData.destructive ? Qt.rgba(0.9, 0.3, 0.3, 0.22) : Qt.rgba(0.54, 0.70, 0.97, 0.20))
                              : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: active ? (modelData.destructive ? "#E06A6A" : IslandStyle.accent) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: btn.modelData.icon
                        iconSize: 24
                        fill: btn.active ? 1 : 0
                        color: btn.modelData.destructive && btn.active ? "#E06A6A" : IslandStyle.textColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: btn.modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: IslandStyle.subtextColor
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: surf.sel = btn.index
                    onClicked: surf.activate(btn.index)
                }
            }
        }
    }
}
