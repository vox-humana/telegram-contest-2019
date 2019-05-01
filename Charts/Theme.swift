import UIKit

struct Constants {
    static let chartHeight: CGFloat = 338

    static let scaleControlHeight: CGFloat = 40 + scaleControlBorderHeight * 2
    static let scaleControlBorderHeight: CGFloat = 1
    static let scaleControlImageWidth: CGFloat = 10
    static let scaleControlcornerRadius: CGFloat = 6

    static let contentPadding: CGFloat = 16
    static let buttonsPanelHPadding: CGFloat = 16
    static let animationDuration: TimeInterval = 0.3
}

extension UIFont {
    static var titleFont: UIFont { return UIFont.boldSystemFont(ofSize: 13) }
    static var lozengeButtonFont: UIFont { return UIFont.systemFont(ofSize: 14) }
    static var axisFont: UIFont { return UIFont.systemFont(ofSize: 11) }
    static var tooltipFont: UIFont { return UIFont.boldSystemFont(ofSize: 12) }
    static var tooltipNameFont: UIFont { return UIFont.systemFont(ofSize: 12) }
}

extension UIColor {
    convenience init(hexString: String) {
        var trimmedString = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if trimmedString.hasPrefix("#") {
            trimmedString.remove(at: trimmedString.startIndex)
        }

        var rgbValue: UInt32 = 0
        Scanner(string: trimmedString).scanHexInt32(&rgbValue)

        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: 1)
    }
}

let tooltipArrowImageDark: UIImage = arrowImage(true, UIColor(hexString: "#D2D5D7"))
let tooltipArrowImageLigth: UIImage = arrowImage(true, UIColor(hexString: "#59606D").withAlphaComponent(0.3))

// https://telegra.ph/iOS-Design-Specification-04-07
struct Theme: Hashable {
    let gridLines: UIColor
    let axisText: UIColor
    let scrollBackground: UIColor
    let scrollSelector: UIColor
    let barMask: UIColor
    let zoomOutText: UIColor
    let tooltipArrowImage: UIImage

    let mainBackgroundColor: UIColor
    let secondaryBackgroundColor: UIColor
    let mainTextColor: UIColor
    let tooltipTextColor: UIColor

    var lineWidth: CGFloat

    static var light: Theme {
        return Theme(
            gridLines: UIColor(hexString: "#182D3B").withAlphaComponent(0.1),
            axisText: UIColor(hexString: "#8E8E93"),
            scrollBackground: UIColor(hexString: "#E2EEF9").withAlphaComponent(0.6),
            scrollSelector: UIColor(hexString: "#C0D1E1"),
            barMask: UIColor(hexString: "#FFFFFF").withAlphaComponent(0.5),
            zoomOutText: UIColor(hexString: "#108BE3"),
            tooltipArrowImage: tooltipArrowImageLigth,

            mainBackgroundColor: .white,
            secondaryBackgroundColor: UIColor(hexString: "#f0f0f5"),
            mainTextColor: .darkText,

            tooltipTextColor: UIColor(hexString: "#8E8E93"),
            lineWidth: 2
        )
    }

    static var dark: Theme {
        return Theme(
            gridLines: UIColor(hexString: "#8596AB").withAlphaComponent(0.2),
            axisText: UIColor(hexString: "#8596AB"),
            scrollBackground: UIColor(hexString: "#18222D").withAlphaComponent(0.6),
            scrollSelector: UIColor(hexString: "#56626D"),
            barMask: UIColor(hexString: "#212F3F").withAlphaComponent(0.5),
            zoomOutText: UIColor(hexString: "#2EA6FE"),
            tooltipArrowImage: tooltipArrowImageDark,

            mainBackgroundColor: UIColor(hexString: "#242f3e"),
            secondaryBackgroundColor: UIColor(hexString: "#1a222c"),
            mainTextColor: .white,

            tooltipTextColor: .white,
            lineWidth: 2
        )
    }
}

protocol Themable {
    func apply(_ theme: Theme)
}

extension UINavigationBar: Themable {
    func apply(_ theme: Theme) {
        barTintColor = theme.mainBackgroundColor
        isTranslucent = false
        titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: theme.mainTextColor,
        ]
        barStyle = theme == .dark ? .black : .default
    }
}

extension UITableViewController: Themable {
    func apply(_ theme: Theme) {
        tableView.visibleCells.forEach {
            ($0 as? Themable)?.apply(theme)
        }
        tableView.backgroundColor = theme.secondaryBackgroundColor
        tableView.separatorColor = theme.gridLines
    }
}

extension UINavigationController: Themable {
    func apply(_ theme: Theme) {
        navigationBar.apply(theme)

        children.forEach {
            ($0 as? Themable)?.apply(theme)
        }
    }
}

extension UISplitViewController: Themable {
    func apply(_ theme: Theme) {
        children.forEach {
            ($0 as? Themable)?.apply(theme)
        }
    }
}
