import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    property alias cfg_panelIcon: iconField.text
    property alias cfg_updateInterval: intervalSpin.value
    property alias cfg_accentColor: accent.text
    property alias cfg_showCharts: chartsCheck.checked
    property alias cfg_showPerCore: coresCheck.checked
    property alias cfg_showGpu: gpuCheck.checked
    property alias cfg_cpuClockMax: cpuClock.value
    property alias cfg_cpuPowerMax: cpuPower.value
    property alias cfg_cpuFanMax: cpuFan.value
    property alias cfg_gpuClockMax: gpuClock.value
    property alias cfg_gpuPowerMax: gpuPower.value
    property alias cfg_gpuFanMax: gpuFan.value

    RowLayout {
        Kirigami.FormData.label: i18n("Panel icon:")
        QQC2.TextField { id: iconField; placeholderText: i18n("icon name") }
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Refresh interval:")
        QQC2.SpinBox { id: intervalSpin; from: 500; to: 10000; stepSize: 250 }
        QQC2.Label { text: i18n("ms"); opacity: 0.6 }
    }
    QQC2.CheckBox { id: chartsCheck; Kirigami.FormData.label: i18n("Show:"); text: i18n("History graphs") }
    QQC2.CheckBox { id: coresCheck; text: i18n("Per-core bars") }
    QQC2.CheckBox { id: gpuCheck; text: i18n("GPU section") }

    Item { Kirigami.FormData.isSection: true }

    QQC2.Label {
        Kirigami.FormData.label: i18n("Graph full-scale:")
        text: i18n("0 = auto-detect from hardware")
        opacity: 0.6
    }
    RowLayout {
        Kirigami.FormData.label: i18n("CPU clock / power / fan:")
        QQC2.SpinBox { id: cpuClock; from: 0; to: 12; stepSize: 1 }
        QQC2.Label { text: i18n("GHz"); opacity: 0.6 }
        QQC2.SpinBox { id: cpuPower; from: 0; to: 1000; stepSize: 5 }
        QQC2.Label { text: i18n("W"); opacity: 0.6 }
        QQC2.SpinBox { id: cpuFan; from: 0; to: 20000; stepSize: 100 }
        QQC2.Label { text: i18n("RPM"); opacity: 0.6 }
    }
    RowLayout {
        Kirigami.FormData.label: i18n("GPU clock / power / fan:")
        QQC2.SpinBox { id: gpuClock; from: 0; to: 6000; stepSize: 50 }
        QQC2.Label { text: i18n("MHz"); opacity: 0.6 }
        QQC2.SpinBox { id: gpuPower; from: 0; to: 1000; stepSize: 5 }
        QQC2.Label { text: i18n("W"); opacity: 0.6 }
        QQC2.SpinBox { id: gpuFan; from: 0; to: 100; stepSize: 5 }
        QQC2.Label { text: i18n("%"); opacity: 0.6 }
    }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: i18n("Accent colour:")
        QQC2.CheckBox {
            id: useAccent; text: i18n("Custom")
            checked: accent.text !== ""
            onToggled: if (!checked) accent.text = ""
        }
        KQuickControls.ColorButton {
            enabled: useAccent.checked
            color: accent.text !== "" ? accent.text : Kirigami.Theme.highlightColor
            onColorChanged: if (useAccent.checked) accent.text = color
        }
        QQC2.Label { id: accent; visible: false; text: "" }
    }

    QQC2.Label {
        Kirigami.FormData.label: i18n("Collector:")
        text: i18n("Sampling rate is poll_interval in ~/.config/Linux-System-Monitor/config.json")
        opacity: 0.6; wrapMode: Text.Wrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 18
    }
}
