import QtQuick
import qs.services

// CPU load or memory in use (services/Sysmon, /proc every 2..10 s while shown).
GlyphLabel {
    property string kind: "cpu"
    icon: kind === "ram" ? "memory-stick" : "cpu"
    text: Sysmon.ready || kind === "ram" ? `${Math.round((kind === "ram" ? Sysmon.ram : Sysmon.cpu) * 100)}%` : "–%"
    Component.onCompleted: Sysmon.use()
    Component.onDestruction: Sysmon.release()
}
