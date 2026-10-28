import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets

// Notification as a two-stage live activity (registry kind "overlay", id "notif";
// the queue and timing live in services/Notifs.qml).
//
//   compact  IN the bar: same height as the collapsed island, a little wider; app
//            icon (count badge when the app has more), title next to it (body preview
//            dimmed behind it); a line that does not fit scrolls once (marquee)
//   card     hover (short dwell) or click: full card with app, time, title, body,
//            image, actions and the app's older notifications (grouped)
//
// Drag up hides it (stays in the history, see Notifs.swipe), the x on the card
// dismisses it for good. Click on the card runs the notification's default action.
PanelBase {
    id: root

    readonly property QtObject p: Theme.peek
    readonly property QtObject c: Theme.card

    // the entry on screen, kept while the overlay fades out (Notifs.peek is null then)
    property var entry: null
    readonly property var src: probe ? null : Notifs.peek
    onSrcChanged: take()
    Component.onCompleted: take()

    function take(): void {
        if (!src)
            return;
        const newGroup = !entry || entry.group !== src.group;
        const newKey = !entry || entry.key !== src.key;
        entry = src;
        if (newKey) {
            drag = 0;
            fly.stop();
            if (newGroup)
                enterAnim.restart();
            titleAnim.restart();
        }
    }

    readonly property bool expanded: !probe && Notifs.expanded && entry !== null
    property real ep: expanded ? 1 : 0
    Behavior on ep {
        Anim {
            ms: root.c.expand
        }
    }

    readonly property int badge: entry ? Notifs.groupCount(entry.group) : 0
    readonly property var older: entry ? Notifs.groupEntries(entry.group).filter(e => e.key !== entry.key) : []

    readonly property real compactWidth: Math.round(Math.max(p.minWidth, Math.min(p.maxWidth, p.padLeft + p.iconSize + p.gap + titleMetrics.advanceWidth + (preview !== "" ? 9 + previewMetrics.advanceWidth : 0) + p.padRight)))

    preferredWidth: expanded ? c.width : compactWidth
    // dragging the card up shrinks the island with it
    preferredHeight: expanded ? Math.max(p.height, Math.min(c.maxHeight, Math.ceil(card.implicitHeight)) + Math.min(0, Math.round(drag))) : p.height
    cornerRadius: expanded ? c.radius : p.radius
    maxWidth: c.width
    maxHeight: c.maxHeight

    // ---- entrance: icon pops, title slides in ---------------------------------------
    property real enter: 1
    property real titleIn: 1
    NumberAnimation {
        id: enterAnim
        target: root
        property: "enter"
        from: 0
        to: 1
        duration: Motion.ms(root.p.enter)
        easing.type: Easing.OutBack
        easing.overshoot: 1.4
    }
    SequentialAnimation {
        id: titleAnim
        ScriptAction {
            script: {
                root.titleIn = 0;
                root.marquee = 0;
            }
        }
        PauseAnimation {
            duration: Motion.ms(80)
        }
        NumberAnimation {
            target: root
            property: "titleIn"
            to: 1
            duration: Motion.ms(root.p.enter)
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: Motion.ms(root.p.marqueeDelay)
        }
        NumberAnimation {
            target: root
            property: "marquee"
            to: root.overflow
            duration: Motion.ms(root.overflow / root.p.marqueeSpeed)
            easing.type: Easing.InOutSine
        }
    }

    // ---- drag up = hide -------------------------------------------------------------
    property real drag: 0
    readonly property real dismissAt: expanded ? c.dismissDrag : p.dismissDrag
    readonly property real dragFade: 1 - Math.min(1, -drag / (dismissAt * 2.4))
    NumberAnimation {
        id: springBack
        target: root
        property: "drag"
        to: 0
        duration: Motion.ms(260)
        easing.type: Easing.OutBack
    }
    SequentialAnimation {
        id: fly
        NumberAnimation {
            target: root
            property: "drag"
            to: -Math.min(root.height, root.dismissAt * 2) // the overlay fade takes it from there
            duration: Motion.ms(120)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: Notifs.swipe()
        }
    }

    Connections {
        target: Notifs
        enabled: !root.probe
        function onSwipeRequested() {
            fly.start();
        }
    }

    // ---- pointer: hover expands, leaving folds back -------------------------------------
    HoverHandler {
        id: hover
        enabled: !root.probe
        onHoveredChanged: {
            if (hovered) {
                leave.stop();
                Notifs.hold(true);
                dwell.restart();
            } else {
                dwell.stop();
                leave.restart();
            }
        }
    }
    Timer {
        id: dwell
        interval: Motion.ms(200)
        onTriggered: Notifs.setExpanded(true)
    }
    Timer {
        id: leave
        interval: Motion.ms(Theme.hoverHold)
        onTriggered: {
            if (Notifs.expanded)
                Notifs.setExpanded(false);
            else
                Notifs.hold(false);
        }
    }

    // below the content, so card buttons win; also keeps clicks from the island (control center)
    MouseArea {
        anchors.fill: parent
        property real startY: 0
        property bool dragging: false
        onPressed: m => {
            startY = m.y;
            dragging = false;
            springBack.stop();
        }
        onPositionChanged: m => {
            const dy = m.y - startY;
            if (!dragging && Math.abs(dy) > 6)
                dragging = true;
            if (dragging)
                root.drag = Math.min(0, dy) + Math.max(0, dy) * 0.12; // rubber band downwards
        }
        onReleased: {
            if (!dragging)
                return;
            if (root.drag < -root.dismissAt)
                fly.start();
            else
                springBack.start();
        }
        onClicked: {
            if (dragging || !root.entry)
                return;
            if (!root.expanded)
                Notifs.setExpanded(true);
            else if (root.entry.hasDefault && root.entry.alive)
                Notifs.invoke(root.entry.key, "default");
        }
    }

    // ---- compact --------------------------------------------------------------------------
    readonly property string preview: (entry?.body ?? "").replace(/\s+/g, " ").trim().slice(0, 140)
    TextMetrics {
        id: titleMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.p.titleSize
        font.weight: Font.Medium
        text: root.entry?.summary ?? ""
    }
    TextMetrics {
        id: previewMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.p.titleSize
        text: root.preview
    }
    property real marquee: 0
    readonly property real overflow: Math.max(0, title.implicitWidth - titleBox.width)

    Item {
        id: compact
        width: root.compactWidth
        height: root.p.height
        x: (root.width - width) / 2
        y: root.drag
        // out in the first part of the expand, so it never overlaps the card header
        opacity: (1 - Motion.smooth(root.ep, [0, 0.4])) * root.dragFade
        visible: opacity > 0.001
        readonly property real cy: Theme.collapsed.centerY + 1

        AppIcon {
            id: cIcon
            x: root.p.padLeft
            y: compact.cy - height / 2
            size: root.p.iconSize
            source: root.entry?.icon ?? ""
            picture: root.entry?.picture ?? false
            scale: 0.35 + 0.65 * root.enter
            opacity: Math.min(1, root.enter * 1.5)
        }
        Rectangle {
            visible: root.badge > 1
            x: cIcon.x + cIcon.width - width / 2
            y: cIcon.y - height / 2 + 3
            width: Math.max(height, badgeText.implicitWidth + 8)
            height: root.p.badgeSize + 4
            radius: height / 2
            color: Theme.accent
            border.width: 2
            border.color: Theme.island
            scale: cIcon.scale
            Txt {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge > 99 ? "99+" : root.badge
                color: Theme.onAccent
                font.pixelSize: root.p.badgeTextSize
                font.weight: Font.Bold
            }
        }

        Item {
            id: titleBox
            x: cIcon.x + root.p.iconSize + root.p.gap + (root.badge > 1 ? 3 : 0)
            width: compact.width - x - root.p.padRight + 6
            height: title.height
            y: compact.cy - height / 2
            clip: true
            opacity: root.titleIn

            // title, then a dim preview of the body on the same line
            Row {
                id: title
                x: -root.marquee + (1 - root.titleIn) * 14
                spacing: 9
                Txt {
                    text: root.entry?.summary ?? ""
                    textFormat: Text.PlainText
                    font.pixelSize: root.p.titleSize
                    font.weight: Font.Medium
                }
                Txt {
                    visible: text !== ""
                    text: root.preview
                    textFormat: Text.PlainText
                    color: Theme.textDim
                    font.pixelSize: root.p.titleSize
                }
            }
            // soft edges while the title is cut off
            Rectangle {
                visible: root.overflow > 0 && root.marquee < root.overflow - 1
                anchors.right: parent.right
                width: 22
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Theme.island
                    }
                }
            }
            Rectangle {
                visible: root.marquee > 1
                width: 22
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.island
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }
        }
    }

    // ---- card -----------------------------------------------------------------------------
    property double now: Date.now()
    Timer {
        running: root.expanded
        repeat: true
        interval: 30000
        onTriggered: root.now = Date.now()
    }
    function ago(t: double): string {
        const s = (now - t) / 1000;
        return s < 60 ? "now" : s < 3600 ? `${Math.floor(s / 60)}m ago` : `${Math.floor(s / 3600)}h ago`;
    }

    Item {
        id: cardBox
        width: root.c.width
        height: card.implicitHeight
        x: (root.width - width) / 2
        y: root.drag
        opacity: Motion.smooth(root.ep, [0.3, 1]) * root.dragFade
        enabled: root.expanded

        Column {
            id: card
            x: root.c.pad
            width: parent.width - 2 * root.c.pad
            topPadding: root.c.pad - 2
            bottomPadding: root.c.pad
            spacing: 12

            // app, time, close
            Item {
                width: parent.width
                height: root.c.iconSize

                AppIcon {
                    id: hIcon
                    size: root.c.iconSize
                    source: root.entry?.icon ?? ""
                    picture: root.entry?.picture ?? false
                }
                Txt {
                    anchors.left: hIcon.right
                    anchors.leftMargin: 10
                    anchors.right: close.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.entry ? `${root.entry.app}  ·  ${root.ago(root.entry.time)}` : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font.pixelSize: root.c.appSize
                    font.weight: Font.Medium
                }
                IconButton {
                    id: close
                    anchors.right: parent.right
                    anchors.rightMargin: -6
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "x"
                    size: 16
                    restOpacity: 0.55
                    onClicked: Notifs.dismiss(root.entry.key)
                }
            }

            // title, body, image
            Item {
                width: parent.width
                height: Math.max(texts.implicitHeight, image.visible ? image.height : 0)

                Column {
                    id: texts
                    width: parent.width - (image.visible ? image.width + 16 : 0)
                    spacing: 5

                    Txt {
                        width: parent.width
                        text: root.entry?.summary ?? ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: root.c.titleSize
                        font.weight: Font.DemiBold
                    }
                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: root.entry?.body ?? ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: root.c.bodyLines
                        elide: Text.ElideRight
                        lineHeight: 1.12
                        color: Theme.textSecondary
                        font.pixelSize: root.c.bodySize
                    }
                }
                AppIcon {
                    id: image
                    anchors.right: parent.right
                    visible: (root.entry?.image ?? "") !== "" && !failed
                    size: root.c.imageSize
                    source: root.entry?.image ?? ""
                    picture: true
                }
            }

            // actions
            Row {
                visible: (root.entry?.actions.length ?? 0) > 0 && root.entry.alive
                spacing: 8

                Repeater {
                    model: root.entry?.actions.slice(0, 3) ?? []

                    Rectangle {
                        id: action
                        required property var modelData
                        width: actionText.implicitWidth + 32
                        height: root.c.actionHeight
                        radius: height / 2
                        color: actionArea.containsMouse ? root.c.actionHover : root.c.action
                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.ms(Theme.fadeOut)
                            }
                        }
                        Txt {
                            id: actionText
                            anchors.centerIn: parent
                            text: action.modelData.text
                            textFormat: Text.PlainText
                            font.pixelSize: root.c.actionSize
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Notifs.invoke(root.entry.key, action.modelData.id)
                        }
                    }
                }
            }

            // the app's older notifications
            Column {
                visible: root.older.length > 0
                width: parent.width
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.c.separator
                }
                Item {
                    width: parent.width
                    height: 30
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.older.length === 1 ? "1 more from " + (root.entry?.app ?? "") : `${root.older.length} more from ${root.entry?.app ?? ""}`
                        textFormat: Text.PlainText
                        color: Theme.textDim
                        font.pixelSize: root.c.appSize
                        font.weight: Font.Medium
                    }
                    Txt {
                        id: clearAll
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear all"
                        color: clearArea.containsMouse ? Theme.text : Theme.textDim
                        font.pixelSize: root.c.appSize
                        font.weight: Font.Medium
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            onClicked: Notifs.clearGroup(root.entry.group)
                        }
                    }
                }
                Repeater {
                    model: root.older.slice(0, root.c.groupRows)

                    Item {
                        id: row
                        required property var modelData
                        width: card.width
                        height: 26
                        Txt {
                            id: rowTitle
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.5)
                            text: row.modelData.summary
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: root.c.rowSize
                            font.weight: Font.Medium
                        }
                        Txt {
                            anchors.left: rowTitle.right
                            anchors.leftMargin: 10
                            anchors.right: rowTime.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.body.replace(/\s+/g, " ")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font.pixelSize: root.c.rowSize
                        }
                        Txt {
                            id: rowTime
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.ago(row.modelData.time)
                            color: Theme.textDim
                            font.pixelSize: root.c.rowSize - 1
                        }
                    }
                }
            }
        }
    }
}
