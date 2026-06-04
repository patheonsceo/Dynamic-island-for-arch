pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

// App / settings launcher (USECASE 4): fuzzy search apps AND system settings
// (both are .desktop entries) via AppSearch; scrollable results; keyboard nav.
FocusScope {
    id: surf
    focus: true
    property string query: ""
    property int sel: 0

    readonly property var results: {
        if (surf.query.trim() === "")
            return Array.from(DesktopEntries.applications.values)
                .filter(a => !a.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name));
        return AppSearch.fuzzyQuery(surf.query);
    }
    onResultsChanged: surf.sel = 0

    function launchSel() {
        const r = surf.results;
        if (r.length > 0 && surf.sel >= 0 && surf.sel < r.length) {
            r[surf.sel].execute();
            Island.close();
        }
    }
    function moveSel(d) {
        if (surf.results.length === 0)
            return;
        surf.sel = Math.max(0, Math.min(surf.results.length - 1, surf.sel + d));
        list.positionViewAtIndex(surf.sel, ListView.Contain);
    }

    Component.onCompleted: input.forceActiveFocus()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.06)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                MaterialSymbol { text: "search"; iconSize: 20; color: IslandStyle.subtextColor }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    StyledTextInput {
                        id: input
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        onTextChanged: surf.query = text
                        Keys.onDownPressed: surf.moveSel(1)
                        Keys.onUpPressed: surf.moveSel(-1)
                        Keys.onReturnPressed: surf.launchSel()
                        Keys.onEnterPressed: surf.launchSel()
                        Keys.onEscapePressed: Island.close()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: "Search apps & settings…"
                        color: IslandStyle.subtextColor
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: surf.results
            currentIndex: surf.sel
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: 46
                radius: 10
                color: surf.sel === row.index ? Qt.rgba(0.54, 0.70, 0.97, 0.18)
                     : rowHover.hovered ? Qt.rgba(1, 1, 1, 0.05)
                     : "transparent"
                HoverHandler { id: rowHover }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    IconImage {
                        implicitSize: 30
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2
                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.name ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: IslandStyle.textColor
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            readonly property string sub: row.modelData.comment || row.modelData.genericName || ""
                            visible: sub !== ""
                            text: sub
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: IslandStyle.subtextColor
                            elide: Text.ElideRight
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        surf.sel = row.index;
                        row.modelData.execute();
                        Island.close();
                    }
                }
            }
        }
    }
}
