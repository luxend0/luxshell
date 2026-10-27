import QtQuick
import qs.config
import qs.core

// Loads registered panels into two alternating slots and cross-fades between
// them, so panel -> panel morphs keep the old content visible while the new
// one fades in (timing: Motion.fadeIn/fadeInDelay/fadeOut). Loading is
// synchronous: a panel's reported size is known in the same frame and the
// island starts its morph right away.
FocusScope {
    id: host

    property string panelId: ""
    property int slot: 0
    readonly property Item current: slot === 0 ? slotA.item : slotB.item

    focus: true

    onPanelIdChanged: {
        const incoming = slot === 0 ? slotB : slotA;
        const outgoing = slot === 0 ? slotA : slotB;
        outgoing.shown = false;
        if (panelId === "")
            return;
        incoming.panelId = panelId;
        incoming.shown = true;
        incoming.sourceComponent = Panels.component(panelId);
        if (incoming.item) // slot reused while its old panel was still fading out
            incoming.item.panelId = panelId;
        slot = incoming === slotA ? 0 : 1;
        incoming.forceActiveFocus();
    }

    Keys.onEscapePressed: Ui.close()

    component Slot: Loader {
        id: loader

        property string panelId: ""
        property bool shown: false
        property real alpha: 0

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        focus: shown
        opacity: alpha
        visible: alpha > 0.001
        // in: after a short delay, while the body is already morphing; out: fast
        onShownChanged: {
            if (shown) {
                fadeOut.stop();
                fadeIn.restart();
            } else {
                fadeIn.stop();
                fadeOut.restart();
            }
        }
        onAlphaChanged: if (!shown && alpha === 0)
            sourceComponent = null
        onLoaded: {
            item.panelId = panelId;
            item.active = Qt.binding(() => loader.shown);
        }

        SequentialAnimation {
            id: fadeIn
            PauseAnimation {
                duration: Motion.ms(Motion.fadeInDelay)
            }
            NumberAnimation {
                target: loader
                property: "alpha"
                to: 1
                duration: Motion.ms(Motion.fadeIn)
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation {
            id: fadeOut
            target: loader
            property: "alpha"
            to: 0
            duration: Motion.ms(Motion.fadeOut)
            easing.type: Easing.OutCubic
        }
    }

    Slot {
        id: slotA
    }
    Slot {
        id: slotB
    }
}
