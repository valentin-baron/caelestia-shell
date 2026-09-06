pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState

    readonly property bool shouldBeActive: screenState.appstore

    readonly property real maxHeight: screen.height * 0.7 - Config.border.thickness * 2

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => content.implicitHeight);
        else
            implicitHeight = implicitHeight; // Break binding during close anim
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            maxHeight: root.maxHeight
        }
    }
}
