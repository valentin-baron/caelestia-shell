pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia.I18n
import Caelestia.Services
import qs.components.misc

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors
    readonly property bool usingLua: Hyprland.usingLua

    // A single constraint out of a bar.workspaces.hiddenWindows entry, matched against one field of
    // a window. An exact string, or a { regex, flags } pair -- the same two forms bar.workspaces
    // .windowIcons accepts, so one convention covers both. An absent constraint constrains nothing
    // and so matches anything, which is what lets an entry name only the field it cares about.
    function matchesWindowRule(value: string, rule: var): bool {
        if (rule === undefined || rule === null)
            return true;

        if (typeof rule === "string")
            return value === rule;

        if (rule.regex)
            return new RegExp(rule.regex, rule.flags ?? "").test(value);

        return false;
    }

    // Whether a window should be left out of anywhere the shell lists windows. Configured through
    // bar.workspaces.hiddenWindows, which ships defaults covering the two windows screen sharing
    // brings along -- see barconfig.hpp for why those in particular.
    //
    // Matched on identity rather than on being small or transparent. A window rule can hide any
    // window that way, and inferring it from geometry would eventually swallow a real window that
    // happened to be tiny.
    function isHiddenToplevel(toplevel: var): bool {
        const o = toplevel?.lastIpcObject;
        if (!o)
            return false;

        // `?? []` guards the case this repository exists to prevent: QML running against a plugin
        // build that predates the key, where reading it gives undefined and calling .some() on that
        // would throw out of a binding every window list depends on.
        return (GlobalConfig.bar.workspaces.hiddenWindows ?? []).some(entry => {
            // `class` is a reserved word, so it is read by subscript rather than by dot.
            const cls = entry["class"];
            const title = entry.title;

            // An entry naming no field at all constrains nothing, and would otherwise match -- and
            // therefore hide -- every window on the system.
            if (cls === undefined && title === undefined)
                return false;

            return root.matchesWindowRule(o.class ?? "", cls) && root.matchesWindowRule(o.title ?? "", title);
        });
    }

    // ---- Minimize ---------------------------------------------------------------------------
    //
    // Hyprland has no minimize. A minimized window here is one moved silently onto a special
    // workspace nothing ever toggles into view (bar.windows.minimizeWorkspace), carrying a
    // `minimized:<seq>:<origin workspace>` tag that says where it came from and in what order it
    // went away.
    //
    // The tag is the only state this feature keeps, and it lives on the window in the compositor
    // rather than in the shell on purpose: this shell gets restarted often (the Quick Toggles
    // reload button, every update), and a restart that forgot which windows were minimized would
    // strand them on a workspace with no way back short of `hyprctl dispatch
    // 'hl.dsp.workspace.toggle_special("minimized")'`.

    readonly property string minimizeWorkspace: GlobalConfig.bar.windows?.minimizeWorkspace ?? "special:minimized"

    // Most recently minimized first -- restoreLast() takes the head, and the strip lists them in
    // that order so the thing you just hid is the one nearest the cursor.
    readonly property var minimizedToplevels: toplevels.values.filter(t => isListableToplevel(t) && isMinimized(t) && !isHiddenToplevel(t)).sort((a, b) => minimizeSeqOf(b) - minimizeSeqOf(a))

    // Everything else -- what the "open" half of the strip lists. Minimized windows are excluded
    // here rather than merged in dimmed, because the two halves are the whole point of the strip.
    readonly property var shownToplevels: toplevels.values.filter(t => isListableToplevel(t) && !isMinimized(t) && !isHiddenToplevel(t))

    // Hyprland's toplevel model accumulates placeholders: an entry gets created for any address
    // an event mentions, and one for a window that was already gone never gets filled in by a
    // refresh. They have no lastIpcObject at all, which means they slip past every other filter
    // here -- isHiddenToplevel answers false when there is nothing to match on, and isMinimized
    // compares undefined -- and so would list as blank rows forever. Nothing upstream noticed
    // because nothing upstream lists windows globally.
    function isListableToplevel(toplevel: var): bool {
        const obj = toplevel?.lastIpcObject;
        return !!obj && obj.class !== undefined && obj.mapped !== false;
    }

    function isMinimized(toplevel: var): bool {
        return toplevel?.lastIpcObject?.workspace?.name === root.minimizeWorkspace;
    }

    function minimizeTagOf(toplevel: var): string {
        return (toplevel?.lastIpcObject?.tags ?? []).find(t => t.startsWith("minimized:")) ?? "";
    }

    function minimizeSeqOf(toplevel: var): int {
        const match = root.minimizeTagOf(toplevel).match(/^minimized:(\d+):/);
        return match ? parseInt(match[1]) : 0;
    }

    // The rest of the tag after the sequence number, which is a workspace NAME and may itself
    // contain colons -- minimizing something that was already on a special workspace records
    // "special:hoyoplay". Hence slicing at the second colon rather than splitting on every one.
    function minimizeOriginOf(toplevel: var): string {
        const tag = root.minimizeTagOf(toplevel);
        const sep = tag.indexOf(":", "minimized:".length);
        return sep === -1 ? "" : tag.slice(sep + 1);
    }

    // A workspace NAME turned into something the movetoworkspace selector understands. A bare
    // number means an ID to Hyprland and the workspaces here are named after their IDs, so that
    // form passes through; anything else has to say `name:` or it would be read as an ID and
    // silently land somewhere else.
    function workspaceSelector(name: string): string {
        if (!name)
            return "";
        if (name.startsWith("special:") || /^\d+$/.test(name))
            return name;
        return `name:${name}`;
    }

    // Switches to the window's workspace on the way, which is what makes the window strip a way
    // of getting somewhere rather than just a list of what exists.
    function focusToplevel(toplevel: var): void {
        const obj = toplevel?.lastIpcObject;
        if (!obj)
            return;

        if (isMinimized(toplevel)) {
            restore(toplevel);
            return;
        }

        const addr = `address:${obj.address}`;
        dispatch(usingLua ? `hl.dsp.focus({ window = "${addr}" })` : `focuswindow ${addr}`);
    }

    function minimize(toplevel: var): void {
        const obj = toplevel?.lastIpcObject;
        if (!obj || isMinimized(toplevel))
            return;

        // Scanning the live tags for the high-water mark rather than keeping a counter: a counter
        // would reset on every shell restart and start handing out sequence numbers below ones
        // already on windows, which would reorder the minimized list for no visible reason.
        const seq = Math.max(0, ...toplevels.values.map(t => minimizeSeqOf(t))) + 1;
        const tag = `minimized:${seq}:${obj.workspace?.name ?? ""}`;
        const addr = `address:${obj.address}`;

        // Tag first, move second, in one batch. The move is what makes Hyprland emit an event, and
        // that event is what triggers the toplevel refresh the shell reads the tag back out of --
        // tagging afterwards would leave the window listed as minimized-from-nowhere until some
        // unrelated event happened along.
        extras.batchMessage(usingLua ? [`dispatch hl.dsp.window.tag({ tag = "+${tag}", window = "${addr}" })`, `dispatch hl.dsp.window.move({ window = "${addr}", workspace = "${root.minimizeWorkspace}", follow = false })`] : [`dispatch tagwindow +${tag} ${addr}`, `dispatch movetoworkspacesilent ${root.minimizeWorkspace},${addr}`]);
    }

    function restore(toplevel: var): void {
        const obj = toplevel?.lastIpcObject;
        if (!obj || !isMinimized(toplevel))
            return;

        const tag = root.minimizeTagOf(toplevel);
        const addr = `address:${obj.address}`;
        // No tag, or a tag naming a workspace that cannot be parsed, means the current workspace:
        // better to hand the window back somewhere visible than to leave it parked.
        const target = root.workspaceSelector(root.minimizeOriginOf(toplevel)) || `${root.activeWsId}`;

        // Untag before the move, for the mirror of the reason minimize tags before it: a window
        // that landed on a real workspace still carrying the tag would be listed in both halves of
        // the strip at once.
        extras.batchMessage(usingLua ? [`dispatch hl.dsp.window.tag({ tag = "-${tag}", window = "${addr}" })`, `dispatch hl.dsp.window.move({ window = "${addr}", workspace = "${target}", follow = true })`, `dispatch hl.dsp.focus({ window = "${addr}" })`] : [`dispatch tagwindow -${tag} ${addr}`, `dispatch movetoworkspace ${target},${addr}`, `dispatch focuswindow ${addr}`]);
    }

    function toggleMinimize(toplevel: var): void {
        if (isMinimized(toplevel))
            restore(toplevel);
        else
            minimize(toplevel);
    }

    function minimizeActive(): void {
        // Hyprland.activeToplevel rather than this service's activeToplevel: that one reports null
        // for a focused window on an otherwise empty workspace, which is exactly the last window
        // someone would want to minimize.
        const toplevel = Hyprland.activeToplevel;
        if (toplevel && !isHiddenToplevel(toplevel))
            minimize(toplevel);
    }

    function restoreLast(): void {
        const toplevel = minimizedToplevels[0];
        if (toplevel)
            restore(toplevel);
    }

    // Hyprland fires `minimized` when a wlr-foreign-toplevel client asks for a window to be
    // minimized or restored. It is a request and nothing more -- Hyprland records no state and
    // takes no action -- so acting on it here is what makes minimize mean anything to something
    // outside this shell.
    //
    // X11 windows asking on their own behalf do NOT arrive here, and cannot be made to: an
    // Xwayland client iconifying itself (WM_CHANGE_STATE, the titlebar minimize button, "minimize
    // to tray") sets requestsMinimize on the surface, which Hyprland reads nowhere and never
    // turns into an event. Honouring those would take a patched Hyprland.
    function handleMinimizeRequest(data: string): void {
        const [addr, state] = data.split(",");
        const toplevel = toplevels.values.find(t => t.address === addr);
        if (!toplevel)
            return;

        if (state === "1")
            minimize(toplevel);
        else
            restore(toplevel);
    }

    readonly property HyprlandToplevel activeToplevel: {
        const t = Hyprland.activeToplevel;
        return t?.workspace?.name.startsWith("special:") || Hyprland.focusedWorkspace?.toplevels.values.length > 0 ? t : null;
    }
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    readonly property HyprKeyboard keyboard: extras.devices.keyboards.find(kb => kb.main) ?? null
    readonly property bool capsLock: keyboard?.capsLock ?? false
    readonly property bool numLock: keyboard?.numLock ?? false
    readonly property string defaultKbLayout: keyboard?.layout.split(",")[0] ?? "??"
    readonly property string kbLayoutFull: keyboard?.activeKeymap ?? Tr.trCtx("Unknown", "keyboard layout")
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? "??"
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property string lastSpecialWorkspace: ""

    signal configReloaded

    function dispatch(request: string): void {
        Hyprland.dispatch(request);
    }

    function focusWorkspace(ws: var): void {
        dispatch(usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
    }

    function toggleSpecial(name: string): void {
        dispatch(usingLua ? `hl.dsp.workspace.toggle_special("${name}")` : `togglespecialworkspace ${name}`);
    }

    function cycleSpecialWorkspace(direction: string): void {
        const openSpecials = workspaces.values.filter(w => w.name.startsWith("special:") && w.name !== root.minimizeWorkspace && w.lastIpcObject.windows > 0);

        if (openSpecials.length === 0)
            return;

        const activeSpecial = focusedMonitor.lastIpcObject.specialWorkspace.name ?? "";

        if (!activeSpecial) {
            if (lastSpecialWorkspace) {
                const workspace = workspaces.values.find(w => w.name === lastSpecialWorkspace);
                if (workspace && workspace.lastIpcObject.windows > 0) {
                    focusWorkspace(lastSpecialWorkspace);
                    return;
                }
            }
            focusWorkspace(openSpecials[0].name);
            return;
        }

        const currentIndex = openSpecials.findIndex(w => w.name === activeSpecial);
        let nextIndex = 0;

        if (currentIndex !== -1) {
            if (direction === "next")
                nextIndex = (currentIndex + 1) % openSpecials.length;
            else
                nextIndex = (currentIndex - 1 + openSpecials.length) % openSpecials.length;
        }

        focusWorkspace(openSpecials[nextIndex].name);
    }

    function monitorNames(): list<string> {
        return monitors.values.map(e => e.name);
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function trimWsName(name: string): string {
        return name.startsWith("special:") ? name.slice("special:".length) : name;
    }

    function toplevelsForWs(ws: int, ignoredTags = []): list<HyprlandToplevel> {
        return toplevels.values.filter(t => t.workspace && t.workspace.id === ws && !isToplevelIgnored(t, ignoredTags));
    }

    function isToplevelIgnored(toplevel: HyprlandToplevel, ignoredTags = []): bool {
        const ipc = toplevel?.lastIpcObject;
        if (!ipc?.class || !ipc.mapped)
            return true;

        if (isHiddenToplevel(toplevel))
            return true;

        return ipc.tags?.some(tag => ignoredTags.includes(tag.replace(/\*$/, ""))) ?? false;
    }

    function reloadDynamicConfs(): void {
        if (usingLua) {
            extras.batchMessage(['eval hl.bind("Caps_Lock", hl.dsp.global("caelestia:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true, release = true })', 'eval hl.bind("Num_Lock", hl.dsp.global("caelestia:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true, release = true })']);
        } else {
            extras.batchMessage(["keyword bindlni ,Caps_Lock,global,caelestia:refreshDevices", "keyword bindlni ,Num_Lock,global,caelestia:refreshDevices"]);
        }
    }

    onUsingLuaChanged: reloadDynamicConfs()
    Component.onCompleted: reloadDynamicConfs()

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (n === "minimized") {
                root.handleMinimizeRequest(event.data);
            } else if (n === "configreloaded") {
                root.configReloaded();
                root.reloadDynamicConfs();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }

        target: Hyprland
    }

    Connections {
        function onLastIpcObjectChanged(): void {
            const specialName = root.focusedMonitor.lastIpcObject.specialWorkspace.name;

            if (specialName && specialName.startsWith("special:")) {
                root.lastSpecialWorkspace = specialName;
            }
        }

        target: root.focusedMonitor
    }

    FileView {
        id: kbLayoutFile

        path: Quickshell.env("CAELESTIA_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                const lines = layoutMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                const lines = variantMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
        }
    }

    IpcHandler {
        function refreshDevices(): void {
            extras.refreshDevices();
        }

        function cycleSpecialWorkspace(direction: string): void {
            root.cycleSpecialWorkspace(direction);
        }

        // What SUPER + H and SUPER + SHIFT + H in configuration/keybinds.lua call. The binds go
        // through the shell rather than doing the moves themselves so there is one implementation
        // of the tag format, not a Lua copy to keep in step with this one.
        function minimize(): void {
            root.minimizeActive();
        }

        function restoreLast(): void {
            root.restoreLast();
        }

        // Diagnostic, and the only way to see these two lists from outside the shell: a bar entry
        // that renders nothing looks identical whether its component failed to load or its model
        // is simply empty, and nothing is logged in either case.
        function listWindows(): string {
            const fmt = t => `${t.lastIpcObject?.class ?? "?"}\t${t.lastIpcObject?.workspace?.name ?? "?"}\t${t.lastIpcObject?.title ?? "?"}`;
            const placeholders = root.toplevels.values.filter(t => !root.isListableToplevel(t)).length;
            return `open=${root.shownToplevels.length} minimized=${root.minimizedToplevels.length} placeholders=${placeholders}\n` + root.shownToplevels.map(fmt).join("\n");
        }

        function listMinimized(): string {
            return root.minimizedToplevels.map(t => `${t.lastIpcObject.class}\t${t.lastIpcObject.title}`).join("\n");
        }

        function listSpecialWorkspaces(): string {
            return root.workspaces.values.filter(w => w.name.startsWith("special:") && w.name !== root.minimizeWorkspace && w.lastIpcObject.windows > 0).map(w => w.name).join("\n");
        }

        target: "hypr"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "refreshDevices"
        description: "Reload devices"
        onPressed: extras.refreshDevices()
        onReleased: extras.refreshDevices()
    }

    HyprExtras {
        id: extras

        usingLua: Hyprland.usingLua
    }
}
