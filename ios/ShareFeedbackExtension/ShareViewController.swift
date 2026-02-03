import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

/// Share Extension for Lumina feedback submissions
/// Allows users to share screenshots and text directly to Firestore
class ShareViewController: SLComposeServiceViewController {

    // MARK: - Properties

    private var sharedImage: UIImage?
    private var sharedText: String?
    private var sharedURL: URL?
    private var ccEmail: String?

    // Configuration item for CC email
    private lazy var ccEmailItem: SLComposeSheetConfigurationItem = {
        let item = SLComposeSheetConfigurationItem()!
        item.title = "CC Email"
        item.value = ccEmail ?? "None"
        item.tapHandler = { [weak self] in
            self?.showEmailInput()
        }
        return item
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the title
        navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Post"
        title = "Lumina Feedback"

        // Load user's email from App Group if available
        loadUserEmail()

        // Extract shared content
        extractSharedContent()
    }

    // MARK: - Configuration Items

    override func configurationItems() -> [Any]! {
        return [ccEmailItem]
    }

    // MARK: - Validation

    override func isContentValid() -> Bool {
        // Valid if we have either text content or an image
        let hasText = (contentText?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0) > 0
        let hasImage = sharedImage != nil
        return hasText || hasImage
    }

    // MARK: - Post Action

    override func didSelectPost() {
        // Get the API endpoint and key from the xcconfig
        guard let apiURL = getConfigValue("REPAIR_TASK_CREATE_URL"),
              let apiKey = getConfigValue("REPAIR_TASK_API_KEY") else {
            showError("Configuration error: Missing API settings")
            return
        }

        // Prepare the request
        guard let url = URL(string: apiURL) else {
            showError("Invalid API URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add message field
        let message = contentText ?? ""
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"message\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(message)\r\n".data(using: .utf8)!)

        // Add type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
        body.append("bug\r\n".data(using: .utf8)!)

        // Add platform field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"platform\"\r\n\r\n".data(using: .utf8)!)
        body.append("ios\r\n".data(using: .utf8)!)

        // Add source field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"\r\n\r\n".data(using: .utf8)!)
        body.append("share\r\n".data(using: .utf8)!)

        // Add app name field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"appName\"\r\n\r\n".data(using: .utf8)!)
        body.append("Lumina\r\n".data(using: .utf8)!)

        // Add CC email if provided
        if let email = ccEmail, !email.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ccEmail\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(email)\r\n".data(using: .utf8)!)
        }

        // Add shared URL if present
        if let sharedURL = sharedURL {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"url\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(sharedURL.absoluteString)\r\n".data(using: .utf8)!)
        }

        // Add image if present
        if let image = sharedImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"screenshot.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Send the request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showError("Failed to submit: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        // Success - complete the extension
                        self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    } else if httpResponse.statusCode == 401 {
                        self?.showError("Unauthorized: Check API key configuration")
                    } else {
                        self?.showError("Server error: \(httpResponse.statusCode)")
                    }
                }
            }
        }
        task.resume()
    }

    // MARK: - Content Extraction

    private func extractSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Check for images
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL {
                            if let data = try? Data(contentsOf: url),
                               let image = UIImage(data: data) {
                                self?.sharedImage = image
                            }
                        } else if let image = item as? UIImage {
                            self?.sharedImage = image
                        } else if let data = item as? Data,
                                  let image = UIImage(data: data) {
                            self?.sharedImage = image
                        }
                    }
                }

                // Check for URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL {
                            self?.sharedURL = url
                        }
                    }
                }

                // Check for text
                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (item, error) in
                        if let text = item as? String {
                            self?.sharedText = text
                        }
                    }
                }
            }
        }
    }

    // MARK: - App Group Data

    private func loadUserEmail() {
        // Try to load user email from App Group
        if let defaults = UserDefaults(suiteName: "group.com.carecompanion.app") {
            ccEmail = defaults.string(forKey: "userEmail")
            ccEmailItem.value = ccEmail ?? "None"
        }
    }

    // MARK: - Email Input

    private func showEmailInput() {
        let alert = UIAlertController(
            title: "CC Email",
            message: "Enter an email address to receive a copy of this feedback",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "email@example.com"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.text = self.ccEmail
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let email = alert.textFields?.first?.text, !email.isEmpty {
                self?.ccEmail = email
                self?.ccEmailItem.value = email
            } else {
                self?.ccEmail = nil
                self?.ccEmailItem.value = "None"
            }
        })

        present(alert, animated: true)
    }

    // MARK: - Configuration Values

    private func getConfigValue(_ key: String) -> String? {
        // Try to get value from Info.plist (populated from xcconfig)
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(
                domain: "com.carecompanion.app.ShareFeedbackExtension",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        })
        present(alert, animated: true)
    }
}
