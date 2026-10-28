import QtQuick
import qs.config
import qs.widgets

// Text of the settings app: Theme font, size scaled by Settings "Font size" (Theme.fontScale).
Txt {
    property real size: Theme.settings.textSize

    font.pixelSize: Math.round(size * Theme.fontScale)
    font.weight: Font.Medium // the video's labels read medium (widths match Inter 17 regular/medium)
    color: Theme.settings.label
}
