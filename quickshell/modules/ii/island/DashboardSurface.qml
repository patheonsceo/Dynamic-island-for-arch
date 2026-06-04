pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// The click-to-open notch content: a tabbed dashboard shell.
// Tabs: Widgets | Kanban | Coming soon. Switch with mouse or Ctrl+Tab.
// Pane content is filled in by later phases (B = Widgets, C = Kanban).
FocusScope {
    id: surf
    property int currentTab: 0
    readonly property var tabs: ["Widgets", "Kanban", "Coming soon"]

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            Island.close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
            const dir = (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
            surf.currentTab = (surf.currentTab + dir + surf.tabs.length) % surf.tabs.length;
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab && (event.modifiers & Qt.ControlModifier)) {
            surf.currentTab = (surf.currentTab - 1 + surf.tabs.length) % surf.tabs.length;
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ---- tab bar ----
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Repeater {
                model: surf.tabs
                delegate: Rectangle {
                    id: tab
                    required property int index
                    required property string modelData
                    implicitHeight: 28
                    implicitWidth: tabText.implicitWidth + 28
                    radius: height / 2
                    color: surf.currentTab === tab.index ? Qt.rgba(1, 1, 1, 0.14)
                         : tabHover.hovered ? Qt.rgba(1, 1, 1, 0.06)
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    StyledText {
                        id: tabText
                        anchors.centerIn: parent
                        text: tab.modelData
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: surf.currentTab === tab.index ? Font.DemiBold : Font.Normal
                        color: surf.currentTab === tab.index ? IslandStyle.textColor : IslandStyle.subtextColor
                    }
                    HoverHandler { id: tabHover }
                    TapHandler { onTapped: surf.currentTab = tab.index }
                }
            }
        }

        // ---- content panes ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WidgetsPane {
                anchors.fill: parent
                visible: surf.currentTab === 0
            }
            DashboardPlaceholder {
                anchors.fill: parent
                visible: surf.currentTab === 1
                icon: "view_kanban"
                label: "Kanban — coming in Phase C"
            }
            DashboardPlaceholder {
                anchors.fill: parent
                visible: surf.currentTab === 2
                icon: "hourglass_top"
                label: "Coming soon"
            }
        }
    }
}
