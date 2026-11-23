pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Which screen draws the lock's password pill.
Scope {
    id: root

    // By preference -- Wayland has no primary-screen concept, so without this "primary" is
    // whatever output happens to be announced first. Plain entries match a connector name
    // (stable for the laptop's own panels, which don't move ports); a "model:" entry matches
    // ShellScreen.model instead, for machines where the wanted monitor can end up on a
    // different connector -- serialNumber would be the more precise match (see
    // configuration/monitor_selectors.lua's desc: selectors in the hypr config repo) but Qt's
    // Wayland backend reports it empty here (core wl_output carries no EDID serial), so model
    // is what's actually available; unique enough among these screens.
    readonly property list<string> preferredScreens: ["HDMI-A-1", "eDP-1", "model:Odyssey G93SC"]

    function matchesScreen(screen, selector) {
        const model = selector.match(/^model:(.+)$/);
        return model ? screen.model === model[1] : screen.name === selector;
    }

    // The connector name of the first preferred selector that actually matches a connected
    // screen, or empty for "all of them" -- the same fallback the greeter uses. Resolved to a
    // connector name (not left as the selector) so LockSurface's plain `name === screen.name`
    // comparison keeps working either way.
    readonly property string name: {
        for (const selector of preferredScreens) {
            const match = Quickshell.screens.find(q => matchesScreen(q, selector));
            if (match)
                return match.name;
        }
        return "";
    }
}
