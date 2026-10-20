pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Caelestia.Config

Singleton {
    id: root

    readonly property var weatherIcons: ({
            "0": "clear_day",
            "1": "clear_day",
            "2": "partly_cloudy_day",
            "3": "cloud",
            "45": "foggy",
            "48": "foggy",
            "51": "rainy",
            "53": "rainy",
            "55": "rainy",
            "56": "rainy",
            "57": "rainy",
            "61": "rainy",
            "63": "rainy",
            "65": "rainy",
            "66": "rainy",
            "67": "rainy",
            "71": "cloudy_snowing",
            "73": "cloudy_snowing",
            "75": "snowing_heavy",
            "77": "cloudy_snowing",
            "80": "rainy",
            "81": "rainy",
            "82": "rainy",
            "85": "cloudy_snowing",
            "86": "snowing_heavy",
            "95": "thunderstorm",
            "96": "thunderstorm",
            "99": "thunderstorm"
        })

    readonly property var categoryIcons: ({
            WebBrowser: "web",
            Printing: "print",
            Security: "security",
            Network: "chat",
            Archiving: "archive",
            Compression: "archive",
            Development: "code",
            IDE: "code",
            TextEditor: "edit_note",
            Audio: "music_note",
            Music: "music_note",
            Player: "music_note",
            Recorder: "mic",
            Game: "sports_esports",
            FileTools: "files",
            FileManager: "files",
            Filesystem: "files",
            FileTransfer: "files",
            Settings: "settings",
            DesktopSettings: "settings",
            HardwareSettings: "settings",
            TerminalEmulator: "terminal",
            ConsoleOnly: "terminal",
            Utility: "build",
            Monitor: "monitor_heart",
            Midi: "graphic_eq",
            Mixer: "graphic_eq",
            AudioVideoEditing: "video_settings",
            AudioVideo: "music_video",
            Video: "videocam",
            Building: "construction",
            Graphics: "photo_library",
            "2DGraphics": "photo_library",
            RasterGraphics: "photo_library",
            TV: "tv",
            System: "host",
            Office: "content_paste"
        })

    // qmlformat off
    readonly property list<string> networkIcons: [
        "signal_wifi_0_bar",
        "network_wifi_1_bar",
        "network_wifi_2_bar",
        "network_wifi_3_bar",
        "network_wifi"
    ]

    readonly property var bluetoothIconRules: [
        [["headset", "headphones"], "headphones"],
        [["audio"], "speaker"],
        [["phone"], "smartphone"],
        [["mouse"], "mouse"],
        [["keyboard"], "keyboard"]
    ]

    readonly property var notifIconRules: [
        [["reboot"], "restart_alt"],
        [["recording"], "screen_record"],
        [["battery"], "power"],
        [["screenshot"], "screenshot_monitor"],
        [["welcome"], "waving_hand"],
        [["time", "a break"], "schedule"],
        [["installed"], "download"],
        [["update"], "update"],
        [["unable to"], "deployed_code_alert"],
        [["profile"], "person"],
        [["file"], "folder_copy"]
    ]
    // qmlformat on

    /**
     * Checks if a name matches an icon rule. See the IconRule type in the config module.
     */
    function matchIconRule(name: string, iconRule: var): bool {
        if (!iconRule.icon)
            return false;

        if (iconRule.regex) {
            const re = new RegExp(iconRule.regex, iconRule.flags ?? "");
            if (re.test(name))
                return true;
        } else if (iconRule.name === name) {
            return true;
        }

        return false;
    }

    function matchIconRuleList(name: string, rules: var): string {
        if (!rules)
            return "";

        for (const iconRule of rules.values)
            if (matchIconRule(name, iconRule))
                return iconRule.icon;

        return "";
    }

    function getAppIcon(name: string, fallback: string): string {
        const icon = DesktopEntries.heuristicLookup(name)?.icon;
        if (fallback !== "undefined")
            return Quickshell.iconPath(icon, fallback);
        return Quickshell.iconPath(icon);
    }

    // A window's `class` is not a desktop entry ID and is often nowhere near one: Electron and
    // Xwayland apps report reverse-DNS (org.jitsi.jitsi-meet, entry jitsi-meet-desktop) or their
    // own hyphenation (rocket-chat, entry rocketchat-desktop), and a Steam game reports
    // steam_app_<id> with no entry anywhere. Trying the trailing dotted segment as well catches
    // the first family; the rest resolve to nothing on purpose, so the caller can fall back to
    // getAppCategoryIcon -- a glyph from the bundled symbol font always renders, where a themed
    // icon name that is not in the current theme silently draws nothing at all.
    function getWindowIcon(windowClass: string): string {
        // Its own matcher rather than matchIconConfig: that one opens with `if (!iconConfig.icon)
        // return false`, because it serves bar.workspaces.windowIcons where every entry names a
        // glyph. An iconSubs entry may instead name an `image`, and reusing the shared matcher
        // silently dropped every one of those on the floor.
        for (const sub of GlobalConfig.bar.windows?.iconSubs ?? []) {
            const matches = sub.regex ? new RegExp(sub.regex, sub.flags ?? "").test(windowClass) : sub.name === windowClass;
            if (!matches)
                continue;

            if (sub.image)
                return Qt.resolvedUrl(sub.image);
            if (sub.icon)
                return Quickshell.iconPath(sub.icon, "");
        }

        // A window's class is not a desktop entry ID and is often nowhere near one: Electron and
        // Xwayland apps report reverse-DNS (org.jitsi.jitsi-meet, entry jitsi-meet-desktop) or
        // their own hyphenation (rocket-chat, entry rocketchat-desktop). The trailing dotted
        // segment catches the first family.
        const names = [windowClass, windowClass.split(".").pop()];

        for (const name of names) {
            if (!name)
                continue;

            const icon = DesktopEntries.heuristicLookup(name)?.icon;
            if (icon) {
                const path = Quickshell.iconPath(icon, "");
                if (path)
                    return path;
            }
        }

        // The heuristic needs a desktop entry to exist and to be found; plenty of apps ship an
        // icon themed under the very name they report as their class (firefox, kitty,
        // org.remmina.Remmina) and lose out when the entry lookup misses for some unrelated
        // reason. Asking the icon theme directly costs nothing and is right more often than not.
        for (const name of names) {
            if (!name)
                continue;

            const path = Quickshell.iconPath(name, "");
            if (path)
                return path;
        }

        // Nothing resolved on purpose, so the caller falls back to getAppCategoryIcon -- a glyph
        // from the bundled symbol font always renders, where a themed name that is not in the
        // current theme silently draws nothing at all.
        return "";
    }

    function getAppCategoryIcon(name: string, fallback: string): string {
        const match = matchIconRuleList(name, GlobalConfig.bar.workspaces.windowIcons);
        if (match)
            return match;

        const categories = DesktopEntries.heuristicLookup(name)?.categories;
        if (categories)
            for (const [key, value] of Object.entries(categoryIcons))
                if (categories.includes(key))
                    return value;

        return fallback;
    }

    /**
     * Accepts a list of tables containing matching rules (strings) and their corresponding results.
     * If any of the strings are found in the text, returns the result associated with them. Otherwise returns the fallback.
     */
    function matchIcon(text: string, rules: var, fallback: string): string {
        for (const [needles, result] of rules)
            if (needles.some(n => text.includes(n)))
                return result;

        return fallback;
    }

    function getNetworkIcon(strength: int, isSecure = false): string {
        const level = Math.max(0, Math.min(4, Math.floor(strength / 20)));
        const icon = networkIcons[level];

        return isSecure && level > 0 ? `${icon}_locked` : icon;
    }

    function getBluetoothIcon(icon: string): string {
        return matchIcon(icon, bluetoothIconRules, "bluetooth");
    }

    function getWeatherIcon(code: string): string {
        return weatherIcons[code] ?? "air";
    }

    function getNotifIcon(summary: string, urgency: int): string {
        const fallback = urgency === NotificationUrgency.Critical ? "release_alert" : "chat";
        return matchIcon(summary.toLowerCase(), notifIconRules, fallback);
    }

    function getVolumeIcon(volume: real, isMuted: bool): string {
        if (isMuted)
            return "no_sound";
        if (volume >= 0.5)
            return "volume_up";
        if (volume > 0)
            return "volume_down";
        return "volume_mute";
    }

    function getMicVolumeIcon(volume: real, isMuted: bool): string {
        return !isMuted && volume > 0 ? "mic" : "mic_off";
    }

    function getTrayIcon(id: string, icon: string): string {
        for (const sub of GlobalConfig.bar.tray.iconSubs.values)
            if (sub.id === id)
                return sub.image ? Qt.resolvedUrl(sub.image) : Quickshell.iconPath(sub.icon);

        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=");
            const file = name.slice(name.lastIndexOf("/") + 1);
            const themed = Quickshell.iconPath(file, true);
            icon = themed ? themed : Qt.resolvedUrl(`${path}/${file}`);
        }
        return icon;
    }

    function getBatteryIcon(percentage: real, charging = false): string {
        if (percentage === 1)
            return charging ? "battery_charging_full" : "battery_full";
        let level = Math.floor(percentage * 7);
        if (charging && (level === 4 || level === 1))
            level--;
        return charging ? `battery_charging_${(level + 3) * 10}` : `battery_${level}_bar`;
    }
}
