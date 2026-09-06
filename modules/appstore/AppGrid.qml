pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

    // Apps.list (appDb.apps) holds AppDb's wrapper objects, not DesktopEntry -- Apps.search()
    // unwraps them (.map(e => e.entry)), same call the launcher itself makes for its unfiltered
    // "apps" results. That order is frequency/favourite-driven (AppDb), so sort alphabetically
    // for the grid instead.
    model: ScriptModel {
        values: Apps.search("").sort((a, b) => a.name.localeCompare(b.name))
    }

    delegate: AppGridItem {
        screenState: root.screenState
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }
}
