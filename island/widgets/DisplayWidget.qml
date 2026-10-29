import QtQuick
import qs.config
import qs.core
import qs.services

// Display brightness (services/Brightness: DDC/CI or backlight) of the screen this island is
// on: sun glyph by level, optional percentage (Settings.islandDisplayPercent). Scroll =
// brightness in Settings.islandDisplayStep % steps (no OSD: an overlay would replace the hover
// island under the pointer and swallow the next notches; the screen itself shows it), click
// opens the display menu (panel "sheet-display": brightness + night light). Reads the displays
// once when created (rate limited, nice 19).
BarToggle {
    id: root

    readonly property bool ready: Brightness.displays.length > 0
    readonly property int index: {
        const name = root.screen ? root.screen.name : "";
        const i = Brightness.displays.findIndex(d => name !== "" && d.connector.endsWith("-" + name));
        return i >= 0 ? i : Math.min(Brightness.primary, Math.max(0, Brightness.displays.length - 1));
    }
    readonly property real value: ready ? Brightness.displays[index].value : 0
    readonly property string glyph: !ready ? "sun" : value < 0.34 ? "sun-dim" : value < 0.67 ? "sun-medium" : "sun"

    function step(steps: int): void {
        if (!ready)
            return;
        Brightness.set(index, value + steps * Settings.islandDisplayStep / 100);
    }

    icon: glyph
    color: ready ? Theme.text : Theme.menus.off
    text: Settings.islandDisplayPercent && ready ? `${Math.round(value * 100)}%` : ""
    wantsWheel: true
    wantsRight: false
    onClicked: Ui.open("sheet-display", root.screen ? root.screen.name : undefined)
    onWheeled: steps => step(steps)
    Component.onCompleted: Brightness.refresh(false)
}
