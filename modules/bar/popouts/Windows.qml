pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

// The readable half of the window strip. The bar can only afford an icon per window, so this is
// where the titles, the workspace each one sits on, and the per-window buttons live.
ColumnLayout {
    id: root

    required property PopoutState popouts

    // A soft cap, and only ever hit by a session that has got away from someone: the popout is
    // laid out as a column with no scroll, so an unbounded list would eventually run off the top
    // and bottom of the screen with no way to reach either end.
    readonly property int maxRows: 15

    readonly property var shown: Hypr.shownToplevels
    readonly property var minimized: Hypr.minimizedToplevels

    width: 320
    spacing: Tokens.spacing.small

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.rightMargin: Tokens.padding.extraSmall
        text: qsTr("Windows")
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    StyledText {
        Layout.rightMargin: Tokens.padding.extraSmall
        text: {
            const open = qsTr("%1 open").arg(root.shown.length);
            return root.minimized.length > 0 ? qsTr("%1, %2 minimized").arg(open).arg(root.minimized.length) : open;
        }
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    Repeater {
        model: ScriptModel {
            values: root.shown.slice(0, root.maxRows)
        }

        WindowRow {}
    }

    Overflow {
        count: root.shown.length - root.maxRows
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.small
        Layout.rightMargin: Tokens.padding.extraSmall
        visible: root.minimized.length > 0
        text: qsTr("Minimized")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    Repeater {
        model: ScriptModel {
            values: root.minimized.slice(0, root.maxRows)
        }

        WindowRow {
            minimized: true
        }
    }

    Overflow {
        count: root.minimized.length - root.maxRows
    }

    component Overflow: StyledText {
        required property int count

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        Layout.bottomMargin: visible ? Tokens.spacing.small : 0

        visible: count > 0
        text: qsTr("and %1 more").arg(count)
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    component WindowRow: StyledRect {
        id: row

        required property var modelData
        property bool minimized

        readonly property var ipc: modelData?.lastIpcObject ?? null
        readonly property string windowClass: ipc?.class ?? ""
        readonly property bool isActive: !minimized && modelData?.address !== undefined && modelData.address === Hypr.activeToplevel?.address

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall

        implicitHeight: rowLayout.implicitHeight + Tokens.padding.small * 2

        radius: Tokens.rounding.small
        // The focused window is marked here as well as on the bar, because the popout is where
        // you end up when the bar's icons were not enough to tell you which is which.
        color: Qt.alpha(Colours.palette.m3secondaryContainer, isActive ? 1 : 0)

        StateLayer {
            radius: parent.radius
            onClicked: Hypr.focusToplevel(row.modelData)
        }

        RowLayout {
            id: rowLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.extraSmall

            spacing: Tokens.spacing.small

            // Same pair as the bar strip: the real app icon where there is one, the category
            // glyph where there is not. See Icons.getWindowIcon for why that happens so often.
            Item {
                Layout.alignment: Qt.AlignVCenter

                implicitWidth: details.implicitHeight
                implicitHeight: details.implicitHeight
                opacity: row.minimized ? 0.5 : 1

                CachingIconImage {
                    id: rowIcon

                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: Icons.getWindowIcon(row.windowClass)
                }

                MaterialIcon {
                    anchors.centerIn: parent

                    visible: !rowIcon.visible
                    text: Icons.getAppCategoryIcon(row.windowClass, "web_asset")
                    color: row.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                id: details

                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: row.ipc?.title || row.ipc?.class || qsTr("Untitled")
                    color: row.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    // A minimized window is on the parking workspace, which says nothing useful --
                    // so it reports where it will go back to instead.
                    text: {
                        const cls = row.windowClass;
                        const ws = row.minimized ? Hypr.minimizeOriginOf(row.modelData) : row.ipc?.workspace?.name ?? "";
                        if (!ws)
                            return cls;
                        return row.minimized ? qsTr("%1 · returns to %2").arg(cls).arg(ws) : qsTr("%1 · workspace %2").arg(cls).arg(ws);
                    }
                    color: row.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.alignment: Qt.AlignVCenter

                implicitWidth: actionIcon.implicitHeight + Tokens.padding.small
                implicitHeight: actionIcon.implicitHeight + Tokens.padding.small

                StateLayer {
                    radius: Tokens.rounding.full
                    onClicked: Hypr.toggleMinimize(row.modelData)
                }

                MaterialIcon {
                    id: actionIcon

                    anchors.centerIn: parent
                    animate: true
                    text: row.minimized ? "flip_to_front" : "minimize"
                    color: row.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                }
            }
        }

        Behavior on color {
            CAnim {}
        }
    }
}
