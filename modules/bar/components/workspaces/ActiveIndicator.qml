pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

StyledRect {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    required property bool fullscreen
    required property real itemSpacing

    // Used to be derivable from activeWsId with plain arithmetic (mod `Config.bar.workspaces
    // .shown`), back when the row was a fixed-size page of consecutive ids at a known offset.
    // Now that it is exactly as long as the real workspace count, the active one's position has
    // to be looked up instead -- it is always in there somewhere at rest, since a monitor never
    // lets go of the workspace it is showing.
    //
    // "At rest" is doing work: a spill or a hyprland.lua shift-back collapse fires several
    // Hyprland events in a row, and activeWsId can update a tick before (spilling onto a new
    // workspace) or after (collapsing one away) the row's own icons catch up. Falling back to
    // index 0 during that window used to snap the indicator to the first workspace and then
    // visibly drag it back once the real position resolved -- looked like the first workspace
    // was what got focused. Holding the last resolved index across a miss instead means the
    // indicator just sits still through the gap and slides directly to wherever activeWsId
    // ends up, with no detour through index 0.
    readonly property int foundWsIdx: {
        for (let i = 0; i < workspaces.count; i++)
            if ((workspaces.itemAt(i) as Workspace)?.ws === activeWsId)
                return i;
        return -1;
    }

    property int currentWsIdx: 0

    property real leading: workspaces.count > 0 ? yAt(currentWsIdx) : 0
    property real trailing: workspaces.count > 0 ? yAt(currentWsIdx) : 0
    property real currentSize: workspaces.count > 0 ? (workspaces.itemAt(currentWsIdx) as Workspace)?.size ?? 0 : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs) as Workspace;
            return ws ? Math.min(yAt(lastWs) + ws.size - offset, s) : 0;
        }
        return s;
    }

    property int cWs
    property int lastWs

    // Column has not necessarily positioned a just-added item's `y` yet by the time it becomes
    // the current index -- confirmed live: reading itemAt(idx).y right as currentWsIdx changes
    // to a brand new item returns 0, the same as index 0, even a tick after deferring with
    // Qt.callLater. Deriving the position from each item's own `size` instead of its `y` sidesteps
    // that race entirely: `size` is intrinsic to the item (its content's height, plus padding when
    // it has windows) and is correct the instant the item exists, regardless of whether Column has
    // gotten around to positioning it. Reading `.y` here used to make a new workspace's indicator
    // motion start from wherever index 0 happens to sit -- exactly the "first workspace flashes,
    // then drags to the new one" this replaces.
    function yAt(idx: int): real {
        let y = 0;
        for (let i = 0; i < idx; i++)
            y += ((workspaces.itemAt(i) as Workspace)?.size ?? 0) + itemSpacing;
        return y;
    }

    function syncCurrentWsIdx(): void {
        if (foundWsIdx >= 0)
            currentWsIdx = foundWsIdx;
    }

    Component.onCompleted: syncCurrentWsIdx()
    onFoundWsIdxChanged: syncCurrentWsIdx()

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true
    y: offset + mask.y
    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
    implicitHeight: size
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: 0
        y: -parent.offset
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.horizontalCenter: parent.horizontalCenter
    }

    Behavior on leading {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on trailing {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {
            duration: Tokens.anim.durations.normal * 2
        }
    }

    Behavior on currentSize {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on offset {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on size {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        type: Anim.Emphasized
    }
}
