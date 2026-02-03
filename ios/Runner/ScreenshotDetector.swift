import Flutter
import UIKit
import Photos

/// Detects when screenshots are taken and notifies Flutter
/// Used in Lumina for the screenshot feedback feature
class ScreenshotDetector: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?
    private var isListening = false

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.carecompanion/screenshot",
            binaryMessenger: registrar.messenger()
        )
        let instance = ScreenshotDetector()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startListening":
            startListening()
            result(nil)

        case "stopListening":
            stopListening()
            result(nil)

        case "getLatestScreenshot":
            getLatestScreenshot(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startListening() {
        guard !isListening else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenshotTaken),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        isListening = true
    }

    private func stopListening() {
        guard isListening else { return }

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        isListening = false
    }

    @objc private func screenshotTaken() {
        // Notify Flutter that a screenshot was taken
        channel?.invokeMethod("onScreenshot", arguments: nil)
    }

    private func getLatestScreenshot(result: @escaping FlutterResult) {
        // Check photo library permission
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        guard status == .authorized || status == .limited else {
            // Request permission if not granted
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    self.fetchLatestScreenshot(result: result)
                } else {
                    result(nil)
                }
            }
            return
        }

        fetchLatestScreenshot(result: result)
    }

    private func fetchLatestScreenshot(result: @escaping FlutterResult) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        // Fetch only screenshots (mediaSubtypes includes .photoScreenshot)
        fetchOptions.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        guard let asset = fetchResult.firstObject else {
            result(nil)
            return
        }

        // Get the image file path
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat

        let manager = PHImageManager.default()

        // Request the image data to save to temporary file
        manager.requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
            guard let data = imageData else {
                result(nil)
                return
            }

            // Save to temporary file
            let tempDir = NSTemporaryDirectory()
            let filename = "screenshot_\(Date().timeIntervalSince1970).png"
            let filepath = (tempDir as NSString).appendingPathComponent(filename)

            do {
                try data.write(to: URL(fileURLWithPath: filepath))
                result(filepath)
            } catch {
                result(nil)
            }
        }
    }

    deinit {
        stopListening()
    }
}
