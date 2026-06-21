/*
 * A thin horizontal bar gauge with a label and value. The fill is a blue->red
 * gradient by how full it is (override with useGradient:false + barColor), and
 * it shows a tooltip on hover.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "Format.js" as Fmt

ColumnLayout {
    id: root

    property string label: ""
    property real value: 0          // 0..100
    property string valueText: Math.round(value) + "%"
    property bool useGradient: true
    property color barColor: Kirigami.Theme.highlightColor
    readonly property color fillColor: useGradient ? Fmt.grad(value) : barColor

    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents.Label {
            text: root.label
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            text: root.valueText
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: Kirigami.Units.smallSpacing
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value / 100))
            height: parent.height
            radius: height / 2
            color: root.fillColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    HoverHandler { id: hover }
    QQC2.ToolTip.visible: hover.hovered && (root.label !== "" || root.valueText !== "")
    QQC2.ToolTip.text: (root.label ? root.label + ": " : "") + root.valueText
    QQC2.ToolTip.delay: 400
}
