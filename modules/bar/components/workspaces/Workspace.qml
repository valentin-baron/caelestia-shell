pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property HyprlandWorkspace modelData
    required property int activeWsId

    readonly property bool isWorkspace: true // Flag for finding workspace children
    // Unanimated prop for others to use as reference
    readonly property int size: implicitHeight + (hasWindows ? Tokens.padding.extraSmall : 0)

    // Cached rather than read straight off modelData: the model destroys it partway through the
    // remove animation that plays when the workspace collapses away (see events/spill.lua on the
    // Hyprland side), and this is what the row keeps showing while that animation finishes.
    property int ws
    property string wsName
    property bool isOccupied
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    anchors.horizontalCenter: parent.horizontalCenter
    height: size

    spacing: 0

    Component.onCompleted: {
        ws = modelData.id;
        wsName = modelData.name;
        isOccupied = modelData.lastIpcObject.windows > 0;
    }

    Connections {
        function onIdChanged(): void {
            if (root.modelData)
                root.ws = root.modelData.id;
        }

        function onNameChanged(): void {
            if (root.modelData)
                root.wsName = root.modelData.name;
        }

        function onLastIpcObjectChanged(): void {
            if (root.modelData)
                root.isOccupied = root.modelData.lastIpcObject.windows > 0;
        }

        target: root.modelData
    }

    StyledText {
        id: indicator

        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
        Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small

        animate: true
        text: {
            const wsName = root.wsName === root.ws.toString() ? root.ws : root.wsName[0];
            let displayName = wsName.toString();
            if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                displayName = displayName.toUpperCase();
            } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                displayName = displayName.toLowerCase();
            }
            const label = Config.bar.workspaces.label || displayName;
            const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
            const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
            return root.activeWsId === root.ws ? activeLabel : root.isOccupied ? occupiedLabel : label;
        }
        color: Config.bar.workspaces.occupiedBg || root.isOccupied || root.activeWsId === root.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
        verticalAlignment: Qt.AlignVCenter
        font.family: Tokens.font.workspaces
    }

    Loader {
        id: windows

        asynchronous: true

        Layout.alignment: Qt.AlignHCenter
        Layout.fillHeight: true
        Layout.topMargin: -Tokens.sizes.bar.innerWidth / 10

        visible: active
        active: root.hasWindows

        sourceComponent: Column {
            spacing: 0

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: {
                        const ws = root.ws;
                        const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === ws && !Hypr.isHiddenToplevel(c));
                        const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                MaterialIcon {
                    required property var modelData

                    // Which of these has focus is the one thing the row did not say. It matters most
                    // where the windows overlap -- a monocle layout, a fullscreened window, a stack
                    // being cycled -- since then this row is the only indication of where in the
                    // stack you are, the screen itself showing only one of them.
                    //
                    // Compared by address rather than by object identity: these come out of a
                    // ScriptModel, which gives no guarantee of handing back the same instance the
                    // service holds, and an address is how the rest of the shell names a toplevel.
                    readonly property bool isActive: modelData?.address !== undefined && modelData.address === Hypr.activeToplevel?.address

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")

                    // Dimming the others rather than recolouring the active one. The palette is
                    // generated per wallpaper, and nothing keeps two of its roles apart: this
                    // machine's scheme puts m3primary at #c2c1ff and m3onSurfaceVariant at #c8c5d1,
                    // near enough that a colour swap between them is invisible at icon size. Nor
                    // `fill`, which would do nothing for a symbol with no interior to fill -- the
                    // `code` glyph is a pair of chevrons. Opacity cannot collide with a palette and
                    // holds for every glyph.
                    opacity: isActive ? 1 : 0.45

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }
        }
    }

    Behavior on height {
        Anim {}
    }
}
