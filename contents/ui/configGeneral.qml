import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_autoRefreshOnHover: hoverCheck.checked
    property alias cfg_pollInterval: intervalSpin.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: hoverCheck
            Kirigami.FormData.label: "Auto-Refresh:"
            text: "Refetch display information when mouse hovers over widget"
        }

        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Background Poll Interval (seconds):"
            from: 5
            to: 120
            stepSize: 5
        }
    }
}
