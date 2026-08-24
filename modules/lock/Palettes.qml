pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The lock-screen palettes. These started life as the SDDM greeter's paletteN combos
// (sddm/mirror/theme.conf in the hypr config repo) and the greeter still carries its own
// copy -- a combo changed here should be changed there too, and vice versa.
Scope {
    id: root

    // One combo per line, six roles in order -- the same line format theme.conf uses, so
    // syncing with the greeter is a copy-paste:
    //   background inputBackground inputBorder inputText errorBorder mutedText
    readonly property var combos: [
        "#232136 #393552 #c4a7e7 #e0def4 #eb6f92 #908caa", // rosé pine moon
        "#1e1e2e #313244 #cba6f7 #cdd6f4 #f38ba8 #7f849c", // catppuccin mocha
        "#282828 #3c3836 #d8a657 #d4be98 #ea6962 #928374", // gruvbox dark
        "#2d353b #3d484d #a7c080 #d3c6aa #e67e80 #859289", // everforest dark
        "#002b36 #073642 #268bd2 #93a1a1 #dc322f #586e75", // solarized dark
        "#152b1e #22402e #7fd8a4 #dcf2e4 #ff7a7a #6fa287", // deep forest green
        "#0d2b2b #164240 #4fd6c9 #d8f4f0 #ff7b8a #649c97", // turquoise
        "#0d1b3d #16295c #6f9dff #dbe6ff #ff6b7a #7488bd", // true navy
        "#221238 #332052 #b07aff #eadfff #ff6b9a #8d76ad", // royal purple
        "#2d0f26 #431a39 #ff5cc8 #ffdff5 #ff4d5e #a86f99", // magenta
        "#2b1216 #421c23 #ff8496 #ffe3e7 #ffd166 #a3737d", // maroon
        "#2d1a0e #422817 #ff9d5c #ffe9d9 #ff5c5c #ad8368", // burnt orange
        "#2a2105 #3d3208 #ffd54d #fff3cc #ff6b5c #a89a63", // amber
        "#251a12 #38291c #d9a066 #f3e5d8 #ff6b5c #9b8471", // espresso
        "#000000 #1a1a1a #ffffff #ffffff #ff4444 #8c8c8c", // pitch black / white
        "#faf4ed #fffaf3 #907aa9 #575279 #b4637a #9893a5", // rosé pine dawn (light)
        "#fbf1c7 #ebdbb2 #b57614 #3c3836 #9d0006 #928374", // gruvbox light
        "#fdf6e3 #eee8d5 #268bd2 #657b83 #dc322f #93a1a1", // solarized light
        "#e7f6ec #cdebd7 #27965a #1e4630 #c23a3a #74a387", // mint (light)
        "#e3f0f8 #cbe2f0 #2a7fb8 #24455c #c93a4e #7c98a8", // sky (light)
        "#fdeef4 #f8d5e5 #d64a86 #5c2e44 #b3123f #a87d92", // blush pink (light)
        "#ffffff #ececec #111111 #111111 #d00000 #767676"  // paper white / black
    ].map(line => {
        const c = line.split(/\s+/);
        return {
            background: c[0],
            inputBackground: c[1],
            inputBorder: c[2],
            inputText: c[3],
            errorBorder: c[4],
            mutedText: c[5]
        };
    })

    // Which connector draws the password pill, by preference -- Wayland has no primary-screen
    // concept, so without this "primary" is whatever output happens to be announced first.
    readonly property list<string> preferredScreens: ["HDMI-A-1", "eDP-1"]

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
}
