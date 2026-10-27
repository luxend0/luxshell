pragma Singleton
import QtQuick
import Quickshell

// Process environment, read once. Everything that can be steered from outside
// (tests, sandbox, keybind wrappers) is collected here so no other file calls
// Quickshell.env() directly.
//
//   LUXSHELL_PREVIEW      collapsed | hover | <panel id>   forced state at start
//   LUXSHELL_NOTIFS=1     run the NotificationServer (off by default: Ambxst owns the bus name)
//   LUXSHELL_FAKE_NOTIFS  fake unread count while the server is off
//   LUXSHELL_CONFIG_DIR   settings directory (default $XDG_CONFIG_HOME/luxshell)
//   LUXSHELL_FAKE_CLOCK   ISO date/time shown instead of the real clock (screenshots)
Singleton {
    id: root

    function get(name: string): string {
        const v = Quickshell.env(name);
        return v === undefined || v === null ? "" : String(v);
    }

    readonly property string preview: get("LUXSHELL_PREVIEW")
    readonly property bool notifs: get("LUXSHELL_NOTIFS") === "1"
    readonly property int fakeNotifs: parseInt(get("LUXSHELL_FAKE_NOTIFS")) || 0
    readonly property string fakeClock: get("LUXSHELL_FAKE_CLOCK")
    readonly property string configDir: {
        const own = get("LUXSHELL_CONFIG_DIR");
        if (own !== "")
            return own;
        const xdg = get("XDG_CONFIG_HOME");
        return (xdg !== "" ? xdg : get("HOME") + "/.config") + "/luxshell";
    }
}
