/*
 * Samples a live `value` over time into a rolling array and renders it with
 * Sparkline (so it inherits the hover tooltip + styling). Styled to match the
 * Plasma System Monitor graphs (filled area under a coloured line).
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property real value: 0
    property color lineColor: Kirigami.Theme.highlightColor
    property int maxHistory: 80
    property int sampleInterval: 2000
    property real rangeMax: 0          // 0 = auto-scale
    property real rangeFloor: 0        // auto-scale never zooms in below this
    property bool filled: true
    property bool paused: false        // when true, stop advancing the history
    property var tipText: function(value, index, total) { return "" + value }

    property var _vals: []

    Sparkline {
        anchors.fill: parent
        values: root._vals
        lineColor: root.lineColor
        filled: root.filled
        rangeMax: root.rangeMax
        rangeFloor: root.rangeFloor
        tipText: root.tipText
    }

    Timer {
        interval: root.sampleInterval
        repeat: true
        running: !root.paused
        onTriggered: {
            var a = root._vals.slice()
            a.push(root.value)
            if (a.length > root.maxHistory)
                a.shift()
            root._vals = a
        }
    }
}
