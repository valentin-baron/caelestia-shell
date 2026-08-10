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
    // Built from toplevels rather than from Hypr.workspaces.values directly. Quickshell's own
    // Hyprland-workspace tracking does not reliably drop an entry when hyprland.lua's
    // shift-back (events/spill.lua) collapses a workspace away: `hyprctl workspaces` agrees
    // with reality straight after, but Hypr.workspaces.values kept a phantom entry for the
    // collapsed id even once nothing referenced it and further Hyprland events had fired.
    // Window open/close tracking does not share that gap -- every other window-list feature in
    // this file (the per-workspace window icons below, SpecialWorkspaces') already stakes
    // itself on Hypr.toplevels.values being accurate -- so a workspace counts as existing here
    // for exactly the reasons Hyprland itself would keep it alive: it is the one a monitor is
    // actively showing (which persists at zero windows), or something has a window open on it.
    readonly property var allWorkspaces: {
        const perMonitor = GlobalConfig.bar.workspaces.perMonitorWorkspaces;
        const byId = new Map();

        const active = perMonitor ? root.monitor?.activeWorkspace : Hypr.focusedWorkspace;
        if (active)
            byId.set(active.id, active);

        for (const t of Hypr.toplevels.values) {
            const ws = t.workspace;
            if (!ws || ws.name.startsWith("special:"))
                continue;
            if (perMonitor && ws.monitor !== root.monitor)
                continue;
            byId.set(ws.id, ws);
        }

        return Array.from(byId.values()).sort((a, b) => a.id - b.id);
    }

    readonly property var occupied: {
        const occ = {};
        for (const ws of allWorkspaces)
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
                    values: root.allWorkspaces
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
                itemSpacing: layout.spacing
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
