import QtQuick
import qs.config

// Contract every panel implements. The island reads preferredWidth/Height and
// cornerRadius (they may change at runtime, the island follows), sets `active`
// while the panel is the visible one and gives it keyboard focus.
// Close yourself with Ui.close(); Esc is handled by the host.
FocusScope {
    id: root

    property string panelId: ""
    property int preferredWidth: 600
    property int preferredHeight: 400
    property int cornerRadius: Theme.panelRadius
    property bool active: false

    // override to focus a specific child (e.g. a search field)
    function focusDefault() {
        forceActiveFocus();
    }

    width: preferredWidth
    height: preferredHeight
    focus: true

    onActiveChanged: if (active)
        focusDefault()
}
