import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Media chip in row 1 of the hover island (in place of the window title while a player
// has a track, island/bar/BarContent cross-fades the two): cover, title + artist on one
// line, play/pause. Same slot and type as the window title, so the hover layout of the
// video stays intact. Pointer on cover/text: soft highlight, a title that does not fit
// scrolls once; click there = openRequested (media panel). The disc toggles playback.
// textOpacity: the text fades in after the cover while the island opens (like the title).
// t: 1 = hover sizes (video), 0 = collapsed sizes (Theme.widgets) when the layout puts the
// chip into the collapsed island.
Item {
    id: root

    property real textOpacity: 1
    property real t: 1
    property bool interactive: true
    property var screen: null
    signal openRequested

    readonly property var player: Media.active
    readonly property bool paused: !(player?.isPlaying ?? false)
    readonly property QtObject m: Theme.media
    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    function mix(a: real, b: real): real {
        return a + (b - a) * t;
    }
    readonly property real cover: mix(wm.chipCover, m.chipCover)
    readonly property real button: mix(wm.chipButton, m.chipButton)
    readonly property real titleSize: Math.round(mix(wm.titleSize, h.titleSize))

    function textMaxAt(maxW: real, cov: real, btn: real): real {
        return maxW - cov - m.chipGap - m.chipButtonsGap - btn;
    }
    readonly property real textMax: textMaxAt(mix(wm.chipMaxWidth, m.chipMaxWidth), cover, button)
    readonly property real overflow: Math.max(0, line.implicitWidth - textMax)
    // soft text edges blend into whatever is behind them (island or the hover highlight)
    readonly property color edge: Theme.mix(Theme.island, m.chipHover, highlight.opacity)
    // BarWidget contract: width at collapsed / hover sizes
    readonly property real wC: wm.chipCover + m.chipGap + Math.min(measureC.implicitWidth, textMaxAt(wm.chipMaxWidth, wm.chipCover, wm.chipButton)) + m.chipButtonsGap + wm.chipButton
    readonly property real wH: m.chipCover + m.chipGap + Math.min(measureH.implicitWidth, textMaxAt(m.chipMaxWidth, m.chipCover, m.chipButton)) + m.chipButtonsGap + m.chipButton

    implicitWidth: cover + m.chipGap + textBox.width + m.chipButtonsGap + button
    implicitHeight: cover

    // highlight while the pointer is on the open area (cover + text)
    Rectangle {
        id: highlight
        x: -root.m.chipPad
        width: open.width + root.m.chipPad + 4
        height: root.cover + 12
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: root.m.chipHover
        opacity: open.containsMouse ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeIn
            }
        }
    }

    ClippingRectangle {
        id: coverBox
        width: root.cover
        height: width
        anchors.verticalCenter: parent.verticalCenter
        radius: root.m.chipCoverRadius
        color: Theme.surfaceHigh
        opacity: root.paused ? 0.6 : 1
        Behavior on opacity {
            Anim {
                ms: Theme.fadeIn
            }
        }

        Glyph {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            name: "music"
            size: 13
            color: Theme.textSecondary
        }
        Image {
            id: art
            anchors.fill: parent
            source: Media.art(root.player)
            sourceSize.width: root.m.chipCover * 2
            sourceSize.height: root.m.chipCover * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }

    // title + artist; cut off with a soft edge, scrolls once while hovered
    Item {
        id: textBox
        x: coverBox.width + root.m.chipGap
        width: Math.min(line.implicitWidth, root.textMax)
        height: line.height
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        opacity: root.textOpacity

        Row {
            id: line
            x: -root.scroll
            spacing: root.m.chipArtistGap
            Txt {
                text: Media.title(root.player)
                textFormat: Text.PlainText
                font.pixelSize: root.titleSize
                font.weight: Font.DemiBold
            }
            Txt {
                visible: text !== ""
                text: Media.artist(root.player)
                textFormat: Text.PlainText
                color: Theme.textDim
                font.pixelSize: root.titleSize
                font.weight: Font.Medium
            }
        }
        Rectangle {
            visible: root.overflow > 0 && root.scroll < root.overflow - 1
            anchors.right: parent.right
            width: 24
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: root.edge
                }
            }
        }
        Rectangle {
            visible: root.scroll > 1
            width: 24
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: root.edge
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    // title + artist at both sizes (wC / wH)
    Row {
        visible: false
        spacing: root.m.chipArtistGap
        Txt {
            id: measureC
            text: Media.title(root.player) + "  " + Media.artist(root.player)
            textFormat: Text.PlainText
            font.pixelSize: Math.round(root.wm.titleSize)
            font.weight: Font.DemiBold
        }
    }
    Txt {
        id: measureH
        visible: false
        text: Media.title(root.player) + "  " + Media.artist(root.player)
        textFormat: Text.PlainText
        font.pixelSize: Math.round(root.h.titleSize)
        font.weight: Font.DemiBold
    }

    property real scroll: 0
    SequentialAnimation {
        id: marquee
        PauseAnimation {
            duration: Motion.ms(500)
        }
        NumberAnimation {
            target: root
            property: "scroll"
            to: root.overflow
            duration: Motion.ms(root.overflow / 0.05)
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: Motion.ms(1200)
        }
        NumberAnimation {
            target: root
            property: "scroll"
            to: 0
            duration: Motion.ms(360)
            easing.type: Easing.OutCubic
        }
    }
    // new track: back to the start
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            marquee.stop();
            root.scroll = 0;
        }
    }

    MouseArea {
        id: open
        width: textBox.x + textBox.width
        height: root.cover + 12
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse && root.overflow > 0) {
                marquee.restart();
            } else if (!containsMouse) {
                marquee.stop();
                back.restart();
            }
        }
        onClicked: root.openRequested()
    }
    NumberAnimation {
        id: back
        target: root
        property: "scroll"
        to: 0
        duration: Motion.ms(260)
        easing.type: Easing.OutCubic
    }

    // play / pause
    Rectangle {
        id: toggle
        x: textBox.x + textBox.width + root.m.chipButtonsGap
        width: root.button
        height: width
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: toggleArea.containsMouse ? root.m.pillHover : root.m.pill
        opacity: root.textOpacity
        Behavior on color {
            ColorAnim {
                ms: Theme.fadeIn
            }
        }

        Glyph {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.paused ? 1 : 0
            name: root.paused ? "play" : "pause"
            size: root.m.chipGlyph * root.button / root.m.chipButton
            filled: true
            stroke: 1.5
            color: Theme.text
        }
        MouseArea {
            id: toggleArea
            anchors.fill: parent
            anchors.margins: -4
            enabled: root.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Media.toggle(root.player)
        }
    }
}
