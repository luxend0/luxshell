import QtQuick
import qs.services

// Current weather (services/Weather: wttr.in every 30 min, cached): glyph + temperature.
GlyphLabel {
    icon: Weather.ready ? Weather.icon : "cloud"
    text: Weather.ready ? Weather.short : "–°"
    Component.onCompleted: Weather.use()
    Component.onDestruction: Weather.release()
}
