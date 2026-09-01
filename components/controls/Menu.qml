pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.drawers

MouseArea {
    id: root

    enum Side {
        Top,
        Bottom,
        Left,
        Right
    }

    required property Item attachTo
    property int attachSideX: Menu.Right
    property int attachSideY: Menu.Bottom
    property int thisSideX: Menu.Right
    property int thisSideY: Menu.Top
    property real marginX
    property real marginY

    property list<MenuItem> items
    property MenuItem active: items[0] ?? null
    property bool expanded

    signal itemSelected(item: MenuItem)

    parent: {
        const win = QsWindow.window;
        const contentWin = win as ContentWindow; // If inside the drawer content window, put it inside the interaction wrapper so hover works
        return contentWin ? contentWin.interactionWrapper : (win as QsWindow).contentItem;
    }
    anchors.fill: parent

    enabled: expanded
    hoverEnabled: expanded
    cursorShape: expanded ? Qt.ArrowCursor : undefined
    onClicked: expanded = false

    opacity: expanded ? 1 : 0
    layer.enabled: opacity < 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    TransformWatcher {
        id: watcher

        a: root.parent
        b: root.attachTo
    }

    Elevation {
        id: menu

        x: {
            watcher.transform; // mapToItem is not reactive so this forces updates
            const item = root.attachTo;
            let off = root.attachSideX === Menu.Left ? 0 : item.width;
            if (root.thisSideX === Menu.Right)
                off -= width;
            return item.mapToItem(root.parent, off, 0).x + root.marginX;
        }
        y: {
            watcher.transform; // mapToItem is not reactive so this forces updates
            const item = root.attachTo;
            let off = root.attachSideY === Menu.Top ? 0 : item.height;
            if (root.thisSideY === Menu.Bottom)
                off -= height;
            return item.mapToItem(root.parent, 0, off).y + root.marginY;
        }

        radius: Tokens.rounding.large
        level: 2

        // How much vertical space is actually free between the attach point and the window edge
        // the menu opens toward, so a long list gets an internal scrollbar instead of being
        // silently clipped by the window bounds (this popup can't render outside them).
        readonly property real maxAvailableHeight: {
            watcher.transform;
            const item = root.attachTo;
            if (!item || !root.parent)
                return Infinity;
            const buffer = Tokens.padding.large;
            const attachOff = root.attachSideY === Menu.Top ? 0 : item.height;
            const anchorY = item.mapToItem(root.parent, 0, attachOff).y + root.marginY;
            return Math.max(120, root.thisSideY === Menu.Bottom ? anchorY - buffer : root.parent.height - anchorY - buffer);
        }

        implicitWidth: Math.max(200, column.implicitWidth + Tokens.padding.extraSmall * 2)
        implicitHeight: Math.min(column.implicitHeight + Tokens.padding.extraSmall * 2, maxAvailableHeight)

        transform: Scale {
            yScale: root.expanded ? 1 : 0.1
            origin.y: root.thisSideY === Menu.Bottom ? menu.height : 0

            Behavior on yScale {
                Anim {}
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onWheel: e => e.accepted = true
        }

        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3surfaceContainerLow

            StyledFlickable {
                id: flick

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall

                contentWidth: width
                contentHeight: column.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: flick
                }

                ColumnLayout {
                    id: column

                    width: flick.width
                    spacing: 0

                    Repeater {
                        id: repeater

                        model: root.items

                        StyledRect {
                            id: item

                            required property int index
                            required property MenuItem modelData
                            readonly property bool active: modelData === root?.active

                            Layout.fillWidth: true
                            implicitWidth: menuOptionRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: menuOptionRow.implicitHeight + Tokens.padding.medium * 2

                            radius: active ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                            topLeftRadius: index === 0 ? Tokens.rounding.medium : radius
                            topRightRadius: index === 0 ? Tokens.rounding.medium : radius
                            bottomLeftRadius: index === repeater?.count - 1 ? Tokens.rounding.medium : radius
                            bottomRightRadius: index === repeater?.count - 1 ? Tokens.rounding.medium : radius

                            color: Qt.alpha(Colours.palette.m3tertiaryContainer, active ? 1 : 0)

                            Behavior on radius {
                                Anim {}
                            }

                            StateLayer {
                                topLeftRadius: parent.topLeftRadius
                                topRightRadius: parent.topRightRadius
                                bottomLeftRadius: parent.bottomLeftRadius
                                bottomRightRadius: parent.bottomRightRadius

                                color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                disabled: !root.expanded
                                onClicked: {
                                    root.itemSelected(item.modelData);
                                    root.active = item.modelData;
                                    item.modelData.clicked();
                                    root.expanded = false;
                                }
                            }

                            RowLayout {
                                id: menuOptionRow

                                anchors.fill: parent
                                anchors.margins: Tokens.padding.medium
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: item.modelData?.icon ?? ""
                                    color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: item.modelData?.text ?? ""
                                    color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                }

                                Loader {
                                    asynchronous: true
                                    Layout.alignment: Qt.AlignVCenter
                                    active: item.modelData?.trailingIcon.length > 0
                                    visible: active

                                    sourceComponent: MaterialIcon {
                                        text: item.modelData.trailingIcon
                                        color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
