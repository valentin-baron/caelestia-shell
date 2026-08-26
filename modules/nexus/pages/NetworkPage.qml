pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Network")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            interval: GlobalConfig.nexus.networkRescanInterval
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        Loader {
            Layout.fillWidth: true
            active: Nmcli.hasAvailableEthernet
            visible: active
            asynchronous: true

            sourceComponent: EthernetSection {
                nState: root.nState
                cappedWidth: root.cappedWidth
            }
        }

        ToggleRow {
            Layout.topMargin: Nmcli.hasAvailableEthernet ? Tokens.spacing.large : 0
            first: true
            text: qsTr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        NetworkList {
            Layout.bottomMargin: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? 0 : -parent.spacing
            nState: root.nState
            limit: GlobalConfig.nexus.maxNetworksShown

            Behavior on Layout.bottomMargin {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // All networks button, only when > max networks
        RowButton {
            Layout.preferredHeight: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? implicitHeight : 0
            clip: true

            icon: "expand_content"
            text: qsTr("Show all networks (%1)").arg(Nmcli.networks.length)
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(5) // All networks sub-page

            Behavior on Layout.preferredHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Saved networks button
        RowButton {
            icon: "bookmark"
            text: qsTr("Saved networks")
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(6) // Saved networks sub-page
        }

        RowButton {
            last: true
            icon: "add"
            text: qsTr("Add network")
            disabled: !Nmcli.wifiEnabled
            onClicked: root.nState.openSubPage(2) // Add network sub-page
        }

        // ---- VPN connections (NetworkManager profiles) -------------------------
        // Imported VPN configs (wg-quick/OpenVPN profiles known to nmcli), listed
        // like the Wi-Fi networks above with tap-to-connect. Distinct from the
        // provider section below, which drives external daemons (Tailscale etc.).
        ConnectedRect {
            Layout.topMargin: Tokens.spacing.large
            Layout.fillWidth: true
            first: true
            implicitHeight: vpnConnHeader.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: vpnConnHeader

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("VPN connections")
                    font: Tokens.font.body.medium
                }

                StyledText {
                    text: Nmcli.activeVpn ? qsTr("Connected to %1").arg(Nmcli.activeVpn.name) : qsTr("Not connected")
                    color: Nmcli.activeVpn ? Colours.palette.m3primary : Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                    animate: true
                }
            }
        }

        ItemList {
            id: vpnConnList

            last: true
            showList: true
            placeholderIcon: "vpn_key_off"
            placeholderText: qsTr("No VPN connections configured")

            model: ScriptModel {
                values: [...Nmcli.vpnConnections].sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name))
            }

            delegate: StateLayer {
                id: vpnConn

                required property int index
                required property var modelData
                readonly property bool isConnecting: Nmcli.connectingVpnUuid === modelData.uuid
                readonly property string typeLabel: modelData.type === "wireguard" ? "WireGuard" : qsTr("VPN")
                property real textOpacity: disabled ? 0.5 : 1

                disabled: isConnecting

                anchors.left: vpnConnList.list.contentItem.left
                anchors.right: vpnConnList.list.contentItem.right
                anchors.fill: undefined
                implicitHeight: vpnConnLayout.implicitHeight + vpnConnLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                bottomLeftRadius: index === vpnConnList.list.count - 1 ? Tokens.rounding.extraLarge : radius
                bottomRightRadius: index === vpnConnList.list.count - 1 ? Tokens.rounding.extraLarge : radius

                onClicked: {
                    if (modelData.active) {
                        Nmcli.deactivateVpn(modelData.uuid, result => {
                            if (!result.success)
                                Toaster.toast(qsTr("VPN disconnection failed"), result.error.trim() || qsTr("Could not deactivate %1").arg(vpnConn.modelData.name), "vpn_key_alert", Toast.Error);
                        });
                    } else {
                        Nmcli.activateVpn(modelData.uuid, result => {
                            if (!result.success)
                                Toaster.toast(qsTr("VPN connection failed"), result.error.trim() || qsTr("Could not activate %1").arg(vpnConn.modelData.name), "vpn_key_alert", Toast.Error);
                        });
                    }
                }

                Behavior on textOpacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                RowLayout {
                    id: vpnConnLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: vpnConn.modelData.active ? "vpn_key" : "vpn_key_off"
                        fill: vpnConn.modelData.active ? 1 : 0
                        color: vpnConn.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        opacity: vpnConn.textOpacity
                        animate: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: vpnConn.textOpacity

                        StyledText {
                            Layout.fillWidth: true
                            text: vpnConn.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (vpnConn.isConnecting)
                                    return qsTr("%1 • Connecting...").arg(vpnConn.typeLabel);
                                if (vpnConn.modelData.active)
                                    return vpnConn.modelData.device.length > 0 ? qsTr("%1 • Connected (%2)").arg(vpnConn.typeLabel).arg(vpnConn.modelData.device) : qsTr("%1 • Connected").arg(vpnConn.typeLabel);
                                return qsTr("%1 • Tap to connect").arg(vpnConn.typeLabel);
                            }
                            color: vpnConn.modelData.active ? Colours.palette.m3primary : Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            animate: true
                        }
                    }

                    AnimLoader {
                        sourceComp: vpnConn.isConnecting ? vpnLoadingComp : vpnIconComp

                        Component {
                            id: vpnIconComp

                            MaterialIcon {
                                text: vpnConn.modelData.active ? "link_off" : "link"
                                color: vpnConn.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.medium
                                opacity: vpnConn.textOpacity
                            }
                        }

                        Component {
                            id: vpnLoadingComp

                            LoadingIndicator {
                                implicitSize: Math.round(Tokens.font.icon.medium.pointSize * 1.3)
                            }
                        }
                    }
                }
            }
        }

        // ---- VPN providers -----------------------------------------------------
        ToggleRow {
            Layout.topMargin: Tokens.spacing.large
            Layout.fillWidth: true
            first: true
            text: qsTr("VPN providers")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: VPN.connected
            // Connectable as long as there's a provider and we're not mid-switch.
            disabled: VPN.connecting || VPN.disconnecting || VPN.providers.length === 0
            onToggled: VPN.toggle()

            Timer {
                running: root.visible
                repeat: true
                triggeredOnStart: true
                interval: 5000
                onTriggered: {
                    VPN.checkStatus();
                    if (VPN.connected)
                        VPN.refreshStats();
                }
            }
        }

        ItemList {
            id: providerList

            showList: true
            placeholderIcon: "add_circle"
            placeholderText: qsTr("No VPN providers configured")

            model: ScriptModel {
                values: [...VPN.providers]
            }

            delegate: Item {
                id: provider

                required property var modelData // QML types are annoying (causes null errors on destruction if typed correctly)
                readonly property bool isSelected: modelData.providerId === VPN.selectedProvider
                readonly property bool isConnected: isSelected && VPN.connected

                anchors.left: providerList.list.contentItem.left
                anchors.right: providerList.list.contentItem.right
                implicitHeight: providerLayout.implicitHeight + providerLayout.anchors.margins * 2

                StateLayer {
                    disabled: provider.isSelected
                    radius: Tokens.rounding.extraSmall
                    onClicked: {
                        if (!provider.isSelected)
                            VPN.setActiveProvider(provider.modelData.index);
                    }
                }

                RowLayout {
                    id: providerLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: providerIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: provider.isConnected ? Colours.palette.m3primaryContainer : provider.isSelected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest

                        MaterialIcon {
                            id: providerIcon

                            anchors.centerIn: parent
                            text: provider.isConnected || provider.isSelected ? "vpn_key" : "vpn_key_off"
                            fill: provider.isConnected ? 1 : 0
                            color: provider.isConnected ? Colours.palette.m3onPrimaryContainer : provider.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                            animate: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: provider.modelData.displayName
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (!provider.isSelected)
                                    return qsTr("Tap to select");
                                if (VPN.connecting)
                                    return qsTr("Connecting...");
                                if (VPN.disconnecting)
                                    return qsTr("Disconnecting...");
                                switch (VPN.status.state) {
                                case "connected":
                                    return qsTr("Connected");
                                case "needs-auth":
                                    return VPN.status.reason || qsTr("Authentication required");
                                case "error":
                                    return VPN.status.reason || qsTr("An error occurred");
                                default:
                                    return qsTr("Selected");
                                }
                            }
                            color: {
                                if (!provider.isSelected)
                                    return Colours.palette.m3onSurfaceVariant;
                                switch (VPN.status.state) {
                                case "connected":
                                    return Colours.palette.m3primary;
                                case "needs-auth":
                                case "error":
                                    return Colours.palette.m3error;
                                default:
                                    return Colours.palette.m3secondary;
                                }
                            }
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            animate: true
                        }
                    }

                    Item {
                        Layout.rightMargin: Tokens.spacing.small
                        opacity: provider.isConnected && root?.cappedWidth > Tokens.sizes.nexus.networkShowVpnDetailWidth ? 1 : 0
                        visible: opacity > 0

                        implicitWidth: provider.isConnected && root?.cappedWidth > Tokens.sizes.nexus.networkShowVpnDetailWidth ? providerDetailRow.implicitWidth : 0
                        implicitHeight: providerDetailRow.implicitHeight

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        RowLayout {
                            id: providerDetailRow

                            anchors.right: parent.right
                            spacing: Tokens.spacing.large

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: qsTr("Interface")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: provider.modelData.iface
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: qsTr("Current Ping")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: Tokens.spacing.small

                                    StyledRect {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: Math.round(Tokens.font.body.small.pointSize * 0.7)
                                        implicitHeight: implicitWidth
                                        radius: Tokens.rounding.full
                                        color: VPN.pingMs <= 80 ? Colours.palette.m3primary : VPN.pingMs <= 150 ? Colours.palette.m3tertiary : Colours.palette.m3error
                                    }

                                    StyledText {
                                        text: qsTr("%1 ms").arg(VPN.pingMs)
                                        color: Colours.palette.m3outline
                                        font: Tokens.font.label.small
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    IconButton {
                        implicitWidth: implicitHeight + (Tokens.padding.large - padding) * 2
                        type: IconButton.Tonal
                        isRound: true
                        icon: "edit"
                        onClicked: {
                            root.nState.editingVpnIndex = provider.modelData.index;
                            root.nState.openSubPage(4); // Add/edit provider sub-page
                        }
                    }
                }
            }
        }

        // Add provider
        RowButton {
            last: true
            icon: "add"
            text: qsTr("Add provider")
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.openSubPage(4); // Add/edit provider sub-page
            }
        }
    }
}
