import QtQuick
import qs.config
import qs.core
import qs.services

// Night light (services/NightLight, wlsunset): moon glyph (the sun-moon of the control
// center tile reads like the display widget's sun at bar size), dimmed while off, optional
// temperature (Settings.islandNightLightTemp). Click = on / off, scroll = temperature in
// Settings.islandNightLightStep K steps (Settings.ccNightTemp, shared with the control
// center; scroll up = more kelvin, like the sliders; no OSD, see DisplayWidget), right
// click = display menu (panel "sheet-display", switch + temperature slider). The bar leaves
// it out where wlsunset is missing (BarRegistry.present).
BarToggle {
    id: root

    icon: "moon"
    color: NightLight.active ? Theme.text : Theme.menus.off
    text: Settings.islandNightLightTemp ? `${Settings.ccNightTemp} K` : ""
    wantsWheel: true
    onClicked: NightLight.toggle()
    onRightClicked: Ui.open("sheet-display", root.screen ? root.screen.name : undefined)
    onWheeled: steps => NightLight.stepTemp(steps * Settings.islandNightLightStep)
    Component.onCompleted: NightLight.refresh()
}
