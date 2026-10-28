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
Item {
    id: root

    property real textOpacity: 1
    signal openRequested

    readonly property var player: Media.active
    readonly property bool paused: !(player?.isPlaying ?? false)
    readonly property QtObject m: Theme.media
    readonly property QtObject h: Theme.hover

    readonly property real textMax: m.chipMaxWidth - m.chipCover - m.chipGap - m.chipButtonsGap - m.chipButton
    readonly property real overflow: Math.max(0, line.implicitWidth - textMax)
    // soft text edges blend into whatever is behind them (island or the hover highlight)
    readonly property color edge: Theme.mix(Theme.island, m.chipHover, highlight.opacity)

    implicitWidth: m.chipCover + m.chipGap + textBox.width + m.chipButtonsGap + m.chipButton
    implicitHeight: m.chipCover

    // highlight while the pointer is on the open area (cover + text)
    Rectangle {
        id: highlight
        x: -root.m.chipPad
        width: open.width + root.m.chipPad + 4
        height: root.m.chipCover + 12
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
        id: cover
        width: root.m.chipCover
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
        x: cover.width + root.m.chipGap
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
                font.pixelSize: root.h.titleSize
                font.weight: Font.DemiBold
            }
            Txt {
                visible: text !== ""
                text: Media.artist(root.player)
                textFormat: Text.PlainText
                color: Theme.textDim
                font.pixelSize: root.h.titleSize
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
        height: root.m.chipCover + 12
        anchors.verticalCenter: parent.verticalCenter
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
        width: root.m.chipButton
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
            size: root.m.chipGlyph
            filled: true
            stroke: 1.5
            color: Theme.text
        }
        MouseArea {
            id: toggleArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Media.toggle(root.player)
        }
    }
}
