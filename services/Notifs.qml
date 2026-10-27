pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Notification store. The D-Bus server only runs with LUXSHELL_NOTIFS=1
// (Ambxst owns org.freedesktop.Notifications during the transition);
// otherwise the count is LUXSHELL_FAKE_NOTIFS (default 0).
Singleton {
    id: root

    readonly property bool live: Env.notifs
    readonly property var list: live && server.item ? server.item.trackedNotifications.values : []
    readonly property int count: live ? list.length : Env.fakeNotifs
    readonly property string status: count === 0 ? "All caught up" : count === 1 ? "1 notification" : `${count} notifications`

    LazyLoader {
        id: server
        active: root.live

        NotificationServer {
            keepOnReload: false
            bodySupported: true
            actionsSupported: true
            imageSupported: true
            onNotification: n => n.tracked = true
        }
    }
}
