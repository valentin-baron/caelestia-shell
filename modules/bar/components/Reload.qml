import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    StateLayer {
        // Match Power.qml: make the hit area a touch larger than the icon
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: Quickshell.reload(true)
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: "refresh"
        color: Colours.palette.m3tertiary
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }
}
