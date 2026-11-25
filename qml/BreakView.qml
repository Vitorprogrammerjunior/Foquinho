import QtQuick

// Lembrete de pausa: o notch (ou a bolinha) cresce pedindo pra você levantar.
// Fica tocando até você confirmar, igual um despertador.
Item {
    id: bv
    property bool shown: false
    signal confirmed()
    signal snoozed()

    width: 480
    height: 64

    // chamado a cada toque do sininho
    property int rings: 0
    function ring() {
        ringAnim.restart()
        rings++
        rings % 2 ? pet.react("surprised", 1100) : pet.react("wave", 1600)
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: bv.shown ? 140 : 0 }
            NumberAnimation { duration: bv.shown ? 260 : 100 }
        }
    }
    scale: shown ? 1 : 0.9
    Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

    readonly property real sitMin: { Store.now; return (Store.now - Store.sitStart) / 60000 }

    // halo laranja atrás do mascote, estoura a cada toque
    Rectangle {
        id: halo
        anchors.centerIn: pet
        width: 46; height: 46; radius: 23
        color: "transparent"
        border.color: Theme.orange
        border.width: 2
        opacity: 0
    }

    Pet {
        id: pet
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        size: 40
        kind: Store.petKind
        mood: "tired"
        animated: bv.visible
    }

    Column {
        anchors.left: pet.right
        anchors.leftMargin: 12
        anchors.right: buttons.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: "Hora de levantar!"
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: Store.fmtMinutes(bv.sitMin) + " no PC. Alonga e bebe água."
            color: Theme.text2
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // adiar 5 minutos
        Rectangle {
            id: snooze
            height: 32
            width: snoozeT.implicitWidth + 20
            radius: 16
            color: snoozeMa.containsMouse ? Theme.fill2 : Theme.fill
            scale: snoozeMa.pressed ? 0.92 : 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 120 } }
            Text {
                id: snoozeT
                anchors.centerIn: parent
                text: "+5 min"
                color: Theme.text2
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            MouseArea {
                id: snoozeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bv.snoozed()
            }
        }

        Rectangle {
            id: ok
            height: 32
            width: okRow.implicitWidth + 24
            radius: 16
            color: okMa.containsMouse ? Qt.lighter(Theme.green, 1.12) : Theme.green
            scale: okMa.pressed ? 0.92 : 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 120 } }
            Row {
                id: okRow
                anchors.centerIn: parent
                spacing: 6
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 14; stroke: 2.4; color: "white" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Levantei"
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: okMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bv.confirmed()
            }
        }
    }

    SequentialAnimation {
        id: ringAnim
        ParallelAnimation {
            NumberAnimation { target: halo; property: "scale"; from: 0.9; to: 1.9; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { target: halo; property: "opacity"; from: 0.9; to: 0; duration: 900 }
            SequentialAnimation {
                NumberAnimation { target: ok; property: "rotation"; to: -5; duration: 70 }
                NumberAnimation { target: ok; property: "rotation"; to: 5; duration: 110 }
                NumberAnimation { target: ok; property: "rotation"; to: -3; duration: 100 }
                NumberAnimation { target: ok; property: "rotation"; to: 0; duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }
}
