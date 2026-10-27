pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Minute clock. English formatting regardless of the system locale ("Sun, Oct 25").
Singleton {
    id: root

    readonly property var locale: Qt.locale("en_US")
    readonly property date now: Env.fakeClock !== "" ? new Date(Env.fakeClock) : clock.date
    readonly property string time: now.toLocaleTimeString(locale, "HH:mm")
    readonly property string date: now.toLocaleDateString(locale, "ddd, MMM d")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: Env.fakeClock === ""
    }
}
