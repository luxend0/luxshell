import QtQuick
import qs.config
import qs.core
import qs.services

// Main page, ref/08 without the light/dark button and without the notifications card
// (own panel: panels/NotificationCenter.qml): row 1 Wi-Fi, Focus, lock; row 2 Bluetooth
// and Game Mode sharing the full width; Sound and Display sliders, then the panel ends
// (Theme.cc.height). Network, Bluetooth, Sound and Display open a sheet
// (openPage); the control that opened it hides while the sheet grows out of it.
// Keyboard: arrows move spatially between controls, Tab in order (ControlCenter).
FocusScope {
    id: page

    signal openPage(string id, Item origin)
    readonly property Item defaultItem: wifi

    // origins of the sheets (panels/ControlCenter.qml morphs from their rects)
    readonly property Item networkTile: wifi
    readonly property Item bluetoothTile: bluetooth
    readonly property Item soundCard: sound
    readonly property Item displayCard: display
    property Item morphSource: null
    property real morphHide: 0 // 0..1, how far morphSource is hidden
    function veil(item: Item): real {
        return morphSource === item ? 1 - morphHide : 1;
    }

    readonly property int pad: Theme.cc.pad
    readonly property int step: Theme.cc.row + Theme.cc.gapY

    implicitWidth: Theme.cc.width
    implicitHeight: Theme.cc.height

    // ---- network tile -------------------------------------------------------
    readonly property bool wired: Net.kind === "ethernet"
    readonly property int wifiLevel: Net.kind === "wifi" ? Math.max(1, Math.min(3, Math.round(Net.strength * 3))) : 0

    function setVolume(v: real): void {
        if (Audio.ready && Exec.allow(`volume ${Math.round(v * 100)} %`))
            Audio.sink.audio.volume = v;
    }

    Tile {
        id: wifi
        x: page.pad
        y: page.pad
        opacity: page.veil(wifi)
        hasPage: true
        icon: page.wired ? "ethernet" : Networks.wifiAvailable && !Networks.wifiEnabled ? "wifi-off" : `wifi-${page.wifiLevel}`
        iconSize: page.wired ? 19 : 22
        label: page.wired ? "Ethernet" : Networks.wifiAvailable ? "Wi-Fi" : "Network"
        sub: page.wired ? Networks.wiredStatus(Net.wired) : Net.kind === "wifi" ? Net.label : Networks.wifiAvailable ? (Networks.wifiEnabled ? "Not connected" : "Off") : "Offline"
        on: Net.kind !== "offline" || (Networks.wifiAvailable && Networks.wifiEnabled)
        onToggled: Networks.setWifi(!Networks.wifiEnabled)
        onOpened: page.openPage("network", wifi)
    }

    Tile {
        id: focusTile
        x: wifi.x + wifi.width + Theme.cc.gapX
        y: page.pad
        icon: "circle-minus"
        iconStroke: 2.4
        label: "Focus"
        sub: Settings.dnd ? "On" : "Off"
        on: Settings.dnd
        onToggled: Settings.set("dnd", !Settings.dnd)
    }

    RoundButton {
        id: lock
        x: focusTile.x + focusTile.width + Theme.cc.gapX
        y: page.pad
        icon: "lock"
        iconSize: 19
        onClicked: {
            Exec.run(["loginctl", "lock-session"], "lock");
            Ui.close();
        }
    }

    Tile {
        id: bluetooth
        x: page.pad
        y: page.pad + page.step
        width: Theme.cc.wideTile
        opacity: page.veil(bluetooth)
        hasPage: true
        icon: Bt.enabled || !Bt.available ? "bluetooth" : "bluetooth-off"
        iconSize: 17
        iconStroke: 2.6
        label: "Bluetooth"
        sub: Bt.status
        on: Bt.enabled
        onToggled: Bt.toggle()
        onOpened: page.openPage("bluetooth", bluetooth)
    }

    Tile {
        id: gameMode
        x: bluetooth.x + bluetooth.width + Theme.cc.gapX
        y: page.pad + page.step
        width: Theme.cc.wideTile
        icon: "gamemode"
        iconSize: 22
        label: "Game Mode"
        sub: GameMode.busy ? "..." : GameMode.active ? "On" : "Off"
        on: GameMode.active
        onToggled: GameMode.toggle()
    }

    SliderCard {
        id: sound
        x: page.pad
        y: page.pad + 2 * page.step
        width: page.width - 2 * page.pad
        opacity: page.veil(sound)
        label: "Sound"
        icon: Audio.icon
        iconSize: 18
        value: Audio.volume
        sliderEnabled: Audio.ready
        onMoved: v => page.setVolume(v)
        onOpened: page.openPage("sound", sound)
    }

    SliderCard {
        id: display
        x: page.pad
        y: page.pad + 3 * page.step
        width: page.width - 2 * page.pad
        opacity: page.veil(display)
        label: "Display"
        icon: "sun-dim"
        iconSize: 23
        iconStroke: 2.5
        value: Brightness.ready ? Brightness.value : 0.5
        sliderEnabled: Brightness.ready
        onMoved: v => Brightness.setPrimary(v)
        onOpened: page.openPage("display", display)
    }
}
