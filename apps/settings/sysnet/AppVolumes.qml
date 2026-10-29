import QtQuick
import qs.config
import qs.widgets
import qs.services
import qs.apps.settings

// Bare custom row (System > Sound > Applications): the volume of every app that plays right
// now (Pipewire playback streams, services/Mixer, like the control center's sound sheet):
// app icon, name, percentage, slider. A click on the icon mutes the app (red badge).
// The page binds the streams (PwObjectTracker) while it shows. LUXSHELL_FAKE_MIXER=1: demo apps.
// Keys: Up/Down walk the apps, Left/Right 5 %, Enter/Space mute.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var opt: null
    property var row: null
    property var host: null
    readonly property var items: Mixer.streams
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && items.length > 0 ? cur : -1

    function navigate(d: int, mods: int): bool {
        const c = cur + d;
        if (c < 0 || c >= items.length)
            return false;
        cur = c;
        return true;
    }
    function enter(d: int): void {
        cur = d > 0 ? 0 : Math.max(0, items.length - 1);
    }
    function adjust(d: int): bool {
        const n = items[cur];
        if (!n?.audio)
            return false;
        Mixer.setVolume(n, Math.round((n.audio.volume + d * 0.05) * 20) / 20);
        return true;
    }
    function activate(): bool {
        const n = items[cur];
        if (n)
            Mixer.toggleMute(n);
        return true;
    }
    function focusRect(): var {
        return {
            "y": cur * root.s.appLine,
            "h": root.s.appLine
        };
    }
    function focusMe(i: int): void {
        cur = i;
        if (host && row) {
            host.focusRoot();
            host.focusRow(row.flatIndex);
        }
    }

    Line {
        visible: root.items.length === 0
        first: true
        clickable: false
        glyph: Catalog.glyph(0xF075A) // md-music
        title: "No apps playing"
        sub: "Apps show up here while they play sound"
    }

    Repeater {
        model: root.items

        Item {
            id: app
            required property var modelData
            required property int index
            readonly property bool muted: modelData.audio?.muted ?? false
            readonly property string icon: Mixer.appIcon(modelData)
            width: root.width
            height: root.s.appLine

            Rectangle {
                visible: app.index > 0
                x: root.g.rowInset
                width: parent.width - 2 * root.g.rowInset
                height: 1
                color: root.g.separator
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 13
                color: "transparent"
                border.width: 2
                border.color: root.g.ring
                visible: root.cursor === app.index
            }

            Rectangle {
                id: disc
                x: root.g.rowInset
                anchors.verticalCenter: parent.verticalCenter
                width: root.s.disc
                height: width
                radius: width / 2
                color: discArea.containsMouse ? Theme.mix(root.g.disc, Theme.text, 0.08) : root.g.disc
                Image {
                    visible: app.icon !== ""
                    anchors.centerIn: parent
                    width: root.s.appIcon
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: app.icon
                    asynchronous: true
                    opacity: app.muted ? 0.45 : 1
                }
                MdIcon {
                    visible: app.icon === ""
                    anchors.centerIn: parent
                    glyph: Catalog.glyph(0xF075A) // md-music
                    size: root.s.discIcon
                    color: root.g.icon
                    opacity: app.muted ? 0.45 : 1
                }
                Rectangle {
                    visible: app.muted
                    x: parent.width - width + 3
                    y: parent.height - height + 3
                    width: 18
                    height: 18
                    radius: 9
                    color: root.g.danger
                    MdIcon {
                        anchors.centerIn: parent
                        glyph: Catalog.glyph(0xF0581) // md-volume-off
                        size: 12
                        color: "white"
                    }
                }
                MouseArea {
                    id: discArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.focusMe(app.index);
                        Mixer.toggleMute(app.modelData);
                    }
                }
            }

            SText {
                id: name
                x: disc.x + disc.width + root.s.textGap
                y: 24 - height / 2
                width: pct.x - x - 12
                elide: Text.ElideRight
                text: Mixer.appName(app.modelData)
            }
            SText {
                id: pct
                x: parent.width - root.g.rowInset - width
                y: name.y
                text: app.muted ? "Muted" : `${Math.round((slider.shown ?? 0) * 100)} %`
                color: root.g.value
            }
            SliderCtl {
                id: slider
                x: name.x
                y: 52 - height / 2
                width: parent.width - x - root.g.rowInset
                value: app.modelData.audio?.volume ?? 0
                min: 0
                max: 1
                step: 0.01
                opacity: app.muted ? 0.55 : 1
                onCommit: v => {
                    root.focusMe(app.index);
                    Mixer.setVolume(app.modelData, v);
                }
            }
        }
    }
}
