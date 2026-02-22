import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GMSServices.provideAPIKey("AIzaSyCB29KVu2hTgM36fOMi8ZgyBErFeMzKgkg")

        GeneratedPluginRegistrant.register(with: self)

        // Register screenshot detector for feedback feature
        if let controller = window?.rootViewController as? FlutterViewController {
            ScreenshotDetector.register(with: controller.registrar(forPlugin: "ScreenshotDetector")!)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
