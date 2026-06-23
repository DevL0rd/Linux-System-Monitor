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
import "lib/Ring.js" as Ring

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
            try { root.snap = JSON.parse(xhr.responseText); root.recordHistory() } catch (e) {}
        }
        xhr.send()
    }
    // event-driven: re-read the instant the collector rewrites the snapshot (no
    // polling). The collector's sample rate (updateInterval, applied below) sets
    // how often that happens.
    FileWatcher {
        path: root.cachePath
        onChanged: root.read()
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

    // ---------------------------------------------------------------- history
    // Every metric (not just the charted one) is recorded continuously into a ring
    // buffer the moment a snapshot arrives -- so switching tabs shows full history
    // immediately. Modelled on Process Monitor: O(1) pushes for all metrics, but
    // only the tab currently on screen is linearised + repainted (the rest just
    // accumulate numbers and cost nothing until selected). `histTick` bumps once
    // per sample to nudge the visible chart to re-read its ring.
    readonly property int histLen: 120
    property int histTick: 0
    property var hist: ({ cpu: {}, gpu: {}, mem: {} })

    // per-device metric descriptors: key (ring id), label (tab), max (chart range,
    // 0 = auto-scale), get (pull current value from the live cpu/gpu object), fmt
    // (format a value for the tab + tooltip). Order = tab order, Usage first.
    // max(src): graph full-scale -- user override (config) if set, else the
    // hardware ceiling the collector detected, else a sane fallback. color(v):
    // heat tint for the value (usage/temp only; others read as plain text).
    readonly property var cpuMetrics: [
        { key: "usage", label: i18n("Usage"), get: function(c) { return c.total || 0 }, fmt: function(v) { return Math.round(v) + "%" },
          max: function(c) { return 100 }, color: function(v) { return Fmt.heat(v, 60, 85, Kirigami.Theme) } },
        { key: "temp",  label: i18n("Temp"),  get: function(c) { return c.temp || 0 },  fmt: function(v) { return Math.round(v) + "°C" },
          max: function(c) { return 100 }, color: function(v) { return Fmt.heat(v, 80, 95, Kirigami.Theme) } },
        { key: "clock", label: i18n("Clock"), get: function(c) { return c.freq || 0 },  fmt: function(v) { return v.toFixed(1) + " GHz" },
          max: function(c) { return Plasmoid.configuration.cpuClockMax > 0 ? Plasmoid.configuration.cpuClockMax : (c.clock_max || 6) } },
        { key: "power", label: i18n("Power"), get: function(c) { return c.watts || 0 }, fmt: function(v) { return Math.round(v) + " W" },
          max: function(c) { return Plasmoid.configuration.cpuPowerMax > 0 ? Plasmoid.configuration.cpuPowerMax : (c.power_max || 100) } },
        { key: "fan",   label: i18n("Fan"),   get: function(c) { return c.fan || 0 },   fmt: function(v) { return v > 0 ? Math.round(v) + " RPM" : "—" },
          max: function(c) { return Plasmoid.configuration.cpuFanMax > 0 ? Plasmoid.configuration.cpuFanMax : (c.fan_max || 6000) } }
    ]
    readonly property var gpuMetrics: [
        { key: "usage", label: i18n("Usage"), get: function(g) { return g.util || 0 },     fmt: function(v) { return Math.round(v) + "%" },
          max: function(g) { return 100 }, color: function(v) { return Fmt.heat(v, 60, 85, Kirigami.Theme) } },
        { key: "temp",  label: i18n("Temp"),  get: function(g) { return g.temp || 0 },     fmt: function(v) { return Math.round(v) + "°C" },
          max: function(g) { return 100 }, color: function(v) { return Fmt.heat(v, 75, 88, Kirigami.Theme) } },
        { key: "clock", label: i18n("Clock"), get: function(g) { return g.clock_gr || 0 }, fmt: function(v) { return Math.round(v) + " MHz" },
          max: function(g) { return Plasmoid.configuration.gpuClockMax > 0 ? Plasmoid.configuration.gpuClockMax : (g.clock_max || 3000) } },
        { key: "power", label: i18n("Power"), get: function(g) { return g.power || 0 },    fmt: function(v) { return Math.round(v) + " W" },
          max: function(g) { return Plasmoid.configuration.gpuPowerMax > 0 ? Plasmoid.configuration.gpuPowerMax : (g.power_max || 175) } },
        { key: "fan",   label: i18n("Fan"),   get: function(g) { return g.fan || 0 },      fmt: function(v) { return Math.round(v) + "%" },
          max: function(g) { return Plasmoid.configuration.gpuFanMax > 0 ? Plasmoid.configuration.gpuFanMax : 100 } }
    ]
    readonly property var memMetrics: [
        { key: "usage", label: i18n("RAM"), get: function(m) { return m.pct || 0 }, fmt: function(v) { return Math.round(v) + "%" },
          max: function(m) { return 100 }, color: function(v) { return Fmt.heat(v, 75, 90, Kirigami.Theme) } }
    ]

    function recordDevice(dev, src, defs) {
        var h = hist[dev]
        for (var i = 0; i < defs.length; i++) {
            var k = defs[i].key
            var r = h[k] || (h[k] = Ring.make(histLen))
            Ring.push(r, defs[i].get(src))
        }
    }
    function recordHistory() {
        recordDevice("cpu", root.cpu, cpuMetrics)
        recordDevice("mem", root.mem, memMetrics)
        if (root.gpu) recordDevice("gpu", root.gpu, gpuMetrics)
        histTick++                                   // notify the visible chart(s)
    }
    // oldest->newest array for one metric's ring (only called for the on-screen tab)
    function histValues(dev, key) {
        var h = hist[dev], r = h && h[key]
        return r ? Ring.values(r) : []
    }

    // ---------------------------------------------------------------- helpers
    // A history graph with a row of metric tabs beneath it. Every metric is already
    // being recorded centrally (recordHistory), so clicking a tab just rebinds the
    // graph to that metric's ring and its full history appears instantly. Tabs are
    // equal width (fillWidth + equal preferredWidth) so they stay evenly spaced.
    component TabbedChart: ColumnLayout {
        id: tc
        property string device: "cpu"
        property var metrics: []
        property var source: ({})              // live cpu/gpu object (for tab values)
        property int selected: 0
        readonly property var sel: tc.metrics[tc.selected] || ({})
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Sparkline {
            visible: Plasmoid.configuration.showCharts
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
            // re-read the selected ring each sample (histTick) and on tab change;
            // only this one metric is linearised -- the others just keep recording
            values: { root.histTick; return root.histValues(tc.device, tc.sel.key || "usage") }
            rangeMax: tc.sel.max ? tc.sel.max(tc.source) : 0    // hard fixed full-scale per metric
            lineColor: root.accent
            tipText: function(v) { return tc.sel.fmt ? tc.sel.fmt(v) : Math.round(v) + "" }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: tc.metrics
                delegate: Rectangle {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool current: tab.index === tc.selected
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1                        // equal-width columns
                    Layout.preferredHeight: tabCol.implicitHeight + Kirigami.Units.smallSpacing
                    radius: Kirigami.Units.smallSpacing
                    color: tab.current ? Qt.alpha(root.accent, 0.18)
                         : tabHover.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.07)
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    ColumnLayout {
                        id: tabCol
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.smallSpacing
                        spacing: 0
                        PlasmaComponents.Label {
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                            text: tab.modelData.label; font: Kirigami.Theme.smallFont
                            opacity: tab.current ? 0.9 : 0.55; elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                            text: tab.modelData.fmt(tab.modelData.get(tc.source))
                            // heat-coded where the metric defines it (usage/temp); else
                            // accent when selected, plain otherwise
                            color: tab.modelData.color ? tab.modelData.color(tab.modelData.get(tc.source))
                                 : (tab.current ? root.accent : Kirigami.Theme.textColor)
                            font.weight: Font.DemiBold; elide: Text.ElideRight
                        }
                    }
                    HoverHandler { id: tabHover }
                    TapHandler { onTapped: tc.selected = tab.index }
                }
            }
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
        // top-right reflects the selected tab's current value, color-coded
        trailing: cpuTabs.sel.fmt ? cpuTabs.sel.fmt(cpuTabs.sel.get(root.cpu)) : ""
        trailingColor: cpuTabs.sel.color ? cpuTabs.sel.color(cpuTabs.sel.get(root.cpu)) : Kirigami.Theme.textColor
        TabbedChart {
            id: cpuTabs
            device: "cpu"
            metrics: root.cpuMetrics
            source: root.cpu
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
        trailing: Math.round(root.mem.pct || 0) + "%"
        trailingColor: Fmt.heat(root.mem.pct || 0, 75, 90, Kirigami.Theme)
        Sparkline {
            visible: Plasmoid.configuration.showCharts
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
            values: { root.histTick; return root.histValues("mem", "usage") }
            rangeMax: 100
            lineColor: root.accent
            tipText: function(v) { return Math.round(v) + "% RAM" }
        }
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
        trailing: (root.gpu && gpuTabs.sel.fmt) ? gpuTabs.sel.fmt(gpuTabs.sel.get(root.gpu)) : ""
        trailingColor: (root.gpu && gpuTabs.sel.color) ? gpuTabs.sel.color(gpuTabs.sel.get(root.gpu)) : Kirigami.Theme.textColor
        TabbedChart {
            id: gpuTabs
            device: "gpu"
            metrics: root.gpuMetrics
            source: root.gpu || ({})
        }
        Gauge {
            Layout.fillWidth: true
            label: i18n("VRAM")
            value: root.gpu ? root.gpu.vram_pct : 0
            valueText: root.gpu ? (root.fmtGB(root.gpu.vram_used) + " / " + root.fmtGB(root.gpu.vram_total)) : ""
            barColor: root.accent
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
                    GpuCard {}
                    CpuCard {}
                    CoresCard {}
                    MemCard {}
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
