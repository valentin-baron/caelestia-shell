pragma ComponentBehavior: Bound

import QtQuick
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property real maxHeight

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight + padding * 2

    AppGrid {
        id: grid

        screenState: root.screenState

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding

        implicitHeight: Math.min(contentHeight, root.maxHeight - root.padding * 2)
    }
}
