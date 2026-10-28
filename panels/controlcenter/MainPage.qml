import QtQuick
import Quickshell
import qs.config
import qs.core
import qs.services
import qs.widgets

// Main page, ref/08 without the notifications card (own panel: panels/NotificationCenter.qml).
// What it shows and where comes from Settings.ccTiles / ccSliders, packed by CcLayout with
// the measured metrics; the default is the video's grid: row 1 Wi-Fi, Focus, lock; row 2
// Bluetooth and Game Mode sharing the full width; Sound and Display sliders, then the panel
// ends (CcLayout.height). Network, Bluetooth, Sound and Display open a sheet (openPage);
// the control that opened it hides while the sheet grows out of it.
//
// Every shown item is one delegate keyed by its id (ScriptModel over CcLayout.keys), so a
// layout change while the page is up lets the items glide to their new slots instead of
// rebuilding the page. Keyboard: arrows move spatially between controls, Tab in reading
// order (ControlCenter).
FocusScope {
    id: page

    signal openPage(string id, Item origin)
    readonly property Item defaultItem: firstControl()

    // origins of the sheets (panels/ControlCenter.qml morphs from their rects); null while
    // the tile is not shown (the sheet then grows out of the panel's top centre)
    readonly property Item networkTile: itemFor("network")
    readonly property Item bluetoothTile: itemFor("bluetooth")
    readonly property Item soundCard: itemFor("s:sound")
    readonly property Item displayCard: itemFor("s:display")
    property Item morphSource: null
    property real morphHide: 0 // 0..1, how far morphSource is hidden
    function veil(item: Item): real {
        return morphSource !== null && morphSource === item ? 1 - morphHide : 1;
    }

    // slots glide only once the page stands (not while it is built)
    property bool settled: false
    Component.onCompleted: Qt.callLater(() => page.settled = true)

    implicitWidth: Theme.cc.width
    implicitHeight: CcLayout.height

    // bumps when delegates come and go, so itemFor() bindings re-run
    property int revision: 0
    function itemFor(key: string): Item {
        void revision;
        for (let i = 0; i < slots.count; i++) {
            const d = slots.itemAt(i);
            if (d && d.key === key)
                return d.control;
        }
        return null;
    }
    function firstControl(): Item {
        void revision;
        return CcLayout.keys.length > 0 ? itemFor(CcLayout.keys[0]) : null;
    }

    // ---- actions ------------------------------------------------------------------
    readonly property bool wired: Net.kind === "ethernet"
    readonly property int wifiLevel: Net.kind === "wifi" ? Math.max(1, Math.min(3, Math.round(Net.strength * 3))) : 0

    function setVolume(v: real): void {
        if (Audio.ready && Exec.allow(`volume ${Math.round(v * 100)} %`))
            Audio.sink.audio.volume = v;
    }
    function switchTheme(): void {
        const a = Settings.ccThemeA, b = Settings.ccThemeB;
        Settings.set("theme", Settings.theme === b ? a : b);
    }

    ScriptModel {
        id: model
        values: CcLayout.keys
    }

    Repeater {
        id: slots
        model: model

        Item {
            id: slot
            required property string modelData
            readonly property string key: modelData
            readonly property var s: CcLayout.slots[key] ?? null
            readonly property Item control: loader.item

            Component.onCompleted: page.revision++
            Component.onDestruction: page.revision++

            x: s ? s.x : 0
            y: s ? s.y : 0
            width: s ? s.w : 0
            height: Theme.cc.row
            opacity: s ? 1 : 0
            Behavior on x {
                enabled: page.settled
                Glide {}
            }
            Behavior on y {
                enabled: page.settled
                Glide {}
            }
            Behavior on width {
                enabled: page.settled
                Glide {}
            }

            Loader {
                id: loader
                width: slot.width
                height: slot.height
                opacity: page.veil(item)
                sourceComponent: ({
                        "network": networkComp,
                        "focus": focusComp,
                        "bluetooth": bluetoothComp,
                        "gamemode": gameModeComp,
                        "nightlight": nightComp,
                        "caffeine": caffeineComp,
                        "mic": micComp,
                        "power": powerComp,
                        "lock": lockComp,
                        "screenshot": screenshotComp,
                        "theme": themeComp,
                        "s:sound": soundComp,
                        "s:display": displayComp,
                        "s:mic": micSliderComp
                    })[slot.key] ?? null
            }
        }
    }

    component Glide: NumberAnimation {
        duration: Motion.ms(Theme.ccLayout.relayout)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasized
    }

    // nothing chosen in the settings: one quiet line instead of a bare panel
    Txt {
        anchors.centerIn: parent
        visible: CcLayout.empty
        text: "Nothing to show. Settings > Control Center"
        color: Theme.textDim
        font.pixelSize: Theme.cc.subSize
    }

    // ---- items ----------------------------------------------------------------------
    Component {
        id: networkComp
        Tile {
            id: wifi
            hasPage: true
            icon: page.wired ? "ethernet" : Networks.wifiAvailable && !Networks.wifiEnabled ? "wifi-off" : `wifi-${page.wifiLevel}`
            iconSize: page.wired ? 19 : 22
            label: page.wired ? "Ethernet" : Networks.wifiAvailable ? "Wi-Fi" : "Network"
            sub: page.wired ? Networks.wiredStatus(Net.wired) : Net.kind === "wifi" ? Net.label : Networks.wifiAvailable ? (Networks.wifiEnabled ? "Not connected" : "Off") : "Offline"
            on: Net.kind !== "offline" || (Networks.wifiAvailable && Networks.wifiEnabled)
            onToggled: Networks.setWifi(!Networks.wifiEnabled)
            onOpened: page.openPage("network", wifi)
        }
    }

    Component {
        id: focusComp
        Tile {
            icon: "circle-minus"
            iconStroke: 2.4
            label: "Focus"
            sub: Settings.dnd ? "On" : "Off"
            on: Settings.dnd
            onToggled: Settings.set("dnd", !Settings.dnd)
        }
    }

    Component {
        id: bluetoothComp
        Tile {
            id: bluetooth
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
    }

    Component {
        id: gameModeComp
        Tile {
            icon: "gamemode"
            iconSize: 22
            label: "Game Mode"
            sub: GameMode.busy ? "..." : GameMode.active ? "On" : "Off"
            on: GameMode.active
            onToggled: GameMode.toggle()
        }
    }

    Component {
        id: nightComp
        Tile {
            icon: "sun-moon"
            iconSize: 21
            label: "Night Light"
            sub: NightLight.active ? `${Settings.ccNightTemp} K` : "Off"
            on: NightLight.active
            onToggled: NightLight.toggle()
        }
    }

    Component {
        id: caffeineComp
        Tile {
            icon: "coffee"
            iconSize: 20
            label: "Caffeine"
            sub: Caffeine.active ? "Stays awake" : "Off"
            on: Caffeine.active
            onToggled: Caffeine.toggle()
        }
    }

    Component {
        id: micComp
        Tile {
            icon: Mic.icon
            iconSize: 20
            label: "Microphone"
            sub: !Mic.ready ? "No microphone" : Mic.muted ? "Muted" : "On"
            on: Mic.ready && !Mic.muted
            onToggled: Mic.toggleMute()
        }
    }

    Component {
        id: powerComp
        Tile {
            icon: PowerProfile.icon(PowerProfile.profile)
            iconSize: 20
            label: "Power Mode"
            sub: PowerProfile.label(PowerProfile.profile)
            on: PowerProfile.profile !== "" && PowerProfile.profile !== "balanced"
            onToggled: PowerProfile.cycle()
        }
    }

    Component {
        id: lockComp
        RoundButton {
            icon: "lock"
            iconSize: 19
            onClicked: {
                Exec.run(["loginctl", "lock-session"], "lock");
                Ui.close();
            }
        }
    }

    Component {
        id: screenshotComp
        RoundButton {
            icon: "camera"
            iconSize: 20
            onClicked: {
                Ui.close();
                Screenshot.take();
            }
        }
    }

    // like the video's light/dark button: white while theme B is applied; right click opens
    // the theme picker
    Component {
        id: themeComp
        RoundButton {
            icon: "contrast"
            iconSize: 20
            on: Settings.theme === Settings.ccThemeB
            onClicked: page.switchTheme()
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: Ui.open("themes")
            }
        }
    }

    Component {
        id: soundComp
        SliderCard {
            id: sound
            label: "Sound"
            icon: Audio.icon
            iconSize: 18
            value: Audio.volume
            sliderEnabled: Audio.ready
            onMoved: v => page.setVolume(v)
            onOpened: page.openPage("sound", sound)
        }
    }

    Component {
        id: displayComp
        SliderCard {
            id: display
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

    Component {
        id: micSliderComp
        SliderCard {
            label: "Microphone"
            icon: Mic.icon
            iconSize: 18
            hasPage: false
            value: Mic.volume
            sliderEnabled: Mic.ready
            onMoved: v => Mic.setVolume(v)
        }
    }
}
