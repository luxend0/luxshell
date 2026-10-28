import QtQuick
import qs.config
import qs.services

// Active keyboard layout (services/KbLayout): "DE" or the full name.
GlyphLabel {
    icon: "keyboard"
    text: (Settings.islandKeyboardStyle === "name" ? KbLayout.name : KbLayout.code) || "–"
}
