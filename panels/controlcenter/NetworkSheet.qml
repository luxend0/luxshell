import QtQuick
import qs.config
import qs.services

// Network sheet (same style as Bluetooth): wired connections, then the Wi-Fi list
// (scanning while open). A new secured network unfolds a password field inside
// its row; Enter or "Join" connects, Esc folds it again. Switch = Wi-Fi radio.
SheetPage {
    id: page

    readonly property bool hasWired: Networks.wired.length > 0

    title: hasWired && Networks.wifiAvailable ? "Network" : Networks.wifiAvailable ? "Wi-Fi" : hasWired ? "Ethernet" : "Network"
    hasSwitch: Networks.wifiAvailable
    switchOn: Networks.wifiEnabled
    onToggled: Networks.setWifi(!Networks.wifiEnabled)

    Component.onCompleted: Networks.setScanning(true)
    Component.onDestruction: Networks.setScanning(false)

    component WiredRow: SheetRow {
        required property var modelData
        icon: "ethernet"
        name: Networks.connectionName(modelData.network) || modelData.name
        sub: Networks.wiredStatus(modelData)
        on: modelData.connected
        button: modelData.connected ? "Disconnect" : "Connect"
        onActivated: Networks.toggleWired(modelData)
    }

    component WifiRow: SheetRow {
        id: wrow
        required property var modelData
        property bool asking: false

        function join(): void {
            if (pw.text.length < 8)
                return;
            Networks.connectWithPassword(modelData, pw.text);
            fold();
        }
        function fold(): void {
            asking = false;
            pw.text = "";
            if (pw.activeFocus) {
                pw.focus = false;
                page.releaseFocus();
            }
        }

        icon: Networks.strengthIcon(modelData)
        name: modelData.name
        sub: modelData.connected ? "Connected" : modelData.known ? "Saved" : Networks.secured(modelData) ? "Secured" : "Open"
        on: modelData.connected
        busy: modelData.stateChanging ?? false
        button: modelData.connected ? "Disconnect" : asking ? "" : "Connect"
        trailingIcon: asking ? "lock" : ""
        expanded: asking
        extraHeight: 58
        onActivated: {
            if (!Networks.needsPassword(modelData)) {
                Networks.activate(modelData);
            } else if (asking) {
                fold();
            } else {
                asking = true;
                Qt.callLater(() => pw.forceActiveFocus());
            }
        }

        Rectangle {
            x: wrow.sh.discX
            y: 2
            width: parent.width - 2 * x
            height: 44
            radius: height / 2
            color: Theme.cc.track
            border.width: 1
            border.color: pw.activeFocus ? Theme.muted : Theme.cc.stroke

            TextInput {
                id: pw
                x: 20
                width: join.x - x - 10
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: Theme.text
                selectionColor: Theme.muted
                clip: true
                Keys.onReturnPressed: wrow.join()
                Keys.onEnterPressed: wrow.join()
                Keys.onEscapePressed: wrow.fold()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.text === ""
                    text: "Password"
                    font: pw.font
                    color: Theme.textDim
                }
            }

            PillButton {
                id: join
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                height: 36
                textSize: wrow.sh.pillSize
                textWeight: Font.DemiBold
                padX: wrow.sh.pillPad
                baseColor: wrow.sh.pillColor
                primary: pw.text.length >= 8
                text: "Join"
                onClicked: wrow.join()
            }
        }
    }

    SheetSection {
        caption: "Ethernet"
        visible: page.hasWired
        Repeater {
            model: Networks.wired
            WiredRow {}
        }
    }

    SheetSection {
        caption: "Wi-Fi"
        status: Networks.scanning ? "Scanning" : ""
        showHint: Networks.wifiNetworks.length === 0
        hint: !Networks.wifiAvailable ? "No Wi-Fi adapter" : !Networks.wifiEnabled ? "Wi-Fi is off" : "Looking for networks…"
        Repeater {
            model: Networks.wifiNetworks
            WifiRow {}
        }
    }
}
