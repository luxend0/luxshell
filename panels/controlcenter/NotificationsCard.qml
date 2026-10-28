import QtQuick
import qs.config
import qs.services

// Lower card of ref/08. Live list from services/Notifs when its server runs;
// otherwise LUXSHELL_FAKE_NOTIFS=<n> shows n sample entries (dismissable locally).
Rectangle {
    id: card

    readonly property var samples: [
        {
            "appName": "Vesktop",
            "appIcon": "vesktop",
            "summary": "ok0x",
            "body": "node02 is back, latency looks normal again"
        },
        {
            "appName": "Firefox",
            "appIcon": "firefox",
            "summary": "Download complete",
            "body": "archlinux-2026.10.01-x86_64.iso"
        },
        {
            "appName": "Spotify",
            "appIcon": "spotify",
            "summary": "Now playing",
            "body": "Bonobo - Kerala"
        },
        {
            "appName": "System",
            "appIcon": "",
            "summary": "Updates available",
            "body": "14 packages can be upgraded"
        }
    ]
    property var fake: []
    // Notifs.entries (newest first) mapped to the row fields; `key` identifies the entry
    readonly property var items: Notifs.live ? Notifs.entries.map(e => ({
                "key": e.key,
                "appName": e.app,
                "appIcon": e.icon,
                "image": e.image,
                "summary": e.summary,
                "body": e.body
            })) : fake

    // fake entries are plain objects; a JS array model hands out copies, so go by index
    function dismiss(n, index: int) {
        const wasCurrent = Cc.current && Cc.current === list.itemAtIndex(index);
        if (Notifs.live)
            Notifs.dismiss(n.key);
        else
            fake = fake.filter((x, i) => i !== index);
        // keep the keyboard selection in the list instead of losing it
        if (wasCurrent)
            Qt.callLater(() => Cc.current = list.itemAtIndex(Math.min(index, list.count - 1)) ?? clear);
    }
    function invoke(n, index: int) {
        if (Notifs.live)
            Notifs.invoke(n.key, "default");
        dismiss(n, index);
    }
    function clearAll() {
        if (Notifs.live)
            Notifs.clear();
        else
            fake = [];
    }

    Component.onCompleted: {
        if (Notifs.live)
            return;
        const out = [];
        for (let i = 0; i < Notifs.count; i++)
            out.push(Object.assign({}, samples[i % samples.length]));
        fake = out;
    }

    radius: Theme.cc.cardRadius
    color: Theme.surface
    border.width: 1
    border.color: Theme.cc.stroke


    CapText {
        x: Theme.cc.labelX
        capY: 25.5
        text: "Notifications"
        font.pixelSize: Theme.cc.captionSize
        color: Theme.textDim
    }

    PillButton {
        id: clear
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 9
        height: 30
        visible: card.items.length > 0
        focusable: true
        text: "Clear"
        onClicked: card.clearAll()
    }

    CapText {
        x: Theme.cc.labelX
        capY: 57.5
        visible: card.items.length === 0
        text: "No notifications"
        font.pixelSize: Theme.cc.bodySize
        color: Theme.textDim
    }

    ListView {
        id: list
        x: 8
        y: 48
        width: card.width - 16
        height: card.height - y - 8
        clip: true
        spacing: 6
        visible: count > 0
        model: card.items
        boundsBehavior: Flickable.StopAtBounds
        delegate: NotifRow {
            onDismiss: card.dismiss(modelData, index)
            onInvoke: card.invoke(modelData, index)
        }
    }

}
