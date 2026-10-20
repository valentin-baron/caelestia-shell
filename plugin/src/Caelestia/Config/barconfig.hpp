#pragma once

#include <qstring.h>
#include <qstringlist.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

class BarScrollActions : public settings::ObjectNode {
    CONFIG_NODE(BarScrollActions, settings::ObjectNode)

    CONFIG_PROPERTY(bool, workspaces, true)
    CONFIG_PROPERTY(bool, volume, true)
    CONFIG_PROPERTY(bool, brightness, true)
};

class BarPopouts : public settings::ObjectNode {
    CONFIG_NODE(BarPopouts, settings::ObjectNode)

    CONFIG_PROPERTY(bool, activeWindow, true)
    CONFIG_PROPERTY(bool, windows, true)
    CONFIG_PROPERTY(bool, tray, true)
    CONFIG_PROPERTY(bool, statusIcons, true)
};

class BarWorkspaces : public settings::ObjectNode {
    CONFIG_NODE(BarWorkspaces, settings::ObjectNode)

    CONFIG_PROPERTY(int, shown, 5)
    CONFIG_PROPERTY(bool, activeIndicator, true)
    CONFIG_PROPERTY(bool, occupiedBg, false)
    CONFIG_PROPERTY(bool, showUnoccupied, true)
    CONFIG_PROPERTY(bool, perMonitor, true)
    CONFIG_PROPERTY(bool, showWindows, true)
    CONFIG_PROPERTY(bool, showWindowsOnSpecialWorkspaces, true)
    CONFIG_PROPERTY(int, maxWindowIcons, 5)
    CONFIG_PROPERTY(bool, activeTrail, true)
    CONFIG_ENUM_PROPERTY(BarWorkspaceDisplay, displayType, BarWorkspaceDisplay::Shapes)
    CONFIG_ENUM_PROPERTY(BarWorkspaceDisplay, specialDisplayType, BarWorkspaceDisplay::Icons)
    CONFIG_PROPERTY(QString, label, u"  "_s)
    CONFIG_PROPERTY(QString, occupiedLabel, u"󰮯"_s)
    CONFIG_PROPERTY(QString, activeLabel, u"󰮯"_s)
    CONFIG_ENUM_PROPERTY(BarWorkspaceCapitalisation, capitalisation, BarWorkspaceCapitalisation::Preserve)
    CONFIG_GLOBAL_LIST(IconRuleList, workspaceIcons, {})
    CONFIG_GLOBAL_LIST(IconRuleList, specialWorkspaceIcons,
        DEFAULT_ARG({
            ICON_RULE_EXACT("special", "star"),
            ICON_RULE_EXACT("communication", "forum"),
            ICON_RULE_EXACT("music", "music_cast"),
            ICON_RULE_EXACT("todo", "checklist"),
            ICON_RULE_EXACT("sysmon", "monitor_heart"),
        }))
    CONFIG_GLOBAL_PROPERTY(QStringList, ignoredTags,
        DEFAULT_ARG({
            u"hide_in_bar"_s,
            u"xwl_popup"_s,
        }))
    CONFIG_GLOBAL_LIST(IconRuleList, windowIcons,
        DEFAULT_ARG({
            ICON_RULE_REGEX("steam(_app_(default|[0-9]+))?", "", "sports_esports"),
        }))
    // Windows to leave out of anywhere the shell lists windows. Each entry constrains `class`
    // and/or `title`; a constraint is either an exact string or a { regex, flags } pair, and every
    // constraint an entry names must match. See Hypr.isHiddenToplevel.
    //
    // The defaults are windows that only exist so screen sharing can work -- the Xwayland video
    // bridge, and the tracker Jitsi opens for the duration of a share. Both are pinned to 1x1 at
    // opacity 0 and refuse focus, so listing them offers something that cannot be seen, clicked or
    // switched to. Setting this key in the config replaces these rather than adding to them.
    CONFIG_GLOBAL_PROPERTY(QVariantList, hiddenWindows,
        DEFAULT_ARG({
            vmap({
                { u"class"_s, u"xwaylandvideobridge"_s },
            }),
            vmap({
                { u"class"_s, u"jitsi-meet"_s },
                { u"title"_s, u"Screen Sharing Tracker"_s },
            }),
        }))
};

class BarActiveWindow : public settings::ObjectNode {
    CONFIG_NODE(BarActiveWindow, settings::ObjectNode)

    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_PROPERTY(bool, inverted, false)
    CONFIG_PROPERTY(bool, showOnHover, true)
};

class BarWindows : public settings::ObjectNode {
    CONFIG_NODE(BarWindows, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showMinimized, true)
    // Whether each half lists a window per icon or collapses to one icon and a count. Open
    // windows collapse by default: there can be a lot of them, the bar is a vertical sliver, and
    // the popout one hover away is the place to read a list. Minimized ones expand by default for
    // the opposite reasons -- there are rarely more than a few, and seeing at a glance what has
    // been put away is most of the point of putting it away.
    CONFIG_PROPERTY(bool, expandOpen, false)
    CONFIG_PROPERTY(bool, expandMinimized, true)
    // Per half, not in total, and only applies to whichever half is expanded -- so a pile of
    // minimized windows cannot push the open ones off the bar. Everything over the cap is still
    // in the popout; the bar just stops growing. 0 means no cap.
    CONFIG_PROPERTY(int, maxIcons, 8)
    // Icon overrides by window class, same shape as bar.tray.iconSubs: `image` is a path to an
    // image file, `icon` a themed icon name, and the window is matched by `name` (exact) or
    // `regex` the way bar.workspaces.windowIcons matches. Needed because a window's class is not
    // a desktop entry ID and the heuristic that bridges them misses often -- see
    // Icons.getWindowIcon.
    CONFIG_GLOBAL_PROPERTY(QVariantList, iconSubs, {})
    // Where minimized windows are parked. Hyprland has no minimize of its own, so a minimized
    // window is one moved silently onto this special workspace, tagged `minimized:<seq>:<origin>`
    // with the workspace it came from. Nothing ever toggles this workspace into view and the
    // shell filters it out of everywhere it lists special workspaces -- which is why it has to be
    // a workspace nothing else uses. See Hypr.minimize.
    CONFIG_GLOBAL_PROPERTY(QString, minimizeWorkspace, u"special:minimized"_s)
};

class BarTrayIconSub : public settings::ObjectNode {
    CONFIG_NODE(BarTrayIconSub, settings::ObjectNode)

    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(QString, icon, {})
    CONFIG_PROPERTY(QString, image, {})
};
CONFIG_LIST_TYPE(BarTrayIconSub, BarTrayIconSubList)

class BarTray : public settings::ObjectNode {
    CONFIG_NODE(BarTray, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, recolour, false)
    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_GLOBAL_LIST(BarTrayIconSubList, iconSubs, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, hiddenIcons, {})
};

class BarClock : public settings::ObjectNode {
    CONFIG_NODE(BarClock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showDate, false)
    CONFIG_PROPERTY(bool, showIcon, true)
    CONFIG_PROPERTY(bool, showSeconds, false)
};

class BarConfig : public settings::ObjectNode {
    CONFIG_NODE(BarConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, persistent, true)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(int, dragThreshold, 20)
    CONFIG_SUBOBJECT(BarScrollActions, scrollActions)
    CONFIG_SUBOBJECT(BarPopouts, popouts)
    CONFIG_SUBOBJECT(BarWorkspaces, workspaces)
    CONFIG_SUBOBJECT(BarActiveWindow, activeWindow)
    CONFIG_SUBOBJECT(BarWindows, windows)
    CONFIG_SUBOBJECT(BarTray, tray)
    CONFIG_SUBOBJECT(BarClock, clock)
    CONFIG_LIST(EntryList, statusIcons,
        DEFAULT_ARG({
            LIST_ENTRY(lockStatus, true),
            LIST_ENTRY(audio, false),
            LIST_ENTRY(microphone, false),
            LIST_ENTRY(kbLayout, false),
            LIST_ENTRY(network, true),
            LIST_ENTRY(bluetooth, true),
            LIST_ENTRY(battery, true),
        }))
    CONFIG_LIST(EntryList, entries,
        DEFAULT_ARG({
            LIST_ENTRY(logo, true),
            LIST_ENTRY(workspaces, true),
            LIST_ENTRY(spacer, true),
            LIST_ENTRY(activeWindow, true),
            LIST_ENTRY(spacer, true),
            LIST_ENTRY(windows, true),
            LIST_ENTRY(tray, true),
            LIST_ENTRY(clock, true),
            LIST_ENTRY(statusIcons, true),
            LIST_ENTRY(power, true),
        }))
    CONFIG_PROPERTY(QStringList, excludedScreens, {})
};

} // namespace caelestia::config
