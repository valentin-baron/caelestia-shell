pragma Singleton

import Quickshell
import Caelestia
import Caelestia.Config
import qs.utils

Searcher {
    id: root

    // Routed through app2unit rather than execDetached/DesktopEntry.execute() directly: neither
    // of those puts the launched process in its own systemd scope, so it is forked as a child of
    // the shell and starts out in caelestia-shell.service's own cgroup. Its top-level process can
    // end up relocated into its own app-<name>-<pid>.scope later (observed with VS Code), but
    // whatever it forked before that -- an Electron zygote and GPU process, say -- stays behind in
    // the shell's cgroup. KillMode=control-group on the shell's unit then takes those down too on
    // a restart, which is what actually crashes an app that never itself touched the shell.
    // app2unit wraps the launch in `systemd-run --user --scope` before the first fork, so the
    // whole tree is isolated from the start -- confirmed against a real launch, checking
    // /proc/<pid>/cgroup landed in its own app-Hyprland-<name>-<hash>.scope rather than the
    // shell's.
    function launch(entry: DesktopEntry): void {
        appDb.incrementFrequency(entry.id);

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "-s", "a", "-t", "scope", "--", ...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            Quickshell.execDetached({
                command: ["app2unit", "-s", "a", "-t", "scope", "--", ...entry.command],
                workingDirectory: entry.workingDirectory
            });
    }

    function search(search: string): var {
        const prefix = GlobalConfig.launcher.specialPrefix;

        if (search.startsWith(`${prefix}i `)) {
            keys = ["id", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}c `)) {
            keys = ["categories", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}d `)) {
            keys = ["comment", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}e `)) {
            keys = ["execString", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}w `)) {
            keys = ["startupClass", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}g `)) {
            keys = ["genericName", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}k `)) {
            keys = ["keywords", "name"];
            weights = [0.9, 0.1];
        } else {
            keys = ["name"];
            weights = [1];

            if (!search.startsWith(`${prefix}t `))
                return query(search).map(e => e.entry);
        }

        const results = query(search.slice(prefix.length + 2)).map(e => e.entry);
        if (search.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: appDb.apps
    useFuzzy: GlobalConfig.launcher.useFuzzy.apps

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: GlobalConfig.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id))
    }
}
