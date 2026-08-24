pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The SDDM greeter's paletteN combos (sddm/mirror/theme.conf in the hypr config repo),
// live-parsed so the lock screen rolls and cycles the exact looks the greeter rolls over.
Scope {
    id: root

    // Roles per combo: background inputBackground inputBorder inputText errorBorder mutedText.
    // The fallback keeps a missing/palette-less theme.conf from leaving the lock unusable.
    readonly property var fallback: [
        {
            background: "#232136",
            inputBackground: "#393552",
            inputBorder: "#c4a7e7",
            inputText: "#e0def4",
            errorBorder: "#eb6f92",
            mutedText: "#908caa"
        }
    ]

    property var combos: fallback
    property list<string> preferredScreens: []
    property int index: 0

    readonly property var current: combos[Math.min(index, combos.length - 1)]

    // The screen that draws the pill: the first preferred connector that is actually
    // connected, or empty for "all of them" -- the same fallback the greeter uses.
    readonly property string pillScreen: preferredScreens.find(s => Quickshell.screens.some(q => q.name === s)) ?? ""

    function cycle(): void {
        index = (index + 1) % combos.length;
    }

    function randomise(): void {
        index = Math.floor(Math.random() * combos.length);
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.config/hypr/sddm/mirror/theme.conf`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const combos = [];
            const screens = [];
            for (const line of text().split("\n")) {
                let m = line.match(/^palette\d+=(.*)$/);
                if (m) {
                    const c = m[1].trim().split(/\s+/);
                    if (c.length >= 6)
                        combos.push({
                            background: c[0],
                            inputBackground: c[1],
                            inputBorder: c[2],
                            inputText: c[3],
                            errorBorder: c[4],
                            mutedText: c[5]
                        });
                    continue;
                }
                m = line.match(/^primaryScreen=(.*)$/);
                if (m)
                    screens.push(...m[1].trim().split(/\s+/).filter(s => s));
            }
            root.combos = combos.length ? combos : root.fallback;
            root.preferredScreens = screens;
            if (root.index >= root.combos.length)
                root.index = 0;
        }
    }
}
