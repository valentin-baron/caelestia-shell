pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: qsTr("Workspaces")
    isSubPage: true

    // One row per window class the shell currently knows about, plus any class hidden by a simple
    // rule that happens not to be open right now -- otherwise hiding the last window of a class
    // would remove the only control that could unhide it.
    //
    // Only entries of the plain { class: "..." } form can be driven from here. Anything richer --
    // a title, a regex -- is shown as on and left alone, because a switch cannot express it and
    // silently dropping the rule to toggle it off would lose what the file said.
    readonly property var windowRows: {
        const rules = GlobalConfig.bar.workspaces.hiddenWindows ?? [];
        const simple = new Set(rules.filter(r => typeof r["class"] === "string" && r.title === undefined).map(r => r["class"]));

        const rows = new Map();

        for (const toplevel of Hypr.toplevels.values) {
            const o = toplevel.lastIpcObject;
            const cls = o?.class;
            if (!cls || rows.has(cls))
                continue;

            const hidden = Hypr.isHiddenToplevel(toplevel);
            rows.set(cls, {
                cls,
                hidden,
                fromFile: hidden && !simple.has(cls),
                detail: o.title ?? ""
            });
        }

        for (const cls of simple)
            if (!rows.has(cls))
                rows.set(cls, {
                    cls,
                    hidden: true,
                    fromFile: false,
                    detail: qsTr("Not currently open")
                });

        const out = Array.from(rows.values()).sort((a, b) => a.cls.localeCompare(b.cls));
        for (let i = 0; i < out.length; i++) {
            out[i].last = i === out.length - 1;
            out[i].subtext = out[i].fromFile ? qsTr("Hidden by a rule in the config file") : out[i].detail;
        }
        return out;
    }

    function setHidden(cls: string, hidden: bool): void {
        const list = (GlobalConfig.bar.workspaces.hiddenWindows ?? []).slice();
        const idx = list.findIndex(r => r["class"] === cls && r.title === undefined);

        if (hidden) {
            if (idx !== -1)
                return;
            list.push({
                "class": cls
            });
        } else {
            if (idx === -1)
                return;
            list.splice(idx, 1);
        }

        GlobalConfig.bar.workspaces.hiddenWindows = list;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StepperRow {
            first: true
            label: qsTr("Shown")
            subtext: qsTr("Number of workspaces displayed")
            value: Config.bar.workspaces.shown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.shown = v
        }

        ToggleRow {
            text: qsTr("Active indicator")
            checked: Config.bar.workspaces.activeIndicator
            onToggled: GlobalConfig.bar.workspaces.activeIndicator = checked
        }

        ToggleRow {
            text: qsTr("Active trail")
            checked: Config.bar.workspaces.activeTrail
            onToggled: GlobalConfig.bar.workspaces.activeTrail = checked
        }

        ToggleRow {
            text: qsTr("Occupied background")
            checked: Config.bar.workspaces.occupiedBg
            onToggled: GlobalConfig.bar.workspaces.occupiedBg = checked
        }

        ToggleRow {
            text: qsTr("Show windows")
            subtext: qsTr("Show icons of open windows on each workspace")
            checked: Config.bar.workspaces.showWindows
            onToggled: GlobalConfig.bar.workspaces.showWindows = checked
        }

        ToggleRow {
            text: qsTr("Windows on special workspaces")
            checked: Config.bar.workspaces.showWindowsOnSpecialWorkspaces
            onToggled: GlobalConfig.bar.workspaces.showWindowsOnSpecialWorkspaces = checked
        }

        StepperRow {
            label: qsTr("Max window icons")
            subtext: qsTr("0 shows every window")
            value: Config.bar.workspaces.maxWindowIcons
            from: 0
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.maxWindowIcons = v
        }

        ToggleRow {
            // Only the last row of the whole column gets the rounded-off corner, so this keeps it
            // unless the section below has rows of its own to end with.
            last: root.windowRows.length === 0
            text: qsTr("Per-monitor workspaces")
            subtext: qsTr("Show each monitor's workspaces independently")
            checked: GlobalConfig.bar.workspaces.perMonitorWorkspaces
            onToggled: GlobalConfig.bar.workspaces.perMonitorWorkspaces = checked
        }

        SectionHeader {
            visible: root.windowRows.length > 0
            text: qsTr("Hidden windows")
        }

        Repeater {
            model: root.windowRows

            ToggleRow {
                required property var modelData

                last: modelData.last
                text: modelData.cls
                subtext: modelData.subtext
                enabled: !modelData.fromFile
                checked: modelData.hidden
                onToggled: root.setHidden(modelData.cls, checked)
            }
        }
    }
}
