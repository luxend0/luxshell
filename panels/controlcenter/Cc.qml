pragma Singleton
import QtQuick
import Quickshell

// Shared control-center keyboard state. The panel root keeps the real keyboard
// focus the whole time (moving Qt focus between items makes Qt's Wayland
// text-input warn on every step); the selected control is `current`, rings show
// only after a key was pressed (kb) and the pointer moving clears that again.
//
// A control is any item with `readonly property bool ccControl: true` and a
// `function key(k: int): bool` that handles Enter/Space/etc. (true = consumed).
Singleton {
    id: root

    property bool kb: false
    property Item current: null

    function isCurrent(item: Item): bool {
        return kb && current === item;
    }
}
