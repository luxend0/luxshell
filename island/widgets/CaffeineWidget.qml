import QtQuick
import qs.config
import qs.core
import qs.services

// Caffeine (services/Caffeine, logind idle inhibitor): coffee glyph, dimmed while off; on,
// the time left of a timed run (Settings.islandCaffeineTime). Click = on (for
// Settings.islandCaffeineClick minutes, 0 = until turned off) / off, right click = the small
// menu: 30 min / 1 h / 2 h / until off (panel "menu-caffeine").
BarToggle {
    id: root

    icon: "coffee"
    color: Caffeine.active ? Theme.text : Theme.menus.off
    text: Settings.islandCaffeineTime && Caffeine.active ? Caffeine.leftShort : ""
    onClicked: Caffeine.toggleFor(Settings.islandCaffeineClick)
    onRightClicked: Ui.open("menu-caffeine", root.screen ? root.screen.name : undefined)
}
