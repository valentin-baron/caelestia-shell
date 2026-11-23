pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.services

// Clone of the SDDM greeter (sddm/mirror in the hypr config repo): a wallpaper on every
// screen, one huge centered password pill, the same circular power buttons with their hover
// hints and F10/F11/F12 shortcuts -- and where the greeter picks a session, a line saying the
// session is locked. Controls are transparent, drawn in the inverse of the wallpaper behind
// them (see `ink`), so they read on any picture.
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam
    required property PillScreen pillScreen
    // The greeter's font, from its theme.conf
    readonly property string fontFamily: "CaskaydiaCove Nerd Font Mono"
    // Like the greeter: only the preferred monitor draws the pill; the rest stay plain
    // color. Typing works from any monitor -- every surface feeds the shared pam buffer.
    readonly property bool drawsPill: !pillScreen.name || pillScreen.name === (screen?.name ?? "")
    // The pill screen shows a random wallswipe download (picked per lock, never one a screen
    // is already showing).
    readonly property string randomWall: {
        const showing = Quickshell.screens.map(q => Wallpapers.forScreen(q.name));
        const pool = Wallpapers.list.filter(w => /^(wallhaven|unsplash|pexels)-/.test(w.name) && !showing.includes(w.path));
        return pool.length ? pool[Math.floor(Math.random() * pool.length)].path : Wallpapers.forScreen(screen?.name ?? "");
    }
    function translucent(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Average wallpaper colour behind the pill, the status line and the power row, sampled
    // by `probe` once the picture is up; black (so white controls) until then.
    property color pillBehind: "black"
    property color textBehind: "black"
    property color cornerBehind: "black"
    readonly property color pillInk: ink(pillBehind)
    readonly property color textInk: ink(textBehind)
    readonly property color cornerInk: ink(cornerBehind)
    readonly property color errorInk: "#ff4d5e"

    // The inverse of the colour behind, pushed most of the way to white or black (whichever
    // is further from that colour) -- a plain inverse of a mid-grey is mid-grey.
    function ink(behind: color): color {
        const light = 0.2126 * behind.r + 0.7152 * behind.g + 0.0722 * behind.b > 0.5;
        const to = light ? 0 : 1;
        const mix = c => (1 - c) * 0.35 + to * 0.65;
        return Qt.rgba(mix(behind.r), mix(behind.g), mix(behind.b), 1);
    }

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    color: "black"

    Connections {
        // The greeter has no animations (the hyprlock version disabled its own to match),
        // so unlock instantly rather than playing anything.
        function onUnlock(): void {
            root.lock.locked = false;
        }

        target: root.lock
    }

    // Every screen shows a wallpaper (the greeter does the same via sddm/mirror/backgrounds):
    // side screens the one the slideshow gave them, the pill screen a random one. Black shows
    // only until the image has loaded.
    Image {
        id: wall

        anchors.fill: parent
        visible: status === Image.Ready
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        source: {
            const path = root.drawsPill ? root.randomWall : Wallpapers.forScreen(root.screen?.name ?? "");
            return path ? "file://" + path : "";
        }
        onStatusChanged: {
            if (status === Image.Ready && root.drawsPill)
                grabber.start();
        }
    }

    // Samples the displayed wallpaper (crop included): grabs it shrunk to 32x18, then
    // averages the regions the controls sit on. The grab is refused until the surface is
    // mapped, hence the retry; and Canvas can't open a grab's own itemgrabber: URL (nor draw
    // an Image item -- comes out black), hence the round trip through a file.
    Timer {
        id: grabber

        interval: 200
        repeat: true
        onTriggered: {
            const ok = wall.grabToImage(r => {
                const file = `${Quickshell.env("XDG_RUNTIME_DIR")}/lock-probe-${root.screen?.name ?? "x"}.png`;
                if (r.saveToFile(file))
                    probe.load("file://" + file);
            }, Qt.size(probe.width, probe.height));
            if (ok)
                stop();
        }
    }

    // Has to stay in the scene to paint, hence opacity rather than visible.
    Canvas {
        id: probe

        property url grabbed

        function load(url: url): void {
            if (grabbed === url)
                unloadImage(url);
            grabbed = url;
            loadImage(url);
        }

        function average(x: int, y: int, w: int, h: int): color {
            const d = getContext("2d").getImageData(x, y, w, h).data;
            let r = 0, g = 0, b = 0;
            for (let i = 0; i < d.length; i += 4) {
                r += d[i];
                g += d[i + 1];
                b += d[i + 2];
            }
            const n = d.length / 4 * 255;
            return Qt.rgba(r / n, g / n, b / n, 1);
        }

        width: 32
        height: 18
        opacity: 0
        onImageLoaded: requestPaint()
        onPaint: {
            if (!isImageLoaded(grabbed))
                return;
            getContext("2d").drawImage(grabbed, 0, 0, width, height);
            root.pillBehind = average(8, 7, 16, 5);
            root.textBehind = average(12, 16, 8, 2);
            root.cornerBehind = average(26, 15, 6, 3);
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        onActiveFocusChanged: {
            if (!activeFocus)
                forceActiveFocus();
        }
        // The greeter's power shortcuts first (its exact key mapping), everything else
        // feeds the password buffer.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F10)
                Quickshell.execDetached(["systemctl", "suspend"]);
            else if (event.key === Qt.Key_F11)
                Quickshell.execDetached(["systemctl", "poweroff"]);
            else if (event.key === Qt.Key_F12)
                Quickshell.execDetached(["systemctl", "reboot"]);
            else
                root.pam.handleKey(event);
        }
    }

    Rectangle {
        id: pill

        // Geometry copied from the greeter's theme.conf: passwordInputWidth=0.5 -> half the
        // display, 200px tall at the theme's 96pt font, inputRadius 80, inputBorderWidth 4.
        anchors.centerIn: parent
        width: Math.round(parent.width / 2)
        height: 200
        radius: 80
        visible: root.drawsPill

        color: "transparent"
        border.width: 4
        // The greeter signals failure with the border only, and keeps it unchanged while
        // the attempt is being checked.
        border.color: root.pam.state === Pam.None ? root.pillInk : root.errorInk

        Behavior on border.color {
            ColorAnimation {
                duration: 250
            }
        }

        Row {
            id: dots

            // Approximates the theme's 96pt bold '*' mask, like the hyprlock field did:
            // 50px dots at 0.35 spacing.
            readonly property int dotSize: 50
            readonly property int maxDots: Math.max(1, Math.floor((pill.width - pill.radius * 2) / (dotSize + spacing)))

            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: Math.min(root.pam.buffer.length, dots.maxDots)

                Rectangle {
                    width: dots.dotSize
                    height: dots.dotSize
                    radius: dots.dotSize / 2
                    color: root.pillInk

                    Behavior on color {
                        ColorAnimation {
                            duration: 250
                        }
                    }
                }
            }
        }
    }

    // The greeter's power row: same corner, margins, glyphs, and hover hints.
    Row {
        visible: root.drawsPill
        spacing: 24
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 48
        anchors.bottomMargin: 44

        GreeterButton {
            glyph: "⏾"
            tip: "Suspend · F10"
            action: () => Quickshell.execDetached(["systemctl", "suspend"])
        }
        GreeterButton {
            glyph: ""
            tip: "Reboot · F12"
            action: () => Quickshell.execDetached(["systemctl", "reboot"])
        }
        GreeterButton {
            glyph: "⏻"
            tip: "Shut down · F11"
            action: () => Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }

    // Where the greeter has its session picker: there is nothing to pick on a running
    // session, so the same spot says what this screen is instead.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        visible: root.drawsPill

        text: "Hyprland is locked"
        color: root.textInk
        font.family: root.fontFamily
        font.pointSize: 14

        Behavior on color {
            ColorAnimation {
                duration: 250
            }
        }
    }

    // The greeter shows no failure text, but PAM's account-lockout notice is worth
    // surfacing -- without it a locked account looks like a broken password.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 280
        visible: root.drawsPill && text !== ""

        text: root.pam.lockMessage
        color: root.pillInk
        font.family: root.fontFamily
        font.pointSize: 14
        horizontalAlignment: Text.AlignHCenter
    }

    // The greeter's Bubble and PowerButton (sddm/mirror/Main.qml), cloned 1:1 -- change one,
    // change both. The only additions are the color Behaviors, so the buttons fade to their
    // colour once the wallpaper has been sampled.
    component Bubble: Rectangle {
        property alias label: bubbleText.text

        implicitWidth: bubbleText.implicitWidth + 28
        implicitHeight: bubbleText.implicitHeight + 14
        radius: height / 2
        color: root.translucent(root.cornerBehind, 0.85)
        border.width: 1
        border.color: root.cornerInk

        Text {
            id: bubbleText

            anchors.centerIn: parent
            color: root.cornerInk
            font.family: root.fontFamily
            font.pointSize: 12
        }
    }

    component GreeterButton: Item {
        id: btn

        property string glyph
        property string tip
        property var action

        width: 64
        height: 64

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.translucent(root.cornerInk, btnMouse.containsMouse ? 0.2 : 0)
            border.width: 2
            border.color: root.cornerInk

            Behavior on color {
                ColorAnimation {
                    duration: 250
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 250
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: root.cornerInk
            font.family: root.fontFamily
            font.pointSize: 22

            Behavior on color {
                ColorAnimation {
                    duration: 250
                }
            }
        }

        MouseArea {
            id: btnMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.action()
        }

        Bubble {
            label: btn.tip
            visible: btnMouse.containsMouse
            anchors.bottom: parent.top
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
