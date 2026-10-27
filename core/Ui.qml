pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Central UI state. Islands only READ these properties; every change goes
// through the functions below (IPC, keybinds, clicks all end up here).
//
// What an island on screen S shows, highest priority first:
//   1. panel    Ui.panel, if opened on S (or on every screen: panelScreen "")
//   2. overlay  Ui.overlay (OSD etc.), if flashed on S
//   3. hover    Ui.forced === "hover", or the pointer is on the island
//   4. collapsed
Singleton {
    id: root

    property string panel: ""          // registered panel id, "" = none
    property string panelScreen: ""    // screen name, "" = every screen (preview)
    property string overlay: ""
    property string overlayScreen: ""
    property string forced: ""         // "collapsed" | "hover" | "" (preview override for the bar)

    function focusedScreen(): string {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    function panelFor(screen: string): string {
        return panel !== "" && (panelScreen === "" || panelScreen === screen) ? panel : "";
    }
    function overlayFor(screen: string): string {
        return overlay !== "" && (overlayScreen === "" || overlayScreen === screen) ? overlay : "";
    }

    // screen: optional; defaults to the focused monitor, "" = every screen
    function open(id, screen) {
        if (!Panels.has(id)) {
            console.info(`luxshell: no panel "${id}" registered`);
            return;
        }
        if (Panels.kind(id) === "overlay") {
            flash(id, 0, screen);
            return;
        }
        panelScreen = screen === undefined ? focusedScreen() : screen;
        panel = id;
    }

    function toggle(id, screen) {
        const where = screen === undefined ? focusedScreen() : screen;
        if (panel === id && (panelScreen === "" || panelScreen === where))
            close();
        else
            open(id, where);
    }

    function close() {
        panel = "";
        panelScreen = "";
    }

    function flash(id, ms, screen) {
        if (Panels.kind(id) !== "overlay") {
            console.info(`luxshell: "${id}" is not an overlay`);
            return;
        }
        overlayScreen = screen === undefined ? focusedScreen() : screen;
        overlay = id;
        overlayTimer.interval = ms > 0 ? ms : 1600;
        overlayTimer.restart();
    }

    // "collapsed" | "hover" force the bar, a panel id opens it on every screen,
    // "" / "auto" returns to normal behaviour.
    function preview(state: string): void {
        if (state === "collapsed" || state === "hover") {
            close();
            forced = state;
        } else if (state === "" || state === "auto") {
            forced = "";
            close();
        } else {
            forced = "";
            open(state, "");
        }
    }

    Timer {
        id: overlayTimer
        onTriggered: {
            root.overlay = "";
            root.overlayScreen = "";
        }
    }

    Component.onCompleted: if (Env.preview !== "")
        preview(Env.preview)
}
