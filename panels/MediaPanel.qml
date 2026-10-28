import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.controlcenter
import qs.panels.media

// Media panel (registry id "media"), opened from the media chip of the hover island
// (or IPC: luxshell open media). Same width and radius as the control center, so it
// morphs out of the island like every panel.
//
//   left   cover (cross-fades on a new track) with a soft glow: a blurred copy of it
//          behind (halo) and a fainter, wider one over the panel (wash). Settings.mediaGlow:
//          soft (muted colour, default) | color | mono | off; monochrome themes stay calm.
//   right  player switch (pills, only interactive with 2+ players), open-app button,
//          title, artist, seek track with times, previous / play-pause / next, player volume.
//   empty  no player: "Nothing playing", short panel.
//
// Keys: Space / K play-pause, Left / Right seek 5 s, Shift+Left/Right or P / N previous /
// next, Up / Down volume, Tab / Shift+Tab player, Esc closes (host).
PanelBase {
    id: root

    readonly property QtObject m: Theme.media
    readonly property var player: probe ? null : Media.active
    readonly property bool hasPlayer: !!player
    readonly property string glowMode: Settings.mediaGlow
    readonly property real glowSat: m.glowSaturation[glowMode] ?? m.glowSaturation.soft

    preferredWidth: m.width
    preferredHeight: hasPlayer ? m.height : m.emptyHeight
    maxWidth: m.width
    maxHeight: m.height
    cornerRadius: m.radius

    // position ticks only while a panel shows it
    readonly property bool watching: active && !probe
    onWatchingChanged: Media.watch(watching)
    Component.onDestruction: if (watching)
        Media.watch(false)

    // entrance: the cover settles, the text slides in (every time the panel opens)
    property real enter: 1
    onActiveChanged: if (active && !probe)
        enterAnim.restart()
    NumberAnimation {
        id: enterAnim
        target: root
        property: "enter"
        from: 0
        to: 1
        duration: Motion.ms(root.m.enter)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasized
    }

    Keys.onPressed: e => {
        const shift = e.modifiers & Qt.ShiftModifier;
        if (e.key === Qt.Key_Space || e.key === Qt.Key_K)
            Media.toggle(player);
        else if (e.key === Qt.Key_N || (shift && e.key === Qt.Key_Right))
            Media.next(player);
        else if (e.key === Qt.Key_P || (shift && e.key === Qt.Key_Left))
            Media.previous(player);
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Left)
            Media.seekBy(player, e.key === Qt.Key_Right ? 5 : -5);
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Down)
            Media.setVolume(player, (player?.volume ?? 0) + (e.key === Qt.Key_Up ? 0.05 : -0.05));
        else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)
            Media.cycle(e.key === Qt.Key_Backtab || shift ? -1 : 1);
        else
            return;
        e.accepted = true;
    }

    // content only outside the registry probe (it needs the size only): touching
    // services/Media (MPRIS) inside the probe loop let the settings load re-evaluate
    // the other probes after their destroy() (TypeErrors at start with a saved theme)
    Loader {
        anchors.fill: parent
        active: !root.probe
        sourceComponent: Item {
            // ---- glow -----------------------------------------------------------------------
            // the cover's two slots (unclipped), so the glow cross-fades with the cover; clipped to
            // the panel's own shape (the island body only clips to its bounding box)
            ClippingRectangle {
                id: glow
                anchors.fill: parent
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: root.cornerRadius
                bottomRightRadius: root.cornerRadius
                color: "transparent"
                visible: root.hasPlayer && root.glowMode !== "off" && cover.ready

                MultiEffect {
                    id: wash
                    readonly property real s: root.width * root.m.washSpread
                    x: cover.x + cover.width / 2 - s / 2
                    y: cover.y + cover.height / 2 - s / 2
                    width: s
                    height: s
                    source: cover.content
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    blurMultiplier: 1.5
                    saturation: root.glowSat
                    brightness: root.m.washBrightness
                    opacity: root.m.washOpacity * root.enter
                }
                MultiEffect {
                    id: halo
                    readonly property real s: cover.width * root.m.glowSpread
                    x: cover.x + cover.width / 2 - s / 2
                    y: cover.y + cover.height / 2 - s / 2 + 6
                    width: s
                    height: s
                    source: cover.content
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    saturation: root.glowSat
                    brightness: root.m.glowBrightness
                    opacity: root.m.glowOpacity * root.enter
                }
            }

            // ---- cover ------------------------------------------------------------------------
            CoverArt {
                id: cover
                visible: root.hasPlayer
                x: root.m.pad
                y: root.m.pad
                width: root.m.cover
                height: root.m.cover
                radius: root.m.coverRadius
                source: Media.art(root.player)
                glyphSize: 44
                transformOrigin: Item.TopLeft
                scale: 0.86 + 0.14 * root.enter
                opacity: Math.min(1, root.enter * 1.6) * (root.player?.isPlaying ? 1 : 0.82)
                Behavior on opacity {
                    enabled: root.enter >= 1
                    Anim {
                        ms: Theme.fadeIn
                    }
                }
            }

            // ---- right column -------------------------------------------------------------------
            Item {
                id: column
                visible: root.hasPlayer
                x: root.m.pad + root.m.cover + root.m.columnGap + (1 - root.enter) * 14
                width: root.width - root.m.pad - root.m.cover - root.m.columnGap - root.m.pad
                height: root.height
                opacity: Motion.smooth(root.enter, [0.15, 1])

                PlayerPills {
                    id: pills
                    x: -root.m.pillPad + 1 // icon aligns with the title
                    y: root.m.pad
                }

                Rectangle {
                    id: raise
                    visible: root.player?.canRaise ?? false
                    anchors.right: parent.right
                    anchors.rightMargin: -6
                    y: root.m.pad
                    width: root.m.pillHeight
                    height: width
                    radius: width / 2
                    color: raiseArea.containsMouse ? root.m.pill : "transparent"
                    Glyph {
                        anchors.centerIn: parent
                        name: "arrow-up-right"
                        size: 16
                        color: raiseArea.containsMouse ? Theme.text : Theme.textDim
                    }
                    MouseArea {
                        id: raiseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Media.raise(root.player);
                            Ui.close();
                        }
                    }
                }

                CapText {
                    width: parent.width
                    capY: root.m.titleY
                    text: Media.title(root.player)
                    textFormat: Text.PlainText
                    font.pixelSize: root.m.titleSize
                    font.weight: Font.DemiBold
                }
                CapText {
                    width: parent.width
                    capY: root.m.artistY
                    text: {
                        const a = Media.artist(root.player);
                        const b = Media.album(root.player);
                        return a && b ? `${a}  ·  ${b}` : a || b;
                    }
                    textFormat: Text.PlainText
                    color: Theme.textSecondary
                    font.pixelSize: root.m.artistSize
                    font.weight: Font.Medium
                }

                SeekBar {
                    width: parent.width
                    y: root.m.trackY - height / 2
                    player: root.player
                }

                Row {
                    id: transport
                    x: -(root.m.skipDisc - root.m.skipGlyph) / 2 // glyph edge aligns with the text
                    y: root.m.controlsY - height / 2
                    spacing: root.m.skipGap

                    TransportButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip-back"
                        enabled: root.player?.canGoPrevious ?? false
                        onClicked: Media.previous(root.player)
                    }
                    TransportButton {
                        anchors.verticalCenter: parent.verticalCenter
                        primary: true
                        icon: root.player?.isPlaying ? "pause" : "play"
                        glyphSize: root.m.playGlyph
                        glyphOffset: root.player?.isPlaying ? 0 : 1.5
                        enabled: root.player?.canTogglePlaying ?? false
                        onClicked: Media.toggle(root.player)
                    }
                    TransportButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip-forward"
                        enabled: root.player?.canGoNext ?? false
                        onClicked: Media.next(root.player)
                    }
                }

                VolumeBar {
                    visible: Media.canVolume(root.player)
                    anchors.right: parent.right
                    y: root.m.controlsY - height / 2
                    player: root.player
                }
            }

            // ---- nothing playing --------------------------------------------------------------------
            Item {
                anchors.fill: parent
                visible: !root.hasPlayer && !root.probe
                opacity: Motion.smooth(root.enter, [0.15, 1])

                Rectangle {
                    id: emptyDisc
                    x: root.m.pad + 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    height: width
                    radius: 18
                    color: Theme.surfaceHigh
                    Glyph {
                        anchors.centerIn: parent
                        name: "music"
                        size: 26
                        color: Theme.textSecondary
                    }
                }
                Column {
                    anchors.left: emptyDisc.right
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Txt {
                        text: "Nothing playing"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    Txt {
                        text: "Start music in Spotify or any MPRIS player"
                        color: Theme.textDim
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
