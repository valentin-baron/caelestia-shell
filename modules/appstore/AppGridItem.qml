pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property ScreenState screenState

    implicitWidth: GridView.view.cellWidth
    implicitHeight: GridView.view.cellHeight

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: {
            Apps.launch(root.modelData);
            root.screenState.appstore = false;
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Tokens.spacing.small
        width: parent.width - Tokens.padding.medium * 2

        IconImage {
            id: icon

            anchors.horizontalCenter: parent.horizontalCenter
            asynchronous: true
            source: Quickshell.iconPath(root.modelData?.icon, "image-missing")
            implicitSize: 48
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.modelData?.name ?? ""
            font: Tokens.font.body.medium
        }
    }
}
