import Foundation
import os

/// Privacy-respecting log facade.
///
/// LogWeight handles GDPR Art. 9 (special-category) health data. To ensure no
/// weight value, sample identifier, or user-identifying information is ever
/// written to a log, this API exposes ONLY:
/// - event names (compile-time literals)
/// - integer error codes
///
/// There is no overload that takes a `Double` weight, a `String` value, or a
/// `Date`. If you find yourself needing one, the answer is "log an event name
/// instead". This is enforced by API surface, not by convention.
public enum SecurityLog {

    private static let logger = Logger(
        subsystem: "dev.logweight.LogWeight",
        category: "weight"
    )

    /// Records that a known event happened. The event name MUST be a hard-coded
    /// literal — never derived from user data.
    public static func event(_ name: StaticString) {
        logger.info("event: \(String(describing: name), privacy: .public)")
    }

    /// Records a failure with a numeric error code. The code is safe to log; do
    /// not include surrounding context that might identify the user.
    public static func error(_ name: StaticString, code: Int) {
        logger.error("error: \(String(describing: name), privacy: .public) code=\(code, privacy: .public)")
    }
}
