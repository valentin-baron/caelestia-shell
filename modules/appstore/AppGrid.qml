pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.components.controls
import qs.modules.launcher.services

GridView {
    id: root

    required property ScreenState screenState

    readonly property int tileSize: 110

    cellWidth: tileSize
    cellHeight: tileSize + 30

    clip: true

    Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init

    model: Apps.list

    delegate: AppGridItem {
        screenState: root.screenState
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }
}
