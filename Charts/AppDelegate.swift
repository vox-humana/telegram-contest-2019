import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let listVC = (window!.rootViewController as! UINavigationController).topViewController as! ListViewController
        measure("load data") {
            listVC.dataSources = ChartDataSource.loadStage2Data() + ChartDataSource.loadStage1Data() + [ChartDataSource.demo()]
        }
        return true
    }

    var theme: Theme = .light {
        didSet {
            (window?.rootViewController as? Themable)?.apply(theme)
        }
    }

    static var theme: Theme {
        set {
            (UIApplication.shared.delegate as! AppDelegate).theme = newValue
        }
        get {
            return (UIApplication.shared.delegate as! AppDelegate).theme
        }
    }
}
