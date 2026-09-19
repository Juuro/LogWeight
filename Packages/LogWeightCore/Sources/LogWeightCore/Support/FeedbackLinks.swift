import Foundation

/// Links behind Settings → Feedback: the prefilled support email and the
/// App Store "write a review" deep link.
///
/// Diagnostics are limited to app, OS, and device model. Never add health
/// values or any user-entered data here.
public enum FeedbackLinks {
    public static let supportAddress = "support@juuronina.de"
    public static let appStoreID = "6764679748"

    public static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
    )!

    public struct Diagnostics: Equatable, Sendable {
        public let appVersion: String
        public let build: String
        public let osVersion: String
        public let deviceModel: String

        public init(appVersion: String, build: String, osVersion: String, deviceModel: String) {
            self.appVersion = appVersion
            self.build = build
            self.osVersion = osVersion
            self.deviceModel = deviceModel
        }

        /// Plain-text block appended below the user's message. Intentionally not
        /// localized so support can read it regardless of the user's language.
        var bodyBlock: String {
            "---\nLogWeight \(appVersion) (\(build))\niOS \(osVersion)\n\(deviceModel)"
        }
    }

    /// `mailto:` URL with subject and a body that leaves room for the user's
    /// message above the diagnostics block.
    public static func mailtoURL(
        address: String = supportAddress,
        subject: String,
        diagnostics: Diagnostics
    ) -> URL? {
        let body = "\n\n\n" + diagnostics.bodyBlock
        let string = "mailto:\(address)?subject=\(encode(subject))&body=\(encode(body))"
        return URL(string: string)
    }

    /// Percent-encodes everything except RFC 3986 unreserved characters, so
    /// `&`, `=`, `+`, `?`, and newlines in values cannot break the query.
    private static func encode(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
