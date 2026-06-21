/*
 * Linux-System-Monitor :: local system dashboard.
 *
 * Reads the snapshot kept in tmpfs by the resident `--serve` collector (systemd
 * --user service, pinned to the E-cores) in-process via XHR (file://). Requires
 * QML_XHR_ALLOW_FILE_READ=1 (set by install.sh via environment.d).
 *
 * Cards (CPU + graph + freq/power/temp, P/E core bars with group totals, RAM +
 * swap, GPU) stack in a single vertical column.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/Format.js" as Fmt

PlasmoidItem {
    id: root

    property string panelIcon: Plasmoid.configuration.panelIcon || "cpu"
    Plasmoid.icon: panelIcon
    Plasmoid.title: snap.host || i18n("System Monitor")
    Connections {
        target: Plasmoid.configuration
        function onPanelIconChanged() { root.panelIcon = Plasmoid.configuration.panelIcon || "cpu" }
        function onUpdateIntervalChanged() { root.applyInterval() }
    }

    readonly property color accent: Plasmoid.configuration.accentColor !== ""
        ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor

    property var snap: ({})
    readonly property var cpu: snap.cpu || ({})
    readonly property var mem: snap.mem || ({})
    readonly property var gpu: snap.gpu || null

    toolTipMainText: snap.host || i18n("System Monitor")
    toolTipSubText: i18n("CPU %1%  ·  RAM %2%  ·  %3", Math.round(cpu.total || 0),
                         Math.round(mem.pct || 0), Fmt.temp(cpu.temp))
    preferredRepresentation: fullRepresentation

    function fmtGB(b) {
        b = b || 0
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB"
        if (b >= 1048576) return Math.round(b / 1048576) + " MB"
        return Math.round(b / 1024) + " KB"
    }
    function cpuShort() {
        return (snap.cpu_model || "").replace(/\(R\)|\(TM\)/g, "")
            .replace(/\d+th Gen /, "").replace("Intel Core ", "").replace(/\s+/g, " ").trim()
    }
    function gpuShort(n) { return (n || "GPU").replace("NVIDIA GeForce ", "").replace("NVIDIA ", "") }

    // ---- read the tmpfs cache in-process via XHR ----
    property string cachePath: ""
    P5Support.DataSource {
        id: pathHelper
        engine: "executable"
        onNewData: function(source, d) { root.cachePath = (d.stdout || "").trim(); disconnectSource(source); root.read() }
    }
    function read() {
        if (!cachePath) return
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + cachePath)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (!xhr.responseText) return
            try { root.snap = JSON.parse(xhr.responseText) } catch (e) {}
        }
        xhr.send()
    }
    Timer {
        interval: Math.max(500, Plasmoid.configuration.updateInterval)
        repeat: true; running: true
        onTriggered: root.read()
    }
    // keep the collector's sample rate in lock-step with the refresh interval, so
    // changing the setting speeds the *data* up immediately (not just the re-read)
    P5Support.DataSource {
        id: cfgWriter
        engine: "executable"
        onNewData: function(source, d) { disconnectSource(source) }
    }
    function applyInterval() {
        cfgWriter.connectSource("$HOME/.local/bin/sysmon-collect --set-interval "
            + (Math.max(500, Plasmoid.configuration.updateInterval) / 1000))
    }
    Component.onCompleted: {
        pathHelper.connectSource("printf %s \"$XDG_RUNTIME_DIR/Linux-System-Monitor/data.json\"")
        applyInterval()
    }

    // ---------------------------------------------------------------- helpers
    component StatTile: ColumnLayout {
        id: tile
        property string tlabel: ""
        property string tvalue: ""
        property color tcolor: Kirigami.Theme.textColor
        Layout.fillWidth: true
        spacing: 0
        PlasmaComponents.Label {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: tile.tlabel; font: Kirigami.Theme.smallFont; opacity: 0.55
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: tile.tvalue; color: tile.tcolor; font.weight: Font.DemiBold
        }
    }

    // a row of thin per-core bars filling from the bottom (blue->red gradient),
    // each with a hover tooltip
    component CoreBars: RowLayout {
        id: bars
        property var values: []
        property string prefix: i18n("Core")
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
        spacing: 2
        Repeater {
            model: bars.values.length
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: parent.height * Math.max(0.03, Math.min(1, (bars.values[index] || 0) / 100))
                    radius: 2
                    color: Fmt.grad(bars.values[index] || 0)
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                HoverHandler { id: barHover }
                QQC2.ToolTip.visible: barHover.hovered
                QQC2.ToolTip.text: bars.prefix + " " + index + ": " + Math.round(bars.values[index] || 0) + "%"
                QQC2.ToolTip.delay: 300
            }
        }
    }

    // styled card with a title row; instance children go into the body column
    component Card: Rectangle {
        id: card
        property string title: ""
        property string trailing: ""
        property color trailingColor: Kirigami.Theme.textColor
        default property alias cont: body.data
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        radius: Kirigami.Units.smallSpacing
        color: Qt.alpha(Kirigami.Theme.textColor, 0.04)
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
        implicitHeight: wrap.implicitHeight + Kirigami.Units.smallSpacing * 2
        ColumnLayout {
            id: wrap
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            RowLayout {
                Layout.fillWidth: true
                visible: card.title !== ""
                PlasmaComponents.Label { text: card.title; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                PlasmaComponents.Label { text: card.trailing; visible: card.trailing !== ""; color: card.trailingColor; font.weight: Font.Bold }
            }
            ColumnLayout { id: body; Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing }
        }
    }

    // ---------------------------------------------------------------- cards
    component CpuCard: Card {
        title: i18n("CPU")
        trailing: Math.round(root.cpu.total || 0) + "%"
        trailingColor: Fmt.heat(root.cpu.total || 0, 60, 85, Kirigami.Theme)
        HistoryChart {
            visible: Plasmoid.configuration.showCharts
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
            value: root.cpu.total || 0
            rangeMax: 100
            lineColor: root.accent
            sampleInterval: Math.max(500, Plasmoid.configuration.updateInterval)
            tipText: function(v) { return Math.round(v) + "% CPU" }
        }
        RowLayout {
            Layout.fillWidth: true
            StatTile { tlabel: i18n("Freq"); tvalue: (root.cpu.freq || 0).toFixed(1) + " GHz" }
            StatTile { tlabel: i18n("Power"); tvalue: Math.round(root.cpu.watts || 0) + " W" }
            StatTile { tlabel: i18n("Temp"); tvalue: Fmt.temp(root.cpu.temp); tcolor: Fmt.heat(root.cpu.temp || 0, 80, 95, Kirigami.Theme) }
        }
    }

    component CoresCard: Card {
        title: i18n("Cores")
        visible: Plasmoid.configuration.showPerCore
        // hybrid -> P/E sections, each with a group-total bar + per-core bars
        Gauge {
            visible: root.cpu.hybrid === true
            Layout.fillWidth: true
            label: i18n("P-Cores")
            value: root.cpu.p_total || 0
            valueText: Math.round(root.cpu.p_total || 0) + "%   " + (root.cpu.p_freq || 0).toFixed(1) + " GHz"
            barColor: root.accent
        }
        CoreBars { visible: root.cpu.hybrid === true; values: root.cpu.p || []; prefix: i18n("P-Core") }
        Gauge {
            visible: root.cpu.hybrid === true
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            label: i18n("E-Cores")
            value: root.cpu.e_total || 0
            valueText: Math.round(root.cpu.e_total || 0) + "%   " + (root.cpu.e_freq || 0).toFixed(1) + " GHz"
            barColor: root.accent
        }
        CoreBars { visible: root.cpu.hybrid === true; values: root.cpu.e || []; prefix: i18n("E-Core") }
        // non-hybrid -> a single bank of cores
        CoreBars { visible: root.cpu.hybrid !== true; values: root.cpu.cores || [] }
    }

    component MemCard: Card {
        title: i18n("Memory")
        Gauge {
            Layout.fillWidth: true
            label: i18n("RAM")
            value: root.mem.pct || 0
            valueText: root.fmtGB(root.mem.used) + " / " + root.fmtGB(root.mem.total)
            barColor: Fmt.heat(root.mem.pct || 0, 75, 90, Kirigami.Theme)
        }
        Gauge {
            Layout.fillWidth: true
            visible: (root.mem.swap_total || 0) > 0
            label: i18n("Swap")
            value: root.mem.swap_pct || 0
            valueText: root.fmtGB(root.mem.swap_used) + " / " + root.fmtGB(root.mem.swap_total)
            barColor: root.accent
        }
    }

    component GpuCard: Card {
        visible: Plasmoid.configuration.showGpu && root.gpu
        title: root.gpu ? root.gpuShort(root.gpu.name) : i18n("GPU")
        trailing: root.gpu ? Math.round(root.gpu.util) + "%" : ""
        trailingColor: Fmt.heat(root.gpu ? root.gpu.util : 0, 60, 85, Kirigami.Theme)
        HistoryChart {
            visible: Plasmoid.configuration.showCharts
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
            value: root.gpu ? root.gpu.util : 0
            rangeMax: 100
            lineColor: root.accent
            sampleInterval: Math.max(500, Plasmoid.configuration.updateInterval)
            tipText: function(v) { return Math.round(v) + "% GPU" }
        }
        Gauge {
            Layout.fillWidth: true
            label: i18n("VRAM")
            value: root.gpu ? root.gpu.vram_pct : 0
            valueText: root.gpu ? (root.fmtGB(root.gpu.vram_used) + " / " + root.fmtGB(root.gpu.vram_total)) : ""
            barColor: root.accent
        }
        RowLayout {
            Layout.fillWidth: true
            StatTile { tlabel: i18n("Temp"); tvalue: Fmt.temp(root.gpu ? root.gpu.temp : 0); tcolor: Fmt.heat(root.gpu ? root.gpu.temp : 0, 75, 88, Kirigami.Theme) }
            StatTile { tlabel: i18n("Power"); tvalue: Math.round(root.gpu ? root.gpu.power : 0) + " W" }
            StatTile { tlabel: i18n("Clock"); tvalue: Math.round(root.gpu ? root.gpu.clock_gr : 0) + " MHz" }
            StatTile { tlabel: i18n("Fan"); tvalue: Math.round(root.gpu ? root.gpu.fan : 0) + "%" }
        }
    }

    // ---------------------------------------------------------------- layout
    fullRepresentation: Item {
        clip: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 13
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12
        implicitWidth: Kirigami.Units.gridUnit * 18
        implicitHeight: Kirigami.Units.gridUnit * 30

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    source: root.panelIcon
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.snap.host || i18n("System"); font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.cpuShort() + (root.snap.uptime ? "  ·  up " + Fmt.duration(root.snap.uptime) : "")
                        font: Kirigami.Theme.smallFont; opacity: 0.6; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
                PlasmaComponents.Label {
                    text: i18n("Load %1", ((root.snap.load || [0])[0] || 0).toFixed(2))
                    font: Kirigami.Theme.smallFont; opacity: 0.6
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }

            // ---- cards, stacked in a single column ----
            QQC2.ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: scroll.availableWidth
                    spacing: Kirigami.Units.smallSpacing
                    CpuCard {}
                    CoresCard {}
                    MemCard {}
                    GpuCard {}
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
