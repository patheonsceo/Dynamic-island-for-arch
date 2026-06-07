pragma Singleton
import QtQuick
import Quickshell

// Shared "bus" so pills on the side islands (separate PanelWindows) can command
// the centre notch to open a named surface in its `open` state. Mirrors the
// reference's notch.stack + open_notch(name) / close_notch().
//
// openSurface: "" = closed; else one of dashboard | power | tools | launcher | overview
// openScreen:  name of the monitor that owns the open surface ("" while closed).
//   Only ONE monitor shows a surface at a time — opening on another moves it there,
//   so clicking an island opens it on THAT screen, not on all of them.
Singleton {
    id: root

    property string openSurface: ""
    property string openScreen: ""

    function open(name, screen) {
        root.openSurface = name;
        root.openScreen = screen || "";
    }
    function close() {
        root.openSurface = "";
        root.openScreen = "";
    }
    function toggle(name, screen) {
        const s = screen || "";
        if (root.openSurface === name && root.openScreen === s)
            root.close();
        else
            root.open(name, s);
    }
}
