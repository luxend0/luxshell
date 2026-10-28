import QtQuick
import Quickshell

// Creates the settings window while it is open (SettingsApp.open); closing destroys
// it, page and history stay in SettingsApp. Referencing SettingsApp here also
// registers its IPC target ("settings") at shell start.
Scope {
    LazyLoader {
        active: SettingsApp.open

        SettingsWindow {}
    }
}
