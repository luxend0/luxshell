import QtQuick
import qs.config
import qs.core
import qs.services

// Power mode (services/PowerProfile, power-profiles-daemon): leaf / gauge / zap, optional
// name (Settings.islandPowerProfileLabel). Click = next profile (Performance -> Balanced ->
// Power Saver -> ...), right click = the small menu with all three (panel "menu-powerprofile").
// The bar leaves it out where the daemon does not answer (BarRegistry.present). Reads the
// profile once when created; the menu and the control center read it again when they open.
BarToggle {
    id: root

    icon: PowerProfile.icon(PowerProfile.profile)
    text: Settings.islandPowerProfileLabel ? PowerProfile.label(PowerProfile.profile) : ""
    // cycles from the most power down, like the menu's order
    onClicked: {
        const order = ["performance", "balanced", "power-saver"].filter(p => PowerProfile.profiles.includes(p));
        if (order.length > 1)
            PowerProfile.set(order[(order.indexOf(PowerProfile.profile) + 1) % order.length]);
    }
    onRightClicked: Ui.open("menu-powerprofile", root.screen ? root.screen.name : undefined)
    Component.onCompleted: PowerProfile.refresh()
}
