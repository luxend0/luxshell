import QtQuick
import qs.config
import qs.services
import qs.panels.controlcenter

// Power mode menu (registry "menu-powerprofile", right click on the bar's power mode widget):
// the power-profiles-daemon profiles in the order of GNOME's menu, the active one checked
// (white disc + check, like the sound sheet's devices). A pick sets it (services/PowerProfile,
// through Exec) and emits picked; panels/SheetMenu closes the menu.
SheetPage {
    id: page

    signal picked

    readonly property var info: ({
            "performance": "Fastest, uses more power",
            "balanced": "Speed and power in balance",
            "power-saver": "Slower and quieter, saves power"
        })

    // keyboard starts on the active profile (panels/SheetMenu)
    readonly property Item menuDefault: {
        for (let i = 0; i < rows.count; i++)
            if (rows.itemAt(i)?.current)
                return rows.itemAt(i);
        return rows.count > 0 ? rows.itemAt(0) : null;
    }

    title: "Power Mode"
    backButton: false

    Component.onCompleted: PowerProfile.refresh()

    SheetSection {
        caption: "Profile"
        showHint: !PowerProfile.available
        hint: "power-profiles-daemon is not running"

        Repeater {
            id: rows
            model: ["performance", "balanced", "power-saver"].filter(p => PowerProfile.profiles.includes(p))

            SheetRow {
                required property string modelData
                readonly property bool current: modelData === PowerProfile.profile
                icon: PowerProfile.icon(modelData)
                name: PowerProfile.label(modelData)
                sub: page.info[modelData] ?? ""
                on: current
                trailingIcon: current ? "check" : ""
                onActivated: {
                    PowerProfile.set(modelData);
                    page.picked();
                }
            }
        }
    }
}
