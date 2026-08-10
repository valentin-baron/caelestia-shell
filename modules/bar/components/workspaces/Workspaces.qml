pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool onSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? monitor : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (monitor.activeWorkspace?.id ?? 1) : Hypr.activeWsId

    // Every non-special workspace this bar segment is responsible for -- one monitor's worth
    // when per-monitor workspaces are on, everything Hyprland currently knows about otherwise.
    // Sorted so the icons read in workspace order.
    //
    // A workspace exists here for exactly as long as Hyprland keeps the object alive: the
    // active one always (a monitor never lets go of the workspace it is showing), plus any
    // other with a window on it. Nothing stands in for an id that nothing occupies, which is
    // what lets this row grow and shrink with the real workspace count instead of paging
    // through a fixed-size window of ids that may or may not exist.
    readonly property var allWorkspaces: Hypr.workspaces.values
        .filter(w => !w.name.startsWith("special:") && (!GlobalConfig.bar.workspaces.perMonitorWorkspaces || w.monitor === root.monitor))
        .sort((a, b) => a.id - b.id)

    // `shown` used to be how many ids were always displayed; now that the row is exactly as
    // long as the real count, it instead caps how long the row is allowed to grow before it
    // starts dropping the workspaces furthest from the one in view -- centred on activeWsId
    // rather than on either end, so the one being looked at never falls off.
    readonly property var shownWorkspaces: {
        const all = root.allWorkspaces;
        const max = Config.bar.workspaces.shown;
        if (all.length <= max)
            return all;

        const activeIdx = Math.max(0, all.findIndex(w => w.id === root.activeWsId));
        const start = Math.min(Math.max(activeIdx - Math.floor((max - 1) / 2), 0), all.length - max);
        return all.slice(start, start + max);
    }

    readonly property var occupied: {
        const occ = {};
        for (const ws of shownWorkspaces)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }

    property real blur: onSpecial ? 1 : 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.small

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Behavior on implicitHeight {
        Anim {}
    }

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
            }
        }

        Column {
            id: layout

            anchors.centerIn: parent
            spacing: Math.floor(Tokens.spacing.extraSmall)

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
            }

            // Column has no `remove` transition -- only add/move/populate -- so a collapsing
            // workspace's icon disappears on the spot rather than fading out; the same
            // limitation the window-icon Column above already lives with. What's left still
            // animates: `move` slides the remaining icons into place, which is most of what
            // "the row shrinks" needs to look like.
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
                id: workspaces

                model: ScriptModel {
                    values: root.shownWorkspaces
                }

                Workspace {
                    activeWsId: root.activeWsId
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.horizontalCenter: parent.horizontalCenter
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
                fullscreen: root.fullscreen
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = (layout.childAt(event.x, event.y) as Workspace)?.ws;
                if (!ws)
                    return;
                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
                else
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: specialWs

        asynchronous: true

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
