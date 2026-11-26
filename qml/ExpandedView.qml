import QtQuick

// Painel aberto: cabeçalho com o mascote + seções (foco, fila, concluídas) ou ajustes.
Item {
    id: ev
    property bool shown: false
    property bool settingsOpen: false
    signal collapseRequested()
    signal hideRequested()
    signal quitRequested()
    signal settingsToggled()
    readonly property bool inputEmpty: mainSections.inputEmpty

    readonly property real pad: 18
    readonly property real maxH: 700

    function focusInput() { mainSections.focusInput() }

    implicitHeight: Math.min(maxH, header.y + header.height + 12 + body.implicitHeight + 20)

    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: ev.shown ? 90 : 0 }
            NumberAnimation { duration: ev.shown ? 280 : 100; easing.type: Easing.OutCubic }
        }
    }
    transform: Translate {
        y: ev.shown ? 0 : -14
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    // ---------- cabeçalho ----------
    Item {
        id: header
        x: ev.pad
        y: 12
        width: ev.width - 2 * ev.pad
        height: 70

        Pet {
            id: hpet
            anchors.verticalCenter: parent.verticalCenter
            size: 66
            kind: Store.petKind
            mood: Store.petMood
            animated: ev.visible
            listen: true
            interactive: true
            onPetted: Store.sayOneOf(Store.petKind === "cat"
                                     ? ["Ronrom… mais!", "Hehe, cosquinha!", "Miau! Você é demais!"]
                                     : ["Hehe, cosquinha!", "Mais carinho, por favor!", "Você é demais!"])
        }

        Column {
            anchors.left: hpet.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Row {
                spacing: 7
                Text {
                    text: Store.petName
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 17
                    width: lvl.implicitWidth + 12
                    radius: 8.5
                    color: Theme.a(Theme.accent, 0.24)
                    Text {
                        id: lvl
                        anchors.centerIn: parent
                        text: "nv " + Store.level
                        color: Theme.accentText
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
                // No telão? Setor + bolinha de status da sincronização com o Hub de Demandas.
                Rectangle {
                    id: hubPill
                    readonly property var hub: Store.hub
                    readonly property string st: hub ? hub.status : "off"
                    visible: !!hub && (hub.connected || st === "expired")
                    anchors.verticalCenter: parent.verticalCenter
                    height: 17
                    width: hubPillRow.implicitWidth + 12
                    radius: 8.5
                    color: hubPillMa.containsMouse ? Theme.fill2 : Theme.fill
                    Row {
                        id: hubPillRow
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: 3
                            color: hubPill.st === "ok" ? Theme.green
                                 : hubPill.st === "syncing" ? Theme.accent
                                 : hubPill.st === "offline" ? Theme.orange : Theme.red
                        }
                        Text {
                            text: hubPill.st === "expired" ? "Hub desconectado"
                                  : hubPill.hub ? (hubPill.hub.sectorName || "Hub") : ""
                            color: Theme.text2
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: hubPillMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!ev.settingsOpen) ev.settingsToggled()
                    }
                }
            }
            Text {
                width: 236
                text: Store.petLine
                color: Theme.text2
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Rectangle {
                width: 110; height: 3; radius: 1.5
                color: Theme.fill
                Rectangle {
                    width: Math.max(3, parent.width * Store.xp)
                    height: 3; radius: 1.5
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                width: statRow.implicitWidth + 18
                radius: 13
                color: Theme.card
                border.width: 1
                border.color: Theme.stroke
                Row {
                    id: statRow
                    anchors.centerIn: parent
                    spacing: 5
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 12; stroke: 2.2; color: Theme.green }
                    Text {
                        text: Store.today.count + "  ·  " + Store.fmtShort(Store.today.ms)
                        color: Theme.text2
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
            Item { width: 2; height: 1 }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: ev.settingsOpen ? "x" : "sliders"
                onClicked: ev.settingsToggled()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "eyeoff"
                onClicked: ev.hideRequested()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevronUp"
                onClicked: ev.collapseRequested()
            }
        }
    }

    // ---------- corpo ----------
    Flickable {
        id: flick
        y: header.y + header.height + 12
        width: ev.width
        height: Math.max(0, ev.height - y - 20)
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1

        Item {
            id: body
            width: flick.width
            implicitHeight: ev.settingsOpen ? settings.implicitHeight : mainSections.implicitHeight
            height: implicitHeight

            MainSections {
                id: mainSections
                x: ev.pad
                width: parent.width - 2 * ev.pad
                shown: !ev.settingsOpen
                onEscapePressed: ev.collapseRequested()
            }
            SettingsPanel {
                id: settings
                x: ev.pad
                width: parent.width - 2 * ev.pad
                shown: ev.settingsOpen
                onQuitRequested: ev.quitRequested()
            }
        }
    }
}
