import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps init — does not require Flutter engine, safe in didFinishLaunching.
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMS_API_KEY") as? String, !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register screenshot detector plugin.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenshotDetector") {
      ScreenshotDetector.register(with: registrar)
    }
  }
}
