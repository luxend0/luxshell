import QtQuick
import qs.widgets

// Lucide glyph (ISC, lucide.dev) like widgets/Icon, plus the few launcher-only
// shapes; names Icons.qml already knows are taken from there.
Item {
    id: root

    property string name: ""
    property color color: "white"
    property real size: 20
    property real stroke: 2

    readonly property var bodies: ({
            "terminal": '<path d="M12 19h8"/><path d="m4 17 6-6-6-6"/>',
            "calculator": '<rect width="16" height="20" x="4" y="2" rx="2"/><line x1="8" x2="16" y1="6" y2="6"/><line x1="16" x2="16" y1="14" y2="18"/><path d="M16 10h.01"/><path d="M12 10h.01"/><path d="M8 10h.01"/><path d="M12 14h.01"/><path d="M8 14h.01"/><path d="M12 18h.01"/><path d="M8 18h.01"/>',
            "globe": '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
            "history": '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l4 2"/>'
        })

    function url(): string {
        const body = bodies[name] ?? Icons.bodies[name];
        if (body === undefined)
            return "";
        const col = Icons.hex(color);
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="${col}" stroke-opacity="${color.a}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        source: root.url()
        sourceSize.width: Math.max(1, Math.round(root.size))
        sourceSize.height: Math.max(1, Math.round(root.size))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
