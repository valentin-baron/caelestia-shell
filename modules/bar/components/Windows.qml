pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

// The window strip: open windows above, minimized ones below, the tray entry under both.
//
// The open half is one icon and a count by default rather than an icon per window. The bar is a
// vertical sliver shared with the workspaces, the clock and the tray, and a dozen windows listed
// here would push all of that off the screen -- the popout a hover away is where a list belongs.
// The minimized half expands instead, because there are rarely more than a few and seeing what
// has been put away is most of the reason for putting it away. Both are bar.windows.expand*.
StyledRect {
    id: root

    readonly property alias layout: layout

    readonly property var openWindows: Hypr.shownToplevels
    readonly property var minimizedWindows: Config.bar.windows.showMinimized ? Hypr.minimizedToplevels : []

    // Only whichever half is expanded can overflow; a collapsed half shows its full count.
    readonly property var openIcons: Config.bar.windows.expandOpen ? cap(root.openWindows) : []
    readonly property var minimizedIcons: Config.bar.windows.expandMinimized ? cap(root.minimizedWindows) : []
    readonly property int hiddenCount: (openIcons.length > 0 ? root.openWindows.length - openIcons.length : 0) + (minimizedIcons.length > 0 ? root.minimizedWindows.length - minimizedIcons.length : 0)

    readonly property bool hasOpen: root.openWindows.length > 0
    readonly property bool hasMinimized: root.minimizedWindows.length > 0

    readonly property int padding: Config.bar.windows.background ? Tokens.padding.medium : Tokens.padding.extraSmall

    function cap(toplevels: var): var {
        const max = Config.bar.windows.maxIcons;
        return max > 0 ? toplevels.slice(0, max) : toplevels;
    }

    clip: true

    // Gated on the model, never on the geometry. `visible: height > 0` with an implicitHeight
    // measured from the children is a deadlock: an invisible parent makes every child invisible,
    // a positioner does not measure invisible children, so the Column reports 0, which keeps the
    // height at 0 and the strip invisible forever. It only ever appeared to work because the
    // repeater delegates were created while the root was still visible by default, and the
    // collapsed layout has no delegates to win that race.
    visible: hasOpen || hasMinimized

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.windows.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Column {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.padding
        spacing: Tokens.spacing.small

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.openIcons
            }

            WindowIcon {}
        }

        Summary {
            visible: !Config.bar.windows.expandOpen && root.hasOpen
            glyph: "web_asset"
            count: root.openWindows.length
        }

        // Two dividers, not one: the strip is three compartments -- open, minimized, tray -- and
        // the tray is a bar entry of its own, so the only place its boundary can be drawn from is
        // the bottom edge of this one.
        Divider {
            visible: root.hasOpen && root.hasMinimized
        }

        Repeater {
            model: ScriptModel {
                values: root.minimizedIcons
            }

            WindowIcon {
                minimized: true
            }
        }

        Summary {
            visible: !Config.bar.windows.expandMinimized && root.hasMinimized
            glyph: "minimize"
            count: root.minimizedWindows.length
            dim: true
        }

        // Says "there are more, hover me" rather than letting the cap quietly swallow windows.
        Item {
            visible: root.hiddenCount > 0

            implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
            implicitHeight: overflowIcon.implicitHeight

            MaterialIcon {
                id: overflowIcon

                anchors.centerIn: parent

                text: "more_horiz"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }
        }

        Divider {
            visible: root.hasOpen || root.hasMinimized
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    // Every direct child of `layout` is an un-anchored Item of the same width, and does its own
    // centring inside. A Column skips any child that uses anchors -- it is not just ignored for
    // positioning, it stops counting towards the Column's implicit height -- so anchoring these to
    // the Column collapsed the whole strip to nothing the moment the icons stopped being what
    // filled it.
    component Divider: Item {
        implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
        implicitHeight: Math.max(1, Tokens.sizes.bar.innerWidth / 24)

        StyledRect {
            anchors.centerIn: parent

            implicitWidth: Tokens.sizes.bar.innerWidth / 2
            implicitHeight: parent.implicitHeight

            color: Colours.palette.m3outlineVariant
            radius: Tokens.rounding.full
        }
    }

    // A whole half in one icon: a glyph saying which half, and how many are in it. No click
    // handler -- hovering is what opens the popout, and the popout is where anything you would
    // want to click on an individual window lives.
    component Summary: Item {
        id: summary

        required property string glyph
        required property int count
        property bool dim

        implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
        implicitHeight: summaryGlyph.implicitHeight + summaryCount.implicitHeight

        opacity: dim ? 0.55 : 1

        MaterialIcon {
            id: summaryGlyph

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            text: summary.glyph
            color: Colours.palette.m3onSurface
        }

        StyledText {
            id: summaryCount

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            animate: true
            text: summary.count
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }
    }

    component WindowIcon: MouseArea {
        id: windowIcon

        required property var modelData
        property bool minimized

        readonly property bool isActive: !minimized && modelData?.address !== undefined && modelData.address === Hypr.activeToplevel?.address
        readonly property string windowClass: modelData?.lastIpcObject.class ?? ""

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
        implicitHeight: implicitWidth

        // Right-click toggles rather than opening a menu: the popout right next to this one is
        // where anything needing a label lives, and a context menu on a 20px icon in a bar that
        // hides itself is a target nobody hits twice.
        onClicked: event => {
            if (event.button === Qt.LeftButton)
                Hypr.focusToplevel(modelData);
            else
                Hypr.toggleMinimize(modelData);
        }

        // Same reasoning as the workspace window icons: dim the rest rather than recolour the
        // active one. These are real app icons, so a palette colour would not read on them at all
        // -- but a minimized window still has to look put away, and opacity is the one thing that
        // says so whatever the icon turns out to be. Applied to the pair, so the glyph fallback
        // dims identically.
        Item {
            anchors.fill: parent

            opacity: windowIcon.minimized ? 0.35 : windowIcon.isActive ? 1 : 0.6

            CachingIconImage {
                id: icon

                anchors.fill: parent
                visible: status === Image.Ready
                source: Icons.getWindowIcon(windowIcon.windowClass)
            }

            // Not every window has a desktop entry behind it, and an icon name missing from the
            // current theme draws nothing rather than falling back to anything. The category
            // glyph comes out of the bundled symbol font, so it always renders -- and it reads
            // bar.workspaces.windowIcons, which is already where the steam_app_<id> rule lives.
            MaterialIcon {
                anchors.centerIn: parent

                visible: !icon.visible
                text: Icons.getAppCategoryIcon(windowIcon.windowClass, "web_asset")
                color: Colours.palette.m3onSurface
            }

            Behavior on opacity {
                Anim {}
            }
        }
    }
}
