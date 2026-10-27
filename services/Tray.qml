pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// StatusNotifier items (host only; works next to another watcher such as Ambxst).
Singleton {
    id: root

    readonly property var items: SystemTray.items
}
