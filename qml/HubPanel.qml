import QtQuick

// Ajustes › Hub de Demandas: conecta o Foquinho ao telão, escolhe/troca o setor e mostra a sincronização.
Column {
    id: hp
    property bool shown: false
    readonly property var hub: Store.hub
    readonly property bool connected: !!hub && hub.connected
    property int pickedSector: 0
    property string formError: ""

    spacing: 10
    visible: !!hub

    function refreshSectors() {
        if (!hub) return
        hub.fetchSectors(connected ? "" : serverInput.text)
    }
    onShownChanged: if (shown) refreshSectors()
    onConnectedChanged: { formError = ""; if (shown) refreshSectors() }

    Connections {
        target: hp.hub
        function onConnectFailed(message) { hp.formError = message }
        function onConnectSucceeded() { hp.formError = ""; teamInput.text = "" }
    }

    // ---------- peças ----------
    component Field: Rectangle {
        id: fld
        property string label: ""
        property alias text: inp.text
        property alias input: inp
        property string placeholder: ""
        property bool secret: false
        signal accepted()
        width: parent ? parent.width : 0
        height: 44
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: inp.activeFocus ? Theme.a(Theme.accent, 0.75) : Theme.stroke
        Behavior on border.color { ColorAnimation { duration: 160 } }
        Text {
            id: fldLabel
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: fld.label
            color: Theme.text2
            font.pixelSize: 13
        }
        TextInput {
            id: inp
            anchors.left: fldLabel.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: TextInput.AlignRight
            color: Theme.text
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            selectionColor: Theme.a(Theme.accent, 0.6)
            echoMode: fld.secret && !activeFocus ? TextInput.Password : TextInput.Normal
            Keys.onReturnPressed: fld.accepted()
            Keys.onEnterPressed: fld.accepted()
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !inp.text
                text: fld.placeholder
                color: Theme.text3
                font: inp.font
            }
        }
    }

    component SectorChips: Flow {
        id: chips
        property int selected: 0
        property bool locked: false
        signal picked(int id)
        width: parent ? parent.width : 0
        spacing: 6
        Repeater {
            model: hp.hub ? hp.hub.sectors : []
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool isOn: chips.selected === modelData.id
                height: 30
                width: chipRow.implicitWidth + 22
                radius: 15
                color: isOn ? Theme.a(Theme.accent, 0.28) : chipMa.containsMouse ? Theme.fill2 : Theme.fill
                border.width: isOn ? 1.5 : 0
                border.color: Theme.accent
                Behavior on color { ColorAnimation { duration: 140 } }
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: chip.modelData.color || Theme.accent
                    }
                    Text {
                        text: chip.modelData.name
                        color: chip.isOn ? Theme.text : Theme.text2
                        font.pixelSize: 12
                        font.weight: chip.isOn ? Font.DemiBold : Font.Normal
                    }
                }
                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !chips.locked
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chips.picked(chip.modelData.id)
                }
            }
        }
    }

    component PillButton: Rectangle {
        id: pb
        property string text: ""
        property bool primary: true
        property bool danger: false
        property bool enabledState: true
        signal clicked()
        height: 34
        implicitWidth: pbText.implicitWidth + 28
        radius: 17
        opacity: enabledState ? 1 : 0.5
        color: danger ? (pbMa.containsMouse ? Theme.a(Theme.red, 0.22) : Theme.a(Theme.red, 0.12))
             : primary ? (pbMa.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
             : (pbMa.containsMouse ? Theme.fill2 : Theme.fill)
        Behavior on color { ColorAnimation { duration: 140 } }
        Text {
            id: pbText
            anchors.centerIn: parent
            text: pb.text
            color: pb.danger ? Theme.red : pb.primary ? "white" : Theme.text
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: pbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: pb.enabledState
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    // ---------- cabeçalho da seção ----------
    SectionLabel { width: parent.width; label: "HUB DE DEMANDAS" }

    // ---------- conectado ----------
    Rectangle {
        visible: hp.connected
        width: parent.width
        height: onCol.implicitHeight + 28
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: Theme.stroke

        Column {
            id: onCol
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12

            Item {
                width: parent.width
                height: 36
                Rectangle {
                    id: statusDot
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10; radius: 5
                    readonly property string st: hp.hub ? hp.hub.status : "off"
                    color: st === "ok" ? Theme.green
                         : st === "syncing" ? Theme.accent
                         : st === "offline" ? Theme.orange : Theme.red
                    SequentialAnimation on opacity {
                        running: statusDot.st === "syncing"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                        onRunningChanged: if (!running) statusDot.opacity = 1
                    }
                }
                Column {
                    anchors.left: statusDot.right
                    anchors.leftMargin: 10
                    anchors.right: discBtn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: hp.hub ? "Conectado como " + hp.hub.userName : ""
                        color: Theme.text
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: {
                            if (!hp.hub) return ""
                            Store.now
                            const h = hp.hub
                            switch (h.status) {
                            case "ok": {
                                const s = Math.max(0, Math.round((Store.now - h.lastSyncAt) / 1000))
                                return "No telão · sincronizado " + (s < 5 ? "agora" : s < 60 ? "há " + s + " s" : "há " + Math.round(s / 60) + " min")
                            }
                            case "syncing": return "Sincronizando…"
                            case "offline": return (h.message || "Sem conexão") + " · tento de novo sozinho"
                            default: return h.message || "Algo deu errado"
                            }
                        }
                        color: hp.hub && (hp.hub.status === "error") ? Theme.red : Theme.text3
                        font.pixelSize: 11
                    }
                }
                PillButton {
                    id: discBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!hp.hub && (hp.hub.status === "offline" || hp.hub.status === "error")
                    width: visible ? implicitWidth : 0
                    primary: false
                    text: "Tentar agora"
                    onClicked: hp.hub.retryNow()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.stroke }

            Text {
                text: "Seu setor no telão"
                color: Theme.text2
                font.pixelSize: 12
            }
            SectorChips {
                selected: hp.hub ? hp.hub.sectorId : 0
                locked: !!hp.hub && hp.hub.busy
                onPicked: (id) => hp.hub.changeSector(id)
            }
            Text {
                visible: !!hp.hub && hp.hub.sectors.length === 0
                text: hp.hub && hp.hub.sectorName ? hp.hub.sectorName + " (lista de setores indisponível agora)" : "Carregando setores…"
                color: Theme.text3
                font.pixelSize: 11
            }

            Item {
                width: parent.width
                height: 34
                Text {
                    anchors.left: parent.left
                    anchors.right: outBtn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                    text: "Tudo que você anotar aparece no telão do seu setor: o que está em foco e o que está na fila."
                    color: Theme.text3
                    font.pixelSize: 11
                }
                PillButton {
                    id: outBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    danger: true
                    text: "Desconectar"
                    onClicked: hp.hub.disconnectHub()
                }
            }
        }
    }

    // ---------- desconectado: formulário ----------
    Text {
        visible: !hp.connected
        x: 4
        width: parent.width - 8
        wrapMode: Text.WordWrap
        text: hp.hub && hp.hub.status === "expired" && hp.hub.message
              ? hp.hub.message
              : "Conecte para suas demandas aparecerem no telão da equipe, com o que está em foco e a fila."
        color: hp.hub && hp.hub.status === "expired" ? Theme.orange : Theme.text3
        font.pixelSize: 11
    }

    Field {
        id: serverInput
        visible: !hp.connected
        label: "Servidor"
        placeholder: "demandas.suaempresa.com.br"
        text: hp.hub ? (hp.hub.serverUrl || hp.hub.defaultServer) : ""
        input.onEditingFinished: hp.refreshSectors()
    }
    Field {
        id: nameInput
        visible: !hp.connected
        label: "Seu nome"
        placeholder: "como aparece na TV"
        text: hp.hub ? hp.hub.userName : ""   // reconectar: já vem preenchido
        input.maximumLength: 60
        onAccepted: teamInput.input.forceActiveFocus()
    }
    Field {
        id: teamInput
        visible: !hp.connected
        label: "Código da equipe"
        placeholder: "peça para o admin"
        secret: true
        input.maximumLength: 40
        onAccepted: connectBtn.clicked()
    }

    Text {
        visible: !hp.connected
        x: 4
        text: hp.hub && hp.hub.sectors.length > 0 ? "Escolha seu setor"
              : !serverInput.text.trim() ? "Digite o endereço do servidor para ver os setores"
              : "Buscando setores…"
        color: Theme.text2
        font.pixelSize: 12
    }
    SectorChips {
        visible: !hp.connected
        selected: hp.pickedSector
        onPicked: (id) => hp.pickedSector = id
    }

    Item {
        visible: !hp.connected
        width: parent.width
        height: 36
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.right: connectBtn.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: hp.formError || (hp.hub && hp.hub.status === "off" ? hp.hub.message : "")
            color: Theme.red
            font.pixelSize: 11
        }
        PillButton {
            id: connectBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: hp.hub && hp.hub.busy ? "Conectando…" : "Conectar ao hub"
            enabledState: !!hp.hub && !hp.hub.busy
            onClicked: {
                hp.formError = ""
                if (!serverInput.text.trim()) { hp.formError = "Digite o endereço do servidor."; return }
                if (!nameInput.text.trim()) { hp.formError = "Digite seu nome."; return }
                if (!teamInput.text.trim()) { hp.formError = "Digite o código da equipe."; return }
                if (!hp.pickedSector) { hp.formError = "Escolha um setor."; return }
                hp.hub.connectTo(serverInput.text, nameInput.text, teamInput.text, hp.pickedSector)
            }
        }
    }
}
