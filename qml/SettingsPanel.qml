import QtQuick

Column {
    id: sp
    property bool shown: false
    signal quitRequested()

    spacing: 10
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 200 } }

    SectionLabel { width: parent.width; label: "MASCOTE" }

    Row {
        spacing: 8
        Repeater {
            model: [["cat", "Gato"], ["ghost", "Fantasma"], ["slime", "Slime"]]
            Rectangle {
                id: tile
                required property var modelData
                readonly property bool selected: Store.petKind === modelData[0]
                width: (sp.width - 16) / 3
                height: 92
                radius: 16
                color: tileMa.containsMouse ? Theme.cardHover : Theme.card
                border.width: selected ? 1.5 : 1
                border.color: selected ? Theme.accent : Theme.stroke
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Pet {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 12
                    size: 46
                    kind: tile.modelData[0]
                    mood: tile.selected ? "happy" : (tileMa.containsMouse ? "focus" : "idle")
                    animated: sp.visible
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9
                    text: tile.modelData[1]
                    color: tile.selected ? Theme.text : Theme.text2
                    font.pixelSize: 12
                    font.weight: tile.selected ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: tileMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Store.petKind = tile.modelData[0]
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 44
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: nameInput.activeFocus ? Theme.a(Theme.accent, 0.75) : Theme.stroke
        Text {
            id: nameLabel
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "Nome"
            color: Theme.text2
            font.pixelSize: 13
        }
        TextInput {
            id: nameInput
            anchors.left: nameLabel.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: TextInput.AlignRight
            text: Store.petName
            color: Theme.text
            font.pixelSize: 13
            maximumLength: 20
            selectByMouse: true
            selectionColor: Theme.a(Theme.accent, 0.6)
            onEditingFinished: if (text.trim()) Store.petName = text.trim()
        }
    }

    Item { width: 1; height: 2 }
    SectionLabel { width: parent.width; label: "COMPORTAMENTO" }

    Rectangle {
        width: parent.width
        height: 200
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: Theme.stroke
        Column {
            anchors.fill: parent
            Repeater {
                model: 4
                Item {
                    required property int index
                    width: parent.width
                    height: 50
                    Rectangle {
                        visible: index > 0
                        x: 14; width: parent.width - 28; height: 1
                        color: Theme.stroke
                    }
                    Column {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: ["Puxar a próxima ao concluir", "Iniciar junto com o sistema", "Dicas de atalhos do " + Store.petName, "Mostrar a música tocando"][index]
                            color: Theme.text
                            font.pixelSize: 13
                        }
                        Text {
                            text: ["A primeira da fila entra em foco na hora", "Abre o notch quando você faz login", "Um balãozinho ao abrir e uma vez por dia", "Spotify e outros players: DVD, controles e ondinhas"][index]
                            color: Theme.text3
                            font.pixelSize: 11
                        }
                    }
                    Toggle {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        checked: index === 0 ? Store.autoAdvance : index === 2 ? Store.tipsEnabled : index === 3 ? Store.musicEnabled : (Store.backend ? Store.backend.autostart : false)
                        onToggled: (v) => {
                            if (index === 0) Store.autoAdvance = v
                            else if (index === 2) Store.tipsEnabled = v
                            else if (index === 3) Store.musicEnabled = v
                            else if (Store.backend) Store.backend.autostart = v
                        }
                    }
                }
            }
        }
    }

    Item { width: 1; height: 2 }
    SectionLabel { width: parent.width; label: "SAÚDE" }

    Rectangle {
        id: breakCard
        width: parent.width
        height: Store.breakEnabled ? 104 : 50
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: Theme.stroke
        clip: true
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        readonly property real leftMin: { Store.now; return (Store.breakDueAt - Store.now) / 60000 }

        Item {
            width: parent.width
            height: 50
            Column {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "Lembrete para levantar"
                    color: Theme.text
                    font.pixelSize: 13
                }
                Text {
                    text: !Store.breakEnabled ? "Toca um sininho e cresce o notch até você confirmar"
                          : breakCard.leftMin <= 0 ? "Hora da pausa!"
                          : "Próximo em " + Store.fmtMinutes(Math.ceil(breakCard.leftMin)) + " · bloquear a tela conta como pausa"
                    color: Theme.text3
                    font.pixelSize: 11
                }
            }
            Toggle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.breakEnabled
                onToggled: (v) => Store.breakEnabled = v
            }
        }

        Rectangle {
            y: 50
            x: 14; width: parent.width - 28; height: 1
            color: Theme.stroke
        }

        Item {
            y: 51
            width: parent.width
            height: 53
            opacity: Store.breakEnabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Text {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "A cada"
                color: Theme.text2
                font.pixelSize: 12
            }
            Row {
                id: intervalRow
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: [30, 45, 60, 90, 120]
                    Rectangle {
                        id: chip
                        required property int modelData
                        readonly property bool selected: Store.breakMinutes === modelData
                        height: 28
                        width: Math.max(52, chipT.implicitWidth + 20)
                        radius: 14
                        color: selected ? Theme.a(Theme.accent, 0.28) : chipMa.containsMouse ? Theme.fill2 : Theme.fill
                        border.width: selected ? 1.5 : 0
                        border.color: Theme.accent
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            id: chipT
                            anchors.centerIn: parent
                            text: Store.fmtMinutes(chip.modelData)
                            color: chip.selected ? Theme.text : Theme.text2
                            font.pixelSize: 12
                            font.weight: chip.selected ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Store.breakMinutes = chip.modelData
                        }
                    }
                }
            }
        }
    }

    Item { width: 1; height: 2 }
    SectionLabel { width: parent.width; label: "MONITOR" }

    Row {
        id: screenRow
        readonly property var screens: Store.backend ? Store.backend.screens : []
        readonly property string chosen: Store.backend ? Store.backend.screenName : ""
        readonly property string current: Store.backend ? Store.backend.currentScreen : ""
        readonly property var options: {
            let primaryLabel = ""
            for (const s of screens) if (s.primary) primaryLabel = s.label
            const out = [{ key: "", title: "Principal", sub: primaryLabel ? "Segue o " + primaryLabel : "Segue o principal" }]
            for (const s of screens)
                out.push({ key: s.name, title: s.label, sub: s.name + (s.primary ? " · principal" : "") })
            return out
        }
        spacing: 8
        Repeater {
            model: screenRow.options
            Rectangle {
                id: scr
                required property var modelData
                readonly property bool selected: screenRow.chosen === modelData.key
                width: (sp.width - screenRow.spacing * (screenRow.options.length - 1)) / screenRow.options.length
                height: 74
                radius: 16
                color: scrMa.containsMouse ? Theme.cardHover : Theme.card
                border.width: selected ? 1.5 : 1
                border.color: selected ? Theme.accent : Theme.stroke
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10
                    name: scr.modelData.key === "" ? "star" : "display"
                    size: 20
                    color: scr.selected ? Theme.accent : Theme.text2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 35
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: scr.modelData.title
                    color: scr.selected ? Theme.text : Theme.text2
                    font.pixelSize: 12
                    font.weight: scr.selected ? Font.DemiBold : Font.Normal
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 52
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: scr.modelData.sub
                    color: Theme.text3
                    font.pixelSize: 10
                }
                MouseArea {
                    id: scrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (Store.backend) Store.backend.screenName = scr.modelData.key
                }
            }
        }
    }
    Text {
        x: 4
        width: parent.width - 8
        wrapMode: Text.WordWrap
        text: screenRow.screens.length > 1
              ? "Ou puxe pro próximo monitor de qualquer lugar com " + Store.keysFor("screen", "M").join(" + ") + "."
              : "Só um monitor conectado agora. Quando ligar outro, ele aparece aqui."
        color: Theme.text3
        font.pixelSize: 11
    }

    // Fora do KDE não há cor de destaque do sistema para seguir: a pessoa escolhe aqui.
    Item { width: 1; height: 2; visible: accentRow.visible }
    SectionLabel { width: parent.width; label: "COR DE DESTAQUE"; visible: accentRow.visible }

    Rectangle {
        id: accentRow
        visible: !!Store.backend && Store.backend.platform === "x11"
        readonly property string chosen: Store.backend ? Store.backend.accentChoice : ""
        width: parent.width
        height: 50
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: Theme.stroke
        Row {
            anchors.centerIn: parent
            spacing: 12
            Repeater {
                // "" = automático (kdeglobals, se existir, ou o azul do WhiteSur)
                model: ["", "#315bef", "#926ee4", "#f74f9e", "#ff5257", "#f7821b", "#ffc600", "#62ba46", "#8c8c8c"]
                Item {
                    id: sw
                    required property string modelData
                    readonly property bool selected: accentRow.chosen === modelData
                    width: 26
                    height: 26
                    Rectangle {
                        anchors.centerIn: parent
                        width: sw.selected ? 26 : 22
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: sw.selected ? Theme.text : "transparent"
                        Behavior on width { NumberAnimation { duration: 140 } }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: 9
                        scale: swMa.containsMouse ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        gradient: sw.modelData === "" ? autoGrad : null
                        color: sw.modelData === "" ? "transparent" : sw.modelData
                        Gradient {
                            id: autoGrad
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#315bef" }
                            GradientStop { position: 0.5; color: "#926ee4" }
                            GradientStop { position: 1; color: "#f74f9e" }
                        }
                    }
                    MouseArea {
                        id: swMa
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (Store.backend) Store.backend.accentChoice = sw.modelData
                    }
                }
            }
        }
    }

    Item { width: 1; height: 2 }
    SectionLabel { width: parent.width; label: "ATALHOS GLOBAIS" }

    Rectangle {
        width: parent.width
        height: shortcutsCol.implicitHeight + 16
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: Theme.stroke
        Column {
            id: shortcutsCol
            x: 14
            y: 8
            width: parent.width - 28
            spacing: 2
            Repeater {
                model: [["N", "Nova demanda", "add"], ["F", "Abrir / fechar painel", "toggle"], ["H", "Esconder em bolinha", "hide"], ["D", "Concluir demanda em foco", "done"], ["M", "Mover pro próximo monitor", "screen"], ["Espaço", "Tocar / pausar música", "play"], [".", "Próxima música", "next"], [",", "Música anterior", "prev"]]
                Item {
                    required property var modelData
                    width: shortcutsCol.width
                    height: 28
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        color: Theme.text2
                        font.pixelSize: 12
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: Store.keysFor(modelData[2], modelData[0])
                            Rectangle {
                                required property string modelData
                                height: 20
                                width: Math.max(20, keyT.implicitWidth + 12)
                                radius: 6
                                color: Theme.fill
                                border.width: 1
                                border.color: Theme.stroke
                                Text { id: keyT; anchors.centerIn: parent; text: modelData; color: Theme.text; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        x: 4
        width: parent.width - 8
        wrapMode: Text.WordWrap
        text: Store.backend && Store.backend.shortcutsHint ? Store.backend.shortcutsHint
              : "Dá para trocar em Configurações do Sistema › Teclado › Atalhos › Foquinho."
        color: Theme.text3
        font.pixelSize: 11
    }

    Item { width: 1; height: 4 }

    Item {
        width: parent.width
        height: 36
        Rectangle {
            id: quitBtn
            height: 34
            width: quitRow.implicitWidth + 26
            radius: 17
            color: quitMa.containsMouse ? Theme.a(Theme.red, 0.22) : Theme.a(Theme.red, 0.12)
            Behavior on color { ColorAnimation { duration: 140 } }
            Row {
                id: quitRow
                anchors.centerIn: parent
                spacing: 7
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "power"; size: 14; color: Theme.red }
                Text { text: "Encerrar Foquinho"; color: Theme.red; font.pixelSize: 12; font.weight: Font.DemiBold }
            }
            MouseArea { id: quitMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sp.quitRequested() }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: "Foquinho 1.1 · " + Store.totalDone + " concluídas no total"
            color: Theme.text3
            font.pixelSize: 11
        }
    }
}
