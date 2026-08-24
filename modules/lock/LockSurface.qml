pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import Caelestia.Config
import qs.components

// Clone of the SDDM greeter (sddm/mirror in the hypr config repo): flat background, one huge
// centered password pill, plus two extras the greeter lacks -- a palette button under the
// pill, and live cycling through the greeter's own theme.conf combos (the button, or the
// lock IPC target's cyclePalette). Unlike the hyprlock version this replaced, a swap is just
// a property change: everything recolors in place, no process restart.
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam
    required property Palettes palettes

    readonly property var pal: palettes.current
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
        Keys.onPressed: event => root.pam.handleKey(event)
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

    // Palette button: steps to the next theme.conf combo. Positioned like the hyprlock
    // label it replaces: 100px of pill below center + 80px gap.
    MaterialIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 180
        visible: root.drawsPill

        text: "palette"
        color: root.pal.mutedText
        fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.5).build()

        Behavior on color {
            ColorAnimation {
                duration: 250
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: root.palettes.cycle()
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
        font.family: "CaskaydiaCove Nerd Font Mono"
        font.pointSize: 14
        horizontalAlignment: Text.AlignHCenter
    }
}
