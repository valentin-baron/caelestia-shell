pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Repeater workspaces
    required property var occupied

    property list<var> pills: []

    // The ids currently in the repeater, in display order. Positions used to be derivable from
    // an id with plain arithmetic (mod `Config.bar.workspaces.shown`), back when the row was a
    // fixed-size page of consecutive ids; now that it is exactly as long as the real workspace
    // count, a pill's start/end has to be looked up by id instead.
    readonly property var shownIds: {
        const ids = [];
        for (let i = 0; i < workspaces.count; i++)
            ids.push((workspaces.itemAt(i) as Workspace)?.ws);
        return ids;
    }

    onOccupiedChanged: {
        if (!occupied)
            return;
        const ids = shownIds;
        let count = 0;
        for (let i = 0; i < ids.length; i++) {
            const ws = ids[i];
            if (occupied[ws]) {
                const isFirstInGroup = i === 0 || !occupied[ids[i - 1]];
                const isLastInGroup = i === ids.length - 1 || !occupied[ids[i + 1]];
                if (isFirstInGroup) {
                    if (pills[count])
                        pills[count].start = ws;
                    else
                        pills.push(pillComp.createObject(root, {
                            start: ws
                        }));
                    count++;
                }
                if (isLastInGroup && pills[count - 1])
                    pills[count - 1].end = ws;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        StyledRect {
            id: rect

            required property var modelData

            readonly property Workspace start: root.workspaces.count > 0 ? root.workspaces.itemAt(root.shownIds.indexOf(modelData.start)) ?? null : null // qmllint disable incompatible-type
            readonly property Workspace end: root.workspaces.count > 0 ? root.workspaces.itemAt(root.shownIds.indexOf(modelData.end)) ?? null : null // qmllint disable incompatible-type

            anchors.horizontalCenter: root.horizontalCenter

            y: (start?.y ?? 0) - 1
            implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small + 2
            implicitHeight: start && end ? end.y + end.size - start.y + 2 : 0

            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
            radius: Tokens.rounding.full

            scale: 0
            Component.onCompleted: scale = 1

            Behavior on scale {
                Anim {
                    easing: Tokens.anim.standardDecel
                }
            }

            Behavior on y {
                Anim {}
            }

            Behavior on implicitHeight {
                Anim {}
            }
        }
    }

    Component {
        id: pillComp

        Pill {}
    }

    component Pill: QtObject {
        property int start
        property int end
    }
}
