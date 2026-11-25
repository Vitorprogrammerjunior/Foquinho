import QtQuick
import QtQuick.Effects

// Janela transparente ancorada no topo da tela (layer-shell no KDE, dock no X11/Openbox).
// Só a área visível do notch recebe cliques; o resto passa direto para o desktop.
Window {
    id: win
    width: 760
    height: 760
    color: "transparent"
    visible: false // o C++ configura o layer-shell e mostra
    title: "Foquinho"

    property bool booted: false
    property bool quitting: false
    property bool expanded: false
    property bool settingsOpen: false
    property double expandStamp: 0
    property var alertData: null

    // Lembrete de pausa tocando: ganha de tudo (até da bolinha escondida, que cresce pra avisar).
    readonly property bool breakShown: Store.breakRinging && booted && !quitting && !expanded
    readonly property bool hovered: notchHover.hovered && !expanded && !alertData && !breakShown
    readonly property bool hiddenMode: Store.hidden && !quitting && !breakShown
    property real nudge: 0

    readonly property real targetW: (!booted || quitting) ? 0
        : hiddenMode ? 36
        : breakShown ? 480 + nudge
        : expanded ? 548
        : alertData ? 400
        : collapsedView.implicitWidth
    readonly property real targetH: (!booted || quitting) ? 0
        : hiddenMode ? 0
        : breakShown ? 64 + nudge * 0.25
        : expanded ? expandedView.implicitHeight
        : alertData ? 62
        : (hovered ? 42 : 38)
    readonly property real targetR: expanded ? 32 : (alertData || breakShown) ? 28 : (hovered ? 21 : 19)

    property real curW: targetW
    property real curH: targetH
    property real curR: targetR
    Behavior on curW { SpringAnimation { spring: 3.8; damping: 0.32; epsilon: 0.2 } }
    Behavior on curH { SpringAnimation { spring: 3.4; damping: 0.38; epsilon: 0.2 } }
    Behavior on curR { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    // ---------- ações ----------
    function expand(withInput) {
        if (Store.hidden) Store.hidden = false
        alertData = null
        expanded = true
        expandStamp = Date.now()
        if (withInput) {
            // Captura rápida: pega o teclado até Enter/Esc (ou 45 s parado sem texto).
            settingsOpen = false
            quickMode = true
            Backend.grabKeyboard(true)
            quickIdle.restart()
            Qt.callLater(expandedView.focusInput)
        }
    }
    function collapse() {
        expanded = false
        settingsOpen = false
        quickMode = false
        quickIdle.stop()
        root.forceActiveFocus()
        Backend.grabKeyboard(false)
    }
    function hideToDot() {
        collapse()
        alertData = null
        Store.hidden = true
    }
    function quitApp() {
        Store.save()
        expanded = false
        quitting = true
        quitTimer.start()
    }
    function showAlert(a, ms) {
        if (expanded || Store.hidden || breakShown) return
        alertData = a
        alertTimer.interval = ms || 2600
        alertTimer.restart()
    }

    // ---------- lembrete de pausa ----------
    // Com o painel aberto, espera você fechar (no máximo 2 min) antes de tocar.
    property double breakWaitSince: 0
    Connections {
        target: Store
        function onBreakDueChanged() { win.checkBreak() }
    }
    function checkBreak() {
        if (!Store.breakDue || !booted) return
        if (expanded) {
            if (!breakWaitSince) breakWaitSince = Date.now()
            if (Date.now() - breakWaitSince < 120000) { breakWait.restart(); return }
            collapse()
        }
        breakWaitSince = 0
        alertData = null
        Store.ringBreak()
    }
    Timer { id: breakWait; interval: 5000; onTriggered: win.checkBreak() }

    // Toca o sininho: no começo a cada 6 s, depois de 1 min a cada 15 s. Para só quando você confirma.
    property int ringCount: 0
    Timer {
        id: ringer
        running: win.breakShown && !(Backend.screenLocked)
        repeat: true
        triggeredOnStart: true
        interval: win.ringCount < 10 ? 6000 : 15000
        onTriggered: {
            win.ringCount++
            Backend.playChime()
            breakView.ring()
            nudgeAnim.restart()
        }
        onRunningChanged: if (!running && !Store.breakRinging) win.ringCount = 0
    }
    SequentialAnimation {
        id: nudgeAnim
        NumberAnimation { target: win; property: "nudge"; to: 26; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "nudge"; to: 0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }
    function confirmBreak() {
        Store.tookBreak(false)
        afterBreak.restart()
    }
    function snoozeBreak() {
        Store.snoozeBreak(5)
    }
    Timer {
        id: afterBreak; interval: 700
        onTriggered: win.showAlert({ kind: "done", title: "Boa! Pausa feita",
                                     sub: "Te chamo de novo em " + Store.fmtMinutes(Store.breakMinutes) }, 3000)
    }

    property bool quickMode: false
    Timer {
        id: quickIdle; interval: 45000
        onTriggered: if (win.quickMode) { if (expandedView.inputEmpty) win.collapse(); else restart() }
    }
    Timer { id: alertTimer; interval: 2600; onTriggered: win.alertData = null }
    Timer { id: quitTimer; interval: 650; onTriggered: Backend.quit() }
    Timer {
        id: bootTimer
        interval: 250
        onTriggered: {
            win.booted = true
            if (Store.firstRun) {
                if (Backend && !Backend.autostart) Backend.autostart = true
                welcome.start()
            }
        }
    }
    Timer {
        id: welcome
        interval: 900
        onTriggered: win.showAlert({ kind: "info", title: "Oi! Eu sou o " + Store.petName,
                                     sub: "Clique aqui e registre sua primeira demanda" }, 5200)
    }

    // ---------- balão de atalhos: ao iniciar e uma vez por dia ----------
    property bool tipPending: false
    readonly property bool tipShown: tipPending && booted && !quitting && !expanded && !hiddenMode && !alertData && !breakShown
    function maybeTip(onStartup) {
        if (!Store.tipsEnabled || tipPending) return
        if (onStartup || Store.lastTipDay !== Store.dayKey()) tipPending = true
    }
    function answerTip(never) {
        tipPending = false
        Store.tipTalking = false
        Store.lastTipDay = Store.dayKey()
        if (never) { Store.tipsEnabled = false; Store.say("Combinado, não falo mais!") }
        else Store.petEvent("love")
    }
    Timer { id: tipStartup; interval: Store.firstRun ? 7500 : 3000; onTriggered: win.maybeTip(true) }
    Timer { interval: 60000; running: win.booted; repeat: true; onTriggered: win.maybeTip(false) }

    property double lastWave: 0
    onExpandedChanged: {
        Qt.callLater(checkBreak)
        if (expanded && Date.now() - lastWave > 90000) {
            lastWave = Date.now()
            waveDelay.restart()
        }
    }
    Timer { id: waveDelay; interval: 380; onTriggered: Store.petEvent("wave") }

    Component.onCompleted: {
        Store.backend = Backend
        Store.media = Media
        Store.load()
        bootTimer.start()
        tipStartup.start()
    }

    onActiveChanged: {
        // clicou fora: recolhe o painel (nunca esconde o notch)
        if (!active && expanded && Date.now() - expandStamp > 450) collapse()
    }

    Connections {
        target: Backend
        function onCommand(name, arg) {
            switch (name) {
            case "toggle": win.expanded ? win.collapse() : win.expand(false); break
            case "open": win.expand(false); break
            case "add":
                if (arg) Store.addTask(arg, false)
                else win.expand(true)
                break
            case "focus":
                if (arg) Store.addTask(arg, true)
                break
            case "hide": Store.hidden ? (Store.hidden = false) : win.hideToDot(); break
            case "show": Store.hidden = false; break
            case "done": Store.completeFirst(); break
            case "pause": Store.toggleAll(); break
            case "play": Media.playPause(); break
            case "next": Media.next(); break
            case "prev": Media.previous(); break
            case "break": Store.ringBreak(); break
            case "quit": win.quitApp(); break
            }
        }
    }

    Binding { target: Media; property: "enabled"; value: Store.musicEnabled; when: Store.loaded }

    Connections {
        target: Media
        function onNewTrack() {
            win.showAlert({ kind: "music", title: Media.title, sub: Media.artist ? Media.artist : Media.player }, 3200)
        }
    }

    Connections {
        target: Backend
        function onCurrentScreenChanged() {
            if (!win.booted) return
            let label = Backend.currentScreen
            for (const s of Backend.screens) if (s.name === Backend.currentScreen) label = s.label
            win.showAlert({ kind: "info", title: "Cheguei!", sub: "Agora no monitor " + label }, 2200)
        }
    }

    Connections {
        target: Store
        function onCompleted(title, spentMs) {
            win.showAlert({ kind: "done", title: "Concluída!", sub: title + "  ·  " + Store.fmtShort(spentMs) })
        }
        function onAdded(title, toFocus) {
            if (win.quickMode) win.collapse()
            win.showAlert({ kind: "added", title: toFocus ? "Em foco agora" : "Adicionada à fila", sub: title }, 2000)
        }
    }

    // ---------- área clicável ----------
    function updateMask() {
        const rects = []
        if (hiddenMode) {
            rects.push(Qt.rect(win.width / 2 - 23, 2, 46, 46))
        } else {
            const w = Math.max(targetW, 8) + 2 * 12 + 8
            const h = Math.max(targetH, 6) + 4
            rects.push(Qt.rect((win.width - w) / 2, 0, w, h))
        }
        if (tipShown)
            rects.push(Qt.rect(tip.x - 4, tip.y - 2, tip.width + 8, tip.height + 8))
        Backend.setInputRegion(rects)
    }
    onTargetWChanged: Qt.callLater(updateMask)
    onTargetHChanged: Qt.callLater(updateMask)
    onHiddenModeChanged: { Qt.callLater(updateMask); Qt.callLater(updateShape) }
    onTipShownChanged: Qt.callLater(updateMask)

    // ---------- X11 sem compositor (Openbox puro, sem picom) ----------
    // Sem transparência de verdade, a própria janela é recortada no contorno do notch,
    // acompanhando a animação de mola quadro a quadro. No KDE e com compositor, nada disso roda.
    readonly property bool shaped: Backend.needsShape
    function updateShape() {
        if (!shaped) return
        const s = []
        if (notch.visible)
            s.push({ x: notch.x + notch.ear, y: 0, w: win.curW, h: notch.height,
                     r: win.curR, ear: notch.ear, roundTop: false })
        if (dot.shown)
            s.push({ x: win.width / 2 - 23, y: -1, w: 46, h: 46, r: 23, roundTop: true })
        if (tip.visible) {
            // mesma escala de entrada do balão (origem na ponta do rabinho)
            const k = 0.4 + 0.6 * tip.appear
            const ox = tip.x + tip.tailX
            s.push({ x: ox - tip.tailX * k, y: tip.y + tip.tailH * k, w: tip.width * k,
                     h: (tip.height - tip.tailH) * k + 2, r: 15 * k, roundTop: true })
            // rabinho: fino na ponta, mais largo na base
            s.push({ x: ox - 1.5 * k, y: tip.y + 1, w: 3 * k, h: tip.tailH * 0.5 * k, r: 0 })
            s.push({ x: ox - 4.5 * k, y: tip.y + tip.tailH * 0.5 * k, w: 9 * k, h: tip.tailH * 0.5 * k + 1, r: 0 })
        }
        Backend.setShape(s)
    }
    onCurWChanged: if (shaped) Qt.callLater(updateShape)
    onCurHChanged: if (shaped) Qt.callLater(updateShape)
    onCurRChanged: if (shaped) Qt.callLater(updateShape)
    onShapedChanged: Qt.callLater(updateShape)

    // ---------- visual ----------
    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: if (win.expanded) win.collapse()

        Item {
            id: notch
            readonly property real ear: Math.min(12, height / 2.6)
            width: Math.max(0, win.curW) + 2 * ear
            height: Math.max(0, win.curH)
            x: Math.round((win.width - width) / 2)
            y: 0
            visible: height > 0.5 && win.curW > 1

            RectangularShadow {
                x: notch.ear
                width: Math.max(0, win.curW)
                height: notch.height
                radius: Math.min(win.curR, height / 2)
                blur: 34
                spread: -4
                offset.y: 14
                color: "#000000"
                opacity: win.expanded ? 0.65 : win.breakShown ? 0.55 : win.alertData ? 0.45 : 0
                Behavior on opacity { NumberAnimation { duration: 280 } }
            }

            NotchShape {
                anchors.fill: parent
                ear: notch.ear
                radius: win.curR
                color: Theme.notch
            }

            MouseArea {
                anchors.fill: parent
                enabled: !win.expanded && !win.breakShown
                cursorShape: Qt.PointingHandCursor
                onClicked: win.expand(false)
            }
            HoverHandler { id: notchHover }

            Item {
                id: clipper
                x: notch.ear
                width: Math.max(0, win.curW)
                height: notch.height
                clip: true

                CollapsedView {
                    id: collapsedView
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: implicitWidth
                    height: win.hovered ? 42 : 38
                    hovered: win.hovered
                    shown: win.booted && !win.quitting && !win.expanded && !win.alertData && !win.hiddenMode && !win.breakShown
                }

                AlertView {
                    anchors.horizontalCenter: parent.horizontalCenter
                    alert: win.alertData
                    shown: !!win.alertData && !win.expanded && !win.hiddenMode && !win.quitting && !win.breakShown
                }

                BreakView {
                    id: breakView
                    anchors.horizontalCenter: parent.horizontalCenter
                    shown: win.breakShown
                    onConfirmed: win.confirmBreak()
                    onSnoozed: win.snoozeBreak()
                }

                ExpandedView {
                    id: expandedView
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 548
                    height: implicitHeight
                    shown: win.expanded && !win.quitting
                    settingsOpen: win.settingsOpen
                    onCollapseRequested: win.collapse()
                    onHideRequested: win.hideToDot()
                    onQuitRequested: win.quitApp()
                    onSettingsToggled: win.settingsOpen = !win.settingsOpen
                }
            }
        }

        TipBubble {
            id: tip
            x: Math.round((win.width - collapsedView.width) / 2 + collapsedView.petCenter - tailX)
            y: Math.round(Math.max(win.curH, 30) + 8)
            shown: win.tipShown
            onTypingChanged: (typing) => Store.tipTalking = typing
            onOkClicked: win.answerTip(false)
            onNeverClicked: win.answerTip(true)
            onXChanged: { if (win.tipShown) Qt.callLater(win.updateMask); if (win.shaped) Qt.callLater(win.updateShape) }
            onHeightChanged: { if (win.tipShown) Qt.callLater(win.updateMask); if (win.shaped) Qt.callLater(win.updateShape) }
            onAppearChanged: if (win.shaped) Qt.callLater(win.updateShape)
        }

        Dot {
            id: dot
            x: Math.round((win.width - width) / 2)
            y: Math.round(22 - height / 2)
            shown: win.hiddenMode && win.booted
            onShownChanged: if (win.shaped) Qt.callLater(win.updateShape)
            onClicked: Store.hidden = false
        }
    }
}
