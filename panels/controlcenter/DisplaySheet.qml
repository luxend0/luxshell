import QtQuick
import qs.config
import qs.services

// Display sheet: one brightness slider per DDC/CI display (or the backlight).
// The header button re-reads the displays (DDC is slow, reads are rate limited).
// withNightLight (bar menu "sheet-display", panels/SheetMenu): a "Night Light" part below
// with the switch (services/NightLight, wlsunset) and the temperature slider.
SheetPage {
    id: page

    property bool withNightLight: false

    title: "Display"
    actionIcon: "refresh"
    onToggled: Brightness.refresh(true)

    Component.onCompleted: Brightness.refresh(false)

    SheetSection {
        caption: "Brightness"
        status: Brightness.loading ? "Reading" : Brightness.backend === "ddc" ? "DDC/CI" : Brightness.backend === "backlight" ? "Backlight" : ""
        statusDot: Brightness.loading
        showHint: Brightness.displays.length === 0
        hint: Brightness.loading ? "Looking for displays…" : "No DDC/CI display or backlight found"

        Repeater {
            model: Brightness.displays
            SliderRow {
                required property var modelData
                required property int index
                label: modelData.connector !== "-" && modelData.bus >= 0 ? `${modelData.model} · ${modelData.connector.replace(/^card\d+-/, "")}` : modelData.model
                valueText: `${Math.round(modelData.value * 100)} %`
                value: modelData.value
                trackIcon: "sun-dim"
                trackIconSize: 22
                onMoved: v => Brightness.set(index, v)
            }
        }
    }

    SheetSection {
        caption: "Night Light"
        visible: page.withNightLight
        showHint: !NightLight.available
        hint: "Needs wlsunset"

        SwitchRow {
            icon: "moon" // like the bar's night light widget
            name: "Night Light"
            sub: NightLight.active ? `Warm screen · ${Settings.ccNightTemp} K` : "Off"
            on: NightLight.active
            onToggled: NightLight.toggle()
        }
        SliderRow {
            readonly property real span: NightLight.maxTemp - NightLight.minTemp
            label: "Temperature"
            valueText: `${Settings.ccNightTemp} K`
            // right = cooler (more kelvin), like the settings slider
            value: (Settings.ccNightTemp - NightLight.minTemp) / span
            trackIcon: "thermometer"
            onMoved: v => NightLight.setTemp(NightLight.minTemp + v * span)
            onSecondary: NightLight.toggle()
        }
    }
}
