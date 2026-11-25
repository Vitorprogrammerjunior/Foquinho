import QtQuick

// Conteúdo do notch fechado: mascote, demanda em foco e cronômetro.
Item {
    id: cv
    property bool hovered: false
    property bool shown: true

    readonly property bool hasFocus: Store.focusModel.count > 0
    // 0 → 1 suave no hover: tudo que muda de tamanho ou posição segue esta curva, sem pulos
    property real hoverT: hovered ? 1 : 0
    Behavior on hoverT { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    readonly property real controlsW: hasFocus ? 62 * hoverT : 0
    // ondinhas da música na pontinha direita do notch
    readonly property bool musicOn: Media.active && Media.playing
    property real musicW: musicOn ? 24 : 0
    Behavior on musicW { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    property int cycle: 0
    property int shownIdx: 0
    readonly property int idx: Math.max(0, Math.min(shownIdx, Store.focusModel.count - 1))
    readonly property var task: { Store.revision; return hasFocus ? Store.focusModel.get(idx) : null }
    readonly property string title: task ? task.title : ""
    readonly property bool running: task ? task.running : false
    readonly property double elapsed: { Store.now; return Store.elapsedOf(task) }

    readonly property real petCenter: pet.x + pet.width / 2
    implicitHeight: 38
    implicitWidth: hasFocus
        ? Math.max(250, titleText.x + Math.min(titleText.implicitWidth, 230) + (badge.visible ? badge.width + 8 : 0)
                         + 22 + controlsW + timerText.implicitWidth + 16 + musicW)
        : 212 + 14 * hoverT + musicW

    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: cv.shown ? 120 : 0 }
            NumberAnimation { duration: cv.shown ? 240 : 90; easing.type: Easing.OutCubic }
        }
    }
    scale: shown ? 1 : 0.92
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    Timer {
        interval: 5000
        repeat: true
        running: Store.focusModel.count > 1 && !cv.hovered && cv.shown
        onTriggered: cv.cycle = (cv.cycle + 1) % Store.focusModel.count
    }
    onCycleChanged: swap.restart()
    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: swapBox; property: "opacity"; to: 0; duration: 140 }
            NumberAnimation { target: swapT; property: "y"; to: -7; duration: 140; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { cv.shownIdx = cv.cycle; swapT.y = 7 } }
        ParallelAnimation {
            NumberAnimation { target: swapBox; property: "opacity"; to: 1; duration: 220 }
            NumberAnimation { target: swapT; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }
    }

    // ---- hover: o mascote nota você ----
    property double lastHoverReact: 0
    onHoveredChanged: {
        if (hovered && shown && Date.now() - lastHoverReact > 1400 && pet.reaction === "" && !Store.tipTalking) {
            lastHoverReact = Date.now()
            hoverPop.restart()
            pet.react(Store.petMood === "sleep" ? "yawn" : "curious", Store.petMood === "sleep" ? 1300 : 900)
        }
        if (!hovered) { pet.lookX = 0; pet.lookY = 0 }
    }
    HoverHandler {
        id: eyeTrack
        enabled: cv.shown
        // os olhos acompanham o cursor pelo notch
        onPointChanged: if (cv.hovered && pet.reaction === "") {
            const dx = (point.position.x - cv.petCenter) / Math.max(60, cv.width - cv.petCenter)
            pet.lookX = Math.max(-1.8, Math.min(1.8, dx * 2.4))
            pet.lookY = Math.max(-0.6, Math.min(0.8, (point.position.y - cv.height / 2) / cv.height * 1.4))
        }
    }

    Pet {
        id: pet
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 26
        kind: Store.petKind
        mood: Store.petMood
        animated: cv.visible
        listen: true
        talking: Store.tipTalking
        transformOrigin: Item.Center
        property real hoverScale: cv.hovered ? 1.12 : 1
        property real popScale: 1
        scale: hoverScale * popScale
        Behavior on hoverScale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    }
    SequentialAnimation {
        id: hoverPop
        NumberAnimation { target: pet; property: "popScale"; to: 1.12; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: pet; property: "popScale"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.4 }
    }

    // ---- com foco ----
    Item {
        id: swapBox
        visible: cv.hasFocus
        anchors.fill: parent
        transform: Translate { id: swapT }

        Text {
            id: titleText
            x: pet.x + pet.width + 10 + 2 * cv.hoverT
            anchors.verticalCenter: parent.verticalCenter
            // cabe no espaço que sobrar (o notch ainda pode estar crescendo)
            readonly property real room: cv.width - x - (badge.visible ? badge.width + 8 : 0) - 22
                                         - cv.controlsW - timerText.implicitWidth - 16 - cv.musicW + 1.5 // folga da mola
            width: Math.max(0, Math.min(implicitWidth, 230, room))
            text: cv.title
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Rectangle {
            id: badge
            visible: Store.focusModel.count > 1
            anchors.left: titleText.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 17
            width: badgeText.implicitWidth + 12
            radius: 8.5
            color: Theme.a(Theme.accent, 0.25)
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: (cv.idx + 1) + "/" + Store.focusModel.count
                color: Theme.accentText
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }

        Text {
            id: timerText
            anchors.right: parent.right
            anchors.rightMargin: 16 + cv.musicW
            anchors.verticalCenter: parent.verticalCenter
            text: Store.fmt(cv.elapsed)
            color: cv.running ? Theme.accentText : Theme.text2
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            Behavior on color { ColorAnimation { duration: 200 } }
            transformOrigin: Item.Right
            scale: 1 + 0.07 * cv.hoverT
        }
        Rectangle {
            id: liveDot
            anchors.right: timerText.left
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            color: cv.running ? Theme.accent : Theme.text3
            Behavior on color { ColorAnimation { duration: 200 } }
            // some encolhendo quando os botões chegam (antes sumia de uma vez)
            scale: 1 - cv.hoverT
            visible: scale > 0.02
            SequentialAnimation on opacity {
                running: cv.running && cv.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                onStopped: liveDot.opacity = 1
            }
        }

        Row {
            id: controls
            anchors.right: timerText.left
            anchors.rightMargin: 8 + 6 * cv.hoverT
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: cv.hoverT > 0.01
            // cada botão entra com um pulinho, o de concluir primeiro (o mais perto do cronômetro)
            Repeater {
                model: 2
                Item {
                    id: slot
                    required property int index
                    width: 26; height: 26
                    property real t: cv.hovered ? 1 : 0
                    Behavior on t {
                        SequentialAnimation {
                            PauseAnimation { duration: cv.hovered ? (slot.index === 0 ? 70 : 0) : 0 }
                            NumberAnimation {
                                duration: cv.hovered ? 440 : 160
                                easing.type: cv.hovered ? Easing.OutBack : Easing.InCubic
                                easing.overshoot: 2.4
                            }
                        }
                    }
                    opacity: Math.min(1, t * 1.6)
                    scale: 0.35 + 0.65 * t
                    transform: Translate { x: (1 - slot.t) * 10 }
                    IconButton {
                        anchors.fill: parent
                        size: 26
                        iconSize: slot.index === 0 ? 13 : 14
                        icon: slot.index === 0 ? (cv.running ? "pause" : "play") : "check"
                        color: slot.index === 0 ? Theme.text2 : "white"
                        hoverColor: slot.index === 0 ? Theme.text : "white"
                        bg: slot.index === 0 ? Theme.fill : Theme.green
                        hoverBg: slot.index === 0 ? Theme.fill2 : Qt.lighter(Theme.green, 1.15)
                        onClicked: slot.index === 0 ? Store.togglePause(cv.idx) : Store.complete(cv.idx)
                    }
                }
            }
        }
    }

    // ---- sem foco ----
    Item {
        visible: !cv.hasFocus
        anchors.fill: parent
        Text {
            x: pet.x + pet.width + 10 + 2 * cv.hoverT
            anchors.verticalCenter: parent.verticalCenter
            text: Store.queueModel.count > 0 ? Store.queueModel.count + " na fila" : "Sem foco agora"
            color: cv.hovered ? Theme.text : Theme.text2
            Behavior on color { ColorAnimation { duration: 220 } }
            font.pixelSize: 13
        }
        Item {
            anchors.right: parent.right
            anchors.rightMargin: 11 + cv.musicW
            anchors.verticalCenter: parent.verticalCenter
            width: 25; height: 25
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.a(Theme.accent, 0.3)
                scale: 0.4 + 0.6 * cv.hoverT
                opacity: cv.hoverT
            }
            Icon {
                anchors.centerIn: parent
                name: "plus"
                size: 15
                color: cv.hovered ? Theme.text : Theme.text3
                Behavior on color { ColorAnimation { duration: 200 } }
                rotation: 90 * cv.hoverT
                scale: 1 + 0.08 * cv.hoverT
            }
        }
    }

    MiniBars {
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        bands: [3, 1, 7, 12]
        barWidth: 2.6
        minH: 3
        maxH: 15
        opacity: cv.musicOn ? 1 : 0
        visible: opacity > 0.01
        scale: 1 + 0.12 * cv.hoverT
        Behavior on opacity { NumberAnimation { duration: 260 } }
    }
}
