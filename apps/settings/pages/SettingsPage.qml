import QtQuick

// One page of the settings app: title card + sections of option rows, as data.
// Catalog.qml lists the pages (one line each); ../README.md documents the option kinds.
//
//   SettingsPage {
//       pageId: "bar"; title: "Bar & Island"; subtitle: "..."; icon: 0xF1513
//       group: "system"   (only for pages of the OS, default "luxshell")
//       sections: [{ "title": "", "options": [{ "id": "workspaces", "kind": "slider", "key": "workspaceCount", ... }] }]
//   }
//
// A page without options (or with hidden: true) stays out of the sidebar and search.
// Children (Timer, Process, Component for "custom" rows) go straight inside the page.
// Only read live state inside the option functions: a binding in `sections` itself
// rebuilds every row of the page when it changes.
QtObject {
    id: page

    property string pageId: ""
    property string title: ""
    property string subtitle: ""
    property var icon: 0         // Material Design codepoint of the Nerd Font (0xF03D8) or a glyph string
    property string group: "luxshell" // sidebar group: "luxshell" (the shell) | "system" (the OS, Catalog.groups)
    property bool hidden: false
    property var sections: []
    default property list<QtObject> data

    // helpers for option functions
    function glyph(cp: int): string {
        return String.fromCodePoint(cp);
    }
    function trim(n: real): string {
        return String(Math.round(n * 100) / 100);
    }
    function hex(c: color): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }
}
