import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMS_API_KEY") as? String, !apiKey.isEmpty {
            GMSServices.provideAPIKey(apiKey)
        }

        GeneratedPluginRegistrant.register(with: self)

        // Register screenshot detector for feedback feature
        if let controller = window?.rootViewController as? FlutterViewController {
            ScreenshotDetector.register(with: controller.registrar(forPlugin: "ScreenshotDetector")!)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
