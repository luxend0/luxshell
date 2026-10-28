import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Wallpaper on the background layer, one surface per screen.
//
// Only active with LUXSHELL_WALLPAPER=1 or Settings.wallpaperLayer (Wallpapers.layerEnabled):
// during the transition Ambxst still paints the wallpaper, then the picker only writes
// Settings.wallpaper and nothing here is created.
//
//   images  decoded at screen size (asynchronous), cover-cropped
//   videos  QtMultimedia (FFmpeg backend: VA-API hardware decode when available), no audio
//           output at all, looped; paused while a window covers the workspace on that screen
//           (fullscreen, or any tiled window) or the session is locked - a paused decoder costs nothing
//   change  the new wallpaper fades in over the old one once its first frame is there,
//           then the old one is destroyed (Motion.ms: LUXSHELL_SLOWMO applies)
Scope {
    id: root

    // singletons are lazy: this starts the "wallpaper" palette and the theme export
    readonly property bool sync: ThemeSync.active

    readonly property int fade: 700

    // "covered" needs each window's floating flag (lastIpcObject); refresh it on the
    // events that can change it, debounced, no polling
    Connections {
        target: Hyprland
        enabled: Wallpapers.layerEnabled
        function onRawEvent(event): void {
            if (["openwindow", "closewindow", "changefloatingmode", "movewindowv2", "fullscreen"].includes(event.name))
                refresh.restart();
        }
    }
    Timer {
        id: refresh
        interval: 250
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
        }
    }

    Variants {
        model: Wallpapers.layerEnabled ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData
            readonly property var workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
            readonly property bool covered: !!workspace && (workspace.hasFullscreen || workspace.toplevels.values.some(t => !(t.lastIpcObject?.floating ?? false)))

            screen: modelData
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "luxshell-wallpaper"

            Item {
                id: stage
                anchors.fill: parent

                readonly property string source: Settings.wallpaper
                onSourceChanged: show()
                Component.onCompleted: show()

                function show(): void {
                    if (source === "") {
                        for (const s of children)
                            s.leave();
                        return;
                    }
                    slide.createObject(stage, {
                        "path": source
                    });
                }

                // called by a slide once it is fully visible
                function settled(top: Item): void {
                    for (const s of children)
                        if (s !== top)
                            s.destroy();
                }
            }

            Component {
                id: slide

                Item {
                    id: s

                    required property string path
                    readonly property bool video: Wallpapers.isVideo(path)
                    property bool shown: false

                    anchors.fill: parent
                    opacity: 0

                    function reveal(): void {
                        if (shown)
                            return;
                        shown = true;
                        fadeIn.start();
                    }
                    function leave(): void {
                        fadeIn.stop();
                        fadeOut.start();
                    }

                    NumberAnimation {
                        id: fadeIn
                        target: s
                        property: "opacity"
                        to: 1
                        duration: Motion.ms(root.fade)
                        easing.type: Easing.InOutQuad
                        onFinished: stage.settled(s)
                    }
                    NumberAnimation {
                        id: fadeOut
                        target: s
                        property: "opacity"
                        to: 0
                        duration: Motion.ms(root.fade)
                        easing.type: Easing.InOutQuad
                        onFinished: s.destroy()
                    }

                    Image {
                        anchors.fill: parent
                        visible: !s.video
                        source: s.video ? "" : Wallpapers.url(s.path)
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        onStatusChanged: {
                            if (status === Image.Ready)
                                s.reveal();
                            else if (status === Image.Error)
                                console.warn(`luxshell: cannot show wallpaper ${s.path}`);
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: s.video
                        sourceComponent: Item {
                            MediaPlayer {
                                id: player
                                source: Wallpapers.url(s.path)
                                videoOutput: out
                                loops: MediaPlayer.Infinite
                                // no audioOutput: the file's audio track is never even opened
                                // also paused while the session is locked (lock/ shows a still)
                                readonly property bool run: !win.covered && !Lock.locked
                                onRunChanged: run ? play() : pause()
                                onErrorOccurred: (error, message) => console.warn(`luxshell: video wallpaper ${s.path}: ${message}`)
                                Component.onCompleted: run ? play() : pause()
                            }
                            VideoOutput {
                                id: out
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectCrop
                            }
                            // fade in on the first decoded frame, then stop listening
                            Connections {
                                target: out.videoSink
                                enabled: !s.shown
                                function onVideoFrameChanged(): void {
                                    s.reveal();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
