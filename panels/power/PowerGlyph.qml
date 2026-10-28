import QtQuick
import qs.widgets

// Lucide glyph (ISC, lucide.dev) like panels/launcher/Glyph: the power menu's own shapes
// here, every other name from widgets/Icons (lock, moon, power, search).
Item {
    id: root

    property string name: ""
    property color color: "white"
    property real size: 20
    property real stroke: 2

    readonly property var bodies: ({
            "log-out": '<path d="m16 17 5-5-5-5"/><path d="M21 12H9"/><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>',
            "rotate-cw": '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>',
            "cpu": '<path d="M12 20v2"/><path d="M12 2v2"/><path d="M17 20v2"/><path d="M17 2v2"/><path d="M2 12h2"/><path d="M2 17h2"/><path d="M2 7h2"/><path d="M20 12h2"/><path d="M20 17h2"/><path d="M20 7h2"/><path d="M7 20v2"/><path d="M7 2v2"/><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="8" y="8" width="8" height="8" rx="1"/>'
        })

    function url(): string {
        const body = bodies[name] ?? Icons.bodies[name];
        if (body === undefined)
            return "";
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="${Icons.hex(color)}" stroke-opacity="${color.a}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;
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
