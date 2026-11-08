import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_defaultStartMode: startModeCombo.currentValue
    property alias cfg_cardOpacity: opacitySlider.value
    property alias cfg_sortByState: sortByStateCheck.checked
    property alias cfg_showSearch: showSearchCheck.checked

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Auto-refresh interval (seconds):")
            from: 3
            to: 60
            stepSize: 1
        }

        QQC2.ComboBox {
            id: startModeCombo
            Kirigami.FormData.label: i18n("Default VM Startup Mode:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Graphical Window (GUI)"), value: "gui" },
                { text: i18n("Headless (Background Server)"), value: "headless" },
                { text: i18n("Separate Window"), value: "separate" }
            ]
            Component.onCompleted: {
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === Plasmoid.configuration.defaultStartMode) {
                        currentIndex = i;
                        break;
                    }
                }
            }
        }

        QQC2.Slider {
            id: opacitySlider
            Kirigami.FormData.label: i18n("Card background opacity:")
            from: 0.50
            to: 1.00
            stepSize: 0.05
        }

        QQC2.CheckBox {
            id: sortByStateCheck
            Kirigami.FormData.label: i18n("Behavior:")
            text: i18n("Sort running machines first")
        }

        QQC2.CheckBox {
            id: showSearchCheck
            text: i18n("Show search bar for quick filtering")
        }
    }
}
