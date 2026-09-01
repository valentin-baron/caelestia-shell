pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Video")

    property bool previewOn: false

    property var deviceItems: []
    property var deviceByLabel: ({})
    property var activeDeviceItem: null

    property var resolutionItems: []
    property var resByLabel: ({})
    property var activeResolutionItem: null

    property var frameRateItems: []
    property var formatByLabel: ({})
    property var activeFrameRateItem: null

    function makeItem(text, trailingIcon) {
        return menuItemComp.createObject(root, {
            text: text,
            trailingIcon: trailingIcon ?? ""
        });
    }

    // Distinct rounded max frame rates available for a given resolution, across all pixel formats.
    function fpsCountForResolution(formats, width, height) {
        const seen = {};
        let count = 0;
        for (const f of formats) {
            if (f.resolution.width !== width || f.resolution.height !== height)
                continue;
            const fps = Math.round(f.maxFrameRate);
            if (seen[fps])
                continue;
            seen[fps] = true;
            count++;
        }
        return count;
    }

    function destroyItems(items) {
        for (const i of items)
            i.destroy();
    }

    function currentDevice() {
        return root.activeDeviceItem ? root.deviceByLabel[root.activeDeviceItem.text] : mediaDevices.defaultVideoInput;
    }

    function rebuildDeviceItems() {
        const oldItems = root.deviceItems;
        const inputs = mediaDevices.videoInputs;
        const byLabel = {};
        const items = [];
        for (const d of inputs) {
            const idStr = String(d.id);
            let label = d.description || idStr;
            if (byLabel[label])
                label = label + " (" + idStr.substring(0, 4) + ")";
            byLabel[label] = d;
            items.push(root.makeItem(label));
        }
        root.deviceByLabel = byLabel;
        root.deviceItems = items;

        let active = root.activeDeviceItem ? items.find(i => i.text === root.activeDeviceItem.text) : null;
        if (!active && items.length > 0) {
            const defId = String(mediaDevices.defaultVideoInput.id);
            active = items.find(i => String(byLabel[i.text].id) === defId) ?? items[0];
        }
        root.activeDeviceItem = active ?? null;

        root.destroyItems(oldItems);
        root.rebuildResolutionItems();
    }

    function rebuildResolutionItems() {
        const oldItems = root.resolutionItems;
        const device = root.currentDevice();
        const formats = device?.videoFormats ?? [];
        const sorted = formats.slice().sort((a, b) => b.resolution.width * b.resolution.height - a.resolution.width * a.resolution.height);
        const byLabel = {};
        const items = [];
        for (const f of sorted) {
            const label = f.resolution.width + " × " + f.resolution.height;
            if (byLabel[label])
                continue;
            byLabel[label] = {
                width: f.resolution.width,
                height: f.resolution.height
            };
            const hasMultipleFrameRates = root.fpsCountForResolution(sorted, f.resolution.width, f.resolution.height) > 1;
            items.push(root.makeItem(label, hasMultipleFrameRates ? "speed" : ""));
        }
        root.resByLabel = byLabel;
        root.resolutionItems = items;

        let active = root.activeResolutionItem ? items.find(i => i.text === root.activeResolutionItem.text) : null;
        if (!active && items.length > 0) {
            const cur = camera.cameraFormat;
            if (cur.resolution.width > 0) {
                const curLabel = cur.resolution.width + " × " + cur.resolution.height;
                active = items.find(i => i.text === curLabel);
            }
        }
        root.activeResolutionItem = active ?? (items.length > 0 ? items[0] : null);

        root.destroyItems(oldItems);
        root.rebuildFrameRateItems();
    }

    function rebuildFrameRateItems() {
        const oldItems = root.frameRateItems;
        if (!root.activeResolutionItem) {
            root.frameRateItems = [];
            root.formatByLabel = {};
            root.activeFrameRateItem = null;
            root.destroyItems(oldItems);
            return;
        }

        const res = root.resByLabel[root.activeResolutionItem.text];
        const device = root.currentDevice();
        const formats = (device?.videoFormats ?? []).filter(f => f.resolution.width === res.width && f.resolution.height === res.height);
        const sorted = formats.slice().sort((a, b) => b.maxFrameRate - a.maxFrameRate);
        const byLabel = {};
        const items = [];
        for (const f of sorted) {
            const label = qsTr("%1 fps").arg(Math.round(f.maxFrameRate));
            if (byLabel[label])
                continue;
            byLabel[label] = f;
            items.push(root.makeItem(label));
        }
        root.formatByLabel = byLabel;
        root.frameRateItems = items;

        let active = root.activeFrameRateItem ? items.find(i => i.text === root.activeFrameRateItem.text) : null;
        root.activeFrameRateItem = active ?? (items.length > 0 ? items[0] : null);

        root.destroyItems(oldItems);
        root.applyFormat();
    }

    function applyFormat() {
        const format = root.activeFrameRateItem ? root.formatByLabel[root.activeFrameRateItem.text] : null;
        if (format)
            camera.cameraFormat = format;
    }

    Component.onCompleted: root.rebuildDeviceItems()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Component {
            id: menuItemComp

            MenuItem {}
        }

        MediaDevices {
            id: mediaDevices

            onVideoInputsChanged: root.rebuildDeviceItems()
        }

        CaptureSession {
            id: captureSession

            camera: Camera {
                id: camera

                active: root.previewOn
                cameraDevice: root.currentDevice() ?? mediaDevices.defaultVideoInput
            }
            videoOutput: videoOutput
        }

        ConnectedRect {
            id: previewBox

            Layout.fillWidth: true
            first: true
            last: true
            color: "black"
            implicitHeight: 220
            clip: true

            VideoOutput {
                id: videoOutput

                anchors.fill: parent
                visible: root.previewOn
                fillMode: VideoOutput.PreserveAspectFit
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: !root.previewOn
                spacing: Tokens.padding.extraSmall

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "videocam_off"
                    color: Colours.palette.m3outlineVariant
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Preview is off")
                    color: Colours.palette.m3outlineVariant
                    font: Tokens.font.body.large
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Tokens.padding.small
                visible: root.previewOn && camera.errorString !== ""
                text: camera.errorString
                color: Colours.palette.m3error
                font: Tokens.font.body.small
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.small
            first: true
            last: true
            text: qsTr("Show preview")
            checked: root.previewOn
            onToggled: root.previewOn = checked
        }

        SectionHeader {
            text: qsTr("Camera")
        }

        SelectRow {
            visible: root.deviceItems.length > 1
            first: true
            last: root.resolutionItems.length === 0
            label: qsTr("Device")
            subtext: qsTr("Which camera to configure")
            menuItems: root.deviceItems
            active: root.activeDeviceItem
            onSelected: item => {
                root.activeDeviceItem = item;
                root.rebuildResolutionItems();
            }
        }

        StyledText {
            visible: root.resolutionItems.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No camera detected")
            color: Colours.palette.m3outlineVariant
            font: Tokens.font.body.medium
        }

        SelectRow {
            visible: root.resolutionItems.length > 0
            first: root.deviceItems.length <= 1
            last: root.frameRateItems.length === 0
            label: qsTr("Resolution")
            menuItems: root.resolutionItems
            active: root.activeResolutionItem
            onSelected: item => {
                root.activeResolutionItem = item;
                root.rebuildFrameRateItems();
            }
        }

        // Only one frame rate available at this resolution: nothing to pick, just show it.
        ConnectedRect {
            visible: root.frameRateItems.length === 1
            Layout.fillWidth: true
            last: true
            implicitHeight: fpsLayout.implicitHeight + fpsLayout.anchors.margins * 2

            RowLayout {
                id: fpsLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Frame rate")
                    font: Tokens.font.body.small
                }

                StyledText {
                    text: root.frameRateItems.length > 0 ? root.frameRateItems[0].text : ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }

        // Multiple frame rates available at this resolution: let it be picked.
        SelectRow {
            visible: root.frameRateItems.length > 1
            last: true
            label: qsTr("Frame rate")
            menuItems: root.frameRateItems
            active: root.activeFrameRateItem
            onSelected: item => {
                root.activeFrameRateItem = item;
                root.applyFormat();
            }
        }
    }
}
