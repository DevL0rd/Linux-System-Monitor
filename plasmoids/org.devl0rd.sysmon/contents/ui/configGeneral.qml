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
