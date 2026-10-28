import QtQuick
import Quickshell.Widgets
import qs.config
import qs.widgets
import qs.panels.controlcenter

// One notification in the notification center (panels/NotificationCenter.qml).
//
//   title line   summary (one line, wraps when unfolded) | unfold chevron | time ("now", "5m")
//                with a dot when it was unread as the center opened; pointer / keyboard on
//                the card: the time gives way to an x
//   body         two lines, unfolds (chevron, Space, Right)
//   image        square (avatar, cover): left of the text like a messenger; wide (screenshot):
//                thumbnail at the right of the body, unfolded full width below the text
//   actions      the notification's buttons while it is alive
//   stack        layers > 0: the group's older cards as edges below it (folded group)
//
// Sizes: targetHeight is the resting height (the center sums those for the island);
// the drawn box and the stack edges animate towards it (Theme.nc.move, emphasized), so
// rows below slide in step with the island. Drag sideways or the x: flies out, then
// `dismissed` (the center removes the entry). Click: `activated` (default action, or the
// center unfolds a stack).
Item {
    id: card

    property var entry: null
    property double now: Date.now()
    property bool fresh: false       // unread when the center opened
    property int layers: 0           // older cards behind it (folded group)
    property bool selected: false    // keyboard selection
    property int actionSel: -1       // keyboard: selected action pill, -1 = the card itself
    property bool open: false        // text + image unfolded

    signal activated
    signal dismissed
    signal action(string id)

    readonly property QtObject nc: Theme.nc
    readonly property var actions: entry && entry.alive ? entry.actions.slice(0, 3) : []
    readonly property bool hasImage: (entry?.image ?? "") !== ""
    // the image's shape decides where it goes (probe below); until it is known: thumbnail
    readonly property real aspect: probe.status === Image.Ready && probe.implicitHeight > 0 ? probe.implicitWidth / probe.implicitHeight : 0
    readonly property bool lead: hasImage && aspect > 0 && aspect <= nc.leadAspect && aspect >= 1 / nc.leadAspect && !leadIcon.failed
    readonly property bool wide: hasImage && !lead
    readonly property bool canOpen: open || body.truncated || title.truncated || (wide && probe.status === Image.Ready)
    readonly property bool hot: hover.hovered || selected
    readonly property real cardH: Math.ceil(Math.max(content.implicitHeight, lead ? 2 * nc.padY + nc.lead : 0))
    readonly property real stackH: Math.min(layers, nc.stackLayers) * nc.stackPeek
    readonly property real targetHeight: cardH + stackH

    function ago(t: double): string {
        const s = Math.max(0, (now - t) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return `${Math.floor(s / 86400)}d`;
    }

    Image {
        id: probe
        visible: false
        source: card.hasImage ? card.entry.image : ""
        sourceSize.width: 64
        sourceSize.height: 64
        asynchronous: true
    }

    // ---- animated geometry --------------------------------------------------------------
    property bool settled: false
    property real boxH: cardH
    property real stackShown: stackH
    Behavior on boxH {
        enabled: card.settled
        NumberAnimation {
            duration: Motion.ms(card.nc.move)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.emphasized
        }
    }
    Behavior on stackShown {
        enabled: card.settled
        NumberAnimation {
            duration: Motion.ms(card.nc.move)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.emphasized
        }
    }
    Component.onCompleted: Qt.callLater(() => card.settled = true)

    implicitHeight: boxH + stackShown

    // ---- swipe ------------------------------------------------------------------------------
    property real dx: 0
    function flyAway(dir: int): void {
        if (fly.running)
            return;
        flyTo.to = (dir < 0 ? -1 : 1) * (card.width + 40);
        fly.start();
    }
    NumberAnimation {
        id: springBack
        target: card
        property: "dx"
        to: 0
        duration: Motion.ms(260)
        easing.type: Easing.OutBack
    }
    SequentialAnimation {
        id: fly
        NumberAnimation {
            id: flyTo
            target: card
            property: "dx"
            duration: Motion.ms(card.nc.fly)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: card.dismissed()
        }
    }

    // ---- stack edges (behind the card) ------------------------------------------------------
    readonly property real stackK: stackShown / nc.stackPeek
    Repeater {
        model: card.nc.stackLayers

        Rectangle {
            required property int index
            readonly property real k: Math.max(0, Math.min(1, card.stackK - index))
            x: card.dx + card.nc.stackInset * (index + 1)
            width: card.width - 2 * card.nc.stackInset * (index + 1)
            height: 2 * card.nc.cardRadius
            y: card.boxH - height + Math.min(card.stackK, index + 1) * card.nc.stackPeek
            z: -1 - index
            radius: card.nc.cardRadius
            color: index === 0 ? card.nc.layer1 : card.nc.layer2
            border.width: 1
            border.color: index === 0 ? card.nc.layerStroke1 : card.nc.layerStroke2
            opacity: k * box.opacity
            visible: opacity > 0.001

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: parent.height - card.nc.stackPeek * 1.5
                cursorShape: Qt.PointingHandCursor
                onClicked: card.activated()
            }
        }
    }

    // ---- card ------------------------------------------------------------------------------
    Item {
        id: box
        x: card.dx
        width: card.width
        height: card.boxH
        opacity: 1 - 0.85 * Math.min(1, Math.abs(card.dx) / card.width)

        HoverHandler {
            id: hover
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: card.nc.cardRadius
            color: hover.hovered ? card.nc.cardHover : card.nc.card
            border.width: 1
            border.color: (card.entry?.urgency ?? 1) === 2 ? card.nc.strokeCritical : card.nc.stroke
            Behavior on color {
                ColorAnim {
                    ms: Theme.fadeOut
                }
            }
        }
        NcRing {
            target: bg
            shown: card.selected && card.actionSel < 0
        }

        // click / middle click / sideways drag; buttons inside sit above it
        MouseArea {
            id: area
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: (card.entry?.hasDefault && card.entry?.alive) || card.layers > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

            property real startX: 0
            property real startY: 0
            property bool dragging: false

            onPressed: m => {
                const p = mapToItem(card, m.x, m.y);
                startX = p.x;
                startY = p.y;
                dragging = false;
                springBack.stop();
            }
            onPositionChanged: m => {
                const p = mapToItem(card, m.x, m.y);
                const ddx = p.x - startX;
                if (!dragging && Math.abs(ddx) > 8 && Math.abs(ddx) > Math.abs(p.y - startY)) {
                    dragging = true;
                    preventStealing = true; // the list must not turn it into a scroll
                }
                if (dragging)
                    card.dx = ddx;
            }
            onReleased: {
                preventStealing = false;
                if (!dragging)
                    return;
                if (Math.abs(card.dx) > card.width * card.nc.swipeAt)
                    card.flyAway(card.dx);
                else
                    springBack.start();
            }
            onCanceled: {
                preventStealing = false;
                if (dragging)
                    springBack.start();
                dragging = false;
            }
            onClicked: m => {
                if (dragging)
                    return;
                if (m.button === Qt.MiddleButton)
                    card.flyAway(1);
                else
                    card.activated();
            }
        }

        Item {
            anchors.fill: parent
            clip: true // the box grows / shrinks around the unfolded content

            AppIcon {
                id: leadIcon
                x: card.nc.padX
                y: card.nc.padY + 1
                visible: card.lead
                size: card.nc.lead
                source: card.hasImage ? card.entry.image : ""
                picture: true
            }

            Column {
                id: content
                x: card.nc.padX + (card.lead ? card.nc.lead + card.nc.leadGap : 0)
                width: box.width - x - card.nc.padX
                topPadding: card.nc.padY
                bottomPadding: card.nc.padY

                // title | chevron | time / x
                Item {
                    id: titleRow
                    width: parent.width
                    height: title.implicitHeight

                    FontMetrics {
                        id: titleFont
                        font: title.font
                    }
                    readonly property real lineCy: titleFont.height / 2

                    Txt {
                        id: title
                        width: parent.width - cluster.width - 12
                        text: card.entry?.summary ?? ""
                        textFormat: Text.PlainText
                        wrapMode: card.open ? Text.Wrap : Text.NoWrap
                        maximumLineCount: card.open ? 3 : 1
                        elide: Text.ElideRight
                        color: Theme.text
                        font.pixelSize: card.nc.cardTitleSize
                        font.weight: Font.DemiBold
                    }

                    Row {
                        id: cluster
                        anchors.right: parent.right
                        anchors.rightMargin: -6
                        y: titleRow.lineCy - height / 2
                        spacing: 6

                        NcChip {
                            id: unfold
                            visible: card.canOpen
                            icon: card.open ? "chevron-up" : "chevron-down"
                            onClicked: card.open = !card.open
                        }

                        Item {
                            id: slot
                            width: Math.max(stamp.implicitWidth, close.width)
                            height: close.height

                            Row {
                                id: stamp
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                opacity: card.hot ? 0 : 1
                                Behavior on opacity {
                                    Anim {
                                        ms: Theme.fadeOut
                                    }
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: card.fresh
                                    width: card.nc.dot
                                    height: width
                                    radius: width / 2
                                    color: Theme.text
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: card.entry ? card.ago(card.entry.time) : ""
                                    color: Theme.textDim
                                    font.pixelSize: card.nc.timeSize
                                    font.weight: Font.Medium
                                }
                            }
                            NcChip {
                                id: close
                                anchors.right: parent.right
                                icon: "x"
                                hot: card.selected && card.actionSel < 0
                                opacity: card.hot ? 1 : 0
                                visible: opacity > 0.001
                                Behavior on opacity {
                                    Anim {
                                        ms: Theme.fadeOut
                                    }
                                }
                                onClicked: card.flyAway(1)
                            }
                        }
                    }
                }

                // body | thumbnail
                Item {
                    id: bodyRow
                    readonly property bool hasBody: body.text !== ""
                    width: parent.width
                    visible: hasBody || thumb.visible
                    height: visible ? card.nc.bodyGap + Math.max(hasBody ? body.implicitHeight : 0, thumb.visible ? thumb.height : 0) : 0

                    Txt {
                        id: body
                        y: card.nc.bodyGap
                        width: parent.width - (thumb.visible ? thumb.width + card.nc.thumbGap : 0)
                        visible: text !== ""
                        text: card.entry?.body ?? ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: card.open ? card.nc.bodyLinesOpen : card.nc.bodyLines
                        elide: Text.ElideRight
                        lineHeight: card.nc.bodyLineHeight
                        color: Theme.textSecondary
                        font.pixelSize: card.nc.bodySize
                    }
                    AppIcon {
                        id: thumb
                        anchors.right: parent.right
                        y: card.nc.bodyGap + 2
                        visible: card.wide && !card.open && !failed
                        size: card.nc.thumb
                        source: card.entry?.image ?? ""
                        picture: true
                    }
                }

                // unfolded: the image, full width
                Item {
                    width: parent.width
                    visible: card.open && card.wide && big.status === Image.Ready
                    height: visible ? card.nc.imageGap + frame.height : 0

                    ClippingRectangle {
                        id: frame
                        y: card.nc.imageGap
                        width: parent.width
                        height: big.implicitWidth > 0 ? Math.min(card.nc.imageMaxHeight, Math.round(width * big.implicitHeight / big.implicitWidth)) : 0
                        radius: card.nc.imageRadius
                        color: Theme.surfaceHigh

                        Image {
                            id: big
                            anchors.fill: parent
                            source: card.open && card.wide ? card.entry.image : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            mipmap: true
                        }
                    }
                }

                // action pills
                Item {
                    width: parent.width
                    visible: card.actions.length > 0
                    height: visible ? card.nc.actionsTop + card.nc.actionHeight : 0

                    Row {
                        y: card.nc.actionsTop
                        spacing: card.nc.actionGap

                        Repeater {
                            model: card.actions

                            PillButton {
                                id: pill
                                required property var modelData
                                required property int index
                                height: card.nc.actionHeight
                                text: modelData.text
                                textSize: card.nc.actionSize
                                padX: 16
                                baseColor: card.selected && card.actionSel === index ? Theme.mix(card.nc.action, Theme.text, 0.1) : card.nc.action
                                onClicked: card.action(modelData.id)

                                NcRing {
                                    shown: card.selected && card.actionSel === pill.index
                                    gap: 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
