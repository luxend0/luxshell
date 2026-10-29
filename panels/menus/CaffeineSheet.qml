import QtQuick
import qs.config
import qs.services
import qs.panels.controlcenter

// Caffeine menu (registry "menu-caffeine", right click on the bar's caffeine widget): switch =
// on / off (on for Settings.islandCaffeineClick minutes, like a click on the widget), rows =
// keep awake for 30 min / 1 h / 2 h / until turned off. A row shows when that run would end,
// the running one its time left (services/Caffeine). A pick starts it and emits picked;
// panels/SheetMenu closes the menu.
SheetPage {
    id: page

    signal picked

    readonly property var choices: [30, 60, 120, 0]
    property double opened: Clock.now.getTime() // "Until 21:37" from the island's clock (LUXSHELL_FAKE_CLOCK too)

    function label(min: int): string {
        return min === 0 ? "Until turned off" : min === 30 ? "30 minutes" : min === 60 ? "1 hour" : `${min / 60} hours`;
    }
    function ends(min: int): string {
        if (min === 0)
            return "No time limit";
        return "Until " + Clock.formatTime(new Date(opened + min * 60000), Settings.clockFormat);
    }

    // keyboard starts on the running choice, else on the first one (panels/SheetMenu)
    readonly property Item menuDefault: {
        for (let i = 0; i < rows.count; i++)
            if (rows.itemAt(i)?.current)
                return rows.itemAt(i);
        return rows.count > 0 ? rows.itemAt(0) : null;
    }

    title: "Caffeine"
    backButton: false
    hasSwitch: true
    switchOn: Caffeine.active
    onToggled: Caffeine.toggleFor(Settings.islandCaffeineClick)

    SheetSection {
        caption: "Keep awake"

        Repeater {
            id: rows
            model: page.choices

            SheetRow {
                required property int modelData
                readonly property bool current: Caffeine.active && Caffeine.minutes === modelData
                icon: modelData === 0 ? "infinity" : "timer"
                name: page.label(modelData)
                sub: !current ? page.ends(modelData) : modelData === 0 ? "On" : `${Caffeine.leftLong} left`
                on: current
                trailingIcon: current ? "check" : ""
                onActivated: {
                    Caffeine.start(modelData);
                    page.picked();
                }
            }
        }
    }
}
