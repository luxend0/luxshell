pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Minute clock. English formatting regardless of the system locale ("Sun, Oct 25").
Singleton {
    id: root

    readonly property var locale: Qt.locale("en_US")
    readonly property date now: Env.fakeClock !== "" ? new Date(Env.fakeClock) : clock.date
    // formats from the settings app (Clock & Date page): "24h" | "12h" | "12h-ampm"
    readonly property string dateFormat: Settings.dateFormat !== "" ? Settings.dateFormat : "ddd, MMM d"
    readonly property string time: formatTime(now, Settings.clockFormat)
    readonly property string date: now.toLocaleDateString(locale, dateFormat)

    function formatTime(d: date, f: string): string {
        if (f === "12h") // Qt's "h" is 0..23 without AP
            return `${d.getHours() % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")}`;
        return d.toLocaleTimeString(locale, f === "12h-ampm" ? "h:mm AP" : "HH:mm");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: Env.fakeClock === ""
    }
}
