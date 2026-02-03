import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Google Maps with your API key
        // Replace YOUR_IOS_API_KEY with your actual Google Maps API key
        GMSServices.provideAPIKey("YOUR_IOS_API_KEY")

        GeneratedPluginRegistrant.register(with: self)

        // Register screenshot detector for feedback feature
        if let controller = window?.rootViewController as? FlutterViewController {
            ScreenshotDetector.register(with: controller.registrar(forPlugin: "ScreenshotDetector")!)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
