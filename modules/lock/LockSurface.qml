pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config

// Clone of the SDDM greeter (sddm/mirror in the hypr config repo): flat background, one huge
// centered password pill, the same circular power buttons with their hover hints and
// F10/F11/F12 shortcuts -- and where the greeter picks a session, a line saying the session
// is locked. The one extra the greeter lacks is the palette button under the pill (same
// button style), cycling live through the combos Palettes.qml carries (or the lock IPC
// target's cyclePalette). Unlike the hyprlock version this replaced, a swap is just a
// property change: everything recolors in place, no process restart.
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam
    required property Palettes palettes

    readonly property var pal: palettes.current
    // The greeter's font, from its theme.conf
    readonly property string fontFamily: "CaskaydiaCove Nerd Font Mono"
    // Like the greeter: only the preferred monitor draws the pill; the rest stay plain
    // color. Typing works from any monitor -- every surface feeds the shared pam buffer.
    readonly property bool drawsPill: !palettes.pillScreen || palettes.pillScreen === (screen?.name ?? "")

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    color: pal.background

    Connections {
        // The greeter has no animations (the hyprlock version disabled its own to match),
        // so unlock instantly rather than playing anything.
        function onUnlock(): void {
            root.lock.locked = false;
        }

        target: root.lock
    }

    Rectangle {
        anchors.fill: parent
        color: root.pal.background

        Behavior on color {
            ColorAnimation {
                duration: 250
            }
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

        color: root.pal.inputBackground
        border.width: 4
        // The greeter signals failure with the border only, and keeps it unchanged while
        // the attempt is being checked.
        border.color: root.pam.state === Pam.None ? root.pal.inputBorder : root.pal.errorBorder

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
                    color: root.pal.inputText

                    Behavior on color {
                        ColorAnimation {
                            duration: 250
                        }
                    }
                }
            }
        }
    }

    // Palette button: steps to the next palette combo. The greeter has no such button;
    // this one wears the same circle as its power buttons so nothing looks foreign.
    GreeterButton {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 180
        visible: root.drawsPill

        glyph: "󰏘"
        tip: "Palette · Super + Pause"
        action: () => root.palettes.cycle()
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
            glyph: ""
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
        color: root.pal.mutedText
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
        color: root.pal.mutedText
        font.family: root.fontFamily
        font.pointSize: 14
        horizontalAlignment: Text.AlignHCenter
    }

    // The greeter's Bubble and PowerButton (sddm/mirror/Main.qml), cloned 1:1 -- change one,
    // change both. The only additions are the color Behaviors, so the buttons recolor with
    // the rest of the surface when the palette swaps.
    component Bubble: Rectangle {
        property alias label: bubbleText.text

        implicitWidth: bubbleText.implicitWidth + 28
        implicitHeight: bubbleText.implicitHeight + 14
        radius: height / 2
        color: root.pal.inputBackground
        border.width: 1
        border.color: root.pal.inputBorder

        Text {
            id: bubbleText

            anchors.centerIn: parent
            color: root.pal.inputText
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
            color: btnMouse.containsMouse ? root.pal.inputBackground : "transparent"
            border.width: 2
            border.color: btnMouse.containsMouse ? root.pal.inputBorder : root.pal.mutedText

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
            color: btnMouse.containsMouse ? root.pal.inputText : root.pal.mutedText
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
