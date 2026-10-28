import QtQuick
import Quickshell.Widgets
import qs.config
import qs.widgets

// Rounded cover with a cross-fade: a new source loads into the hidden slot and fades in
// once it is ready, the old one stays until then (no black flash between tracks).
// `content` (both slots, unclipped) is what the glow in MediaPanel blurs, so the glow
// cross-fades with the cover. No source / load error: music glyph on a dark tile.
ClippingRectangle {
    id: root

    property string source: ""
    property int fade: Theme.media.coverFade
    property real glyphSize: 40
    readonly property alias content: slots
    readonly property bool ready: !empty && (useA ? a : b).status === Image.Ready
    readonly property bool empty: source === ""

    property bool useA: true

    color: Theme.surfaceHigh

    onSourceChanged: {
        if (source === "") // not `empty`: that binding may not have seen the change yet
            return;
        const next = useA ? b : a;
        if (next.source.toString() === source && next.status === Image.Ready)
            useA = !useA;
        else
            next.source = source;
    }
    Component.onCompleted: a.source = source

    Glyph {
        anchors.centerIn: parent
        visible: !root.ready
        name: "music"
        size: root.glyphSize
        color: Theme.textDim
    }

    Item {
        id: slots
        anchors.fill: parent
        opacity: root.empty ? 0 : 1

        component Slot: Image {
            property bool shown: false
            anchors.fill: parent
            sourceSize.width: Math.round(root.width * 2)
            sourceSize.height: Math.round(root.height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
            opacity: shown && status === Image.Ready ? 1 : 0
            Behavior on opacity {
                Anim {
                    ms: root.fade
                }
            }
        }

        Slot {
            id: a
            shown: root.useA
            onStatusChanged: if (status === Image.Ready && !root.useA && source.toString() === root.source)
                root.useA = true
        }
        Slot {
            id: b
            shown: !root.useA
            onStatusChanged: if (status === Image.Ready && root.useA && source.toString() === root.source)
                root.useA = false
        }
    }
}
