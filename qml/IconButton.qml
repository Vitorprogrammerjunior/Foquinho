import QtQuick

Item {
    id: b
    property string icon: "plus"
    property real size: 28
    property real iconSize: 15
    property color color: Theme.text2
    property color hoverColor: Theme.text
    property color bg: "transparent"
    property color hoverBg: "#1fffffff"
    readonly property bool hovered: ma.containsMouse
    signal clicked()

    width: size
    height: size
    scale: ma.pressed ? 0.86 : ma.containsMouse ? 1.1 : 1
    Behavior on scale { NumberAnimation { duration: ma.pressed ? 90 : 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ma.containsMouse ? b.hoverBg : b.bg
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Icon {
        anchors.centerIn: parent
        name: b.icon
        size: b.iconSize
        color: ma.containsMouse ? b.hoverColor : b.color
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
