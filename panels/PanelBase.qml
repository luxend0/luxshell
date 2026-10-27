import QtQuick
import qs.config
import qs.core

// Contract every panel implements. The island reads preferredWidth/Height and
// cornerRadius (they may change at runtime, the island follows), sets `active`
// while the panel is the visible one and gives it keyboard focus.
// Close yourself with Ui.close(); Esc is handled by the host.
//
// maxWidth/maxHeight: the largest size the panel can ever ask for. Panels whose
// size follows their content (launcher results, sub pages) set them; the registry
// probes them once at start (probe: true, never shown) to size the layer surface.
FocusScope {
    id: root

    property string panelId: ""
    property int preferredWidth: 600
    property int preferredHeight: 400
    property int maxWidth: preferredWidth
    property int maxHeight: preferredHeight
    property int cornerRadius: Theme.panelRadius
    property bool active: false
    property bool probe: false

    // override to focus a specific child (e.g. a search field)
    function focusDefault() {
        forceActiveFocus();
    }
    function report() {
        if (!probe)
            Panels.report(Math.max(preferredWidth, maxWidth), Math.max(preferredHeight, maxHeight));
    }

    width: preferredWidth
    height: preferredHeight
    focus: true

    onActiveChanged: if (active)
        focusDefault()
    onPreferredWidthChanged: report()
    onPreferredHeightChanged: report()
    Component.onCompleted: report()
}
