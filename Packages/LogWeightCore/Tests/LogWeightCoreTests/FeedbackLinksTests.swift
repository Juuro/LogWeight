import XCTest
@testable import LogWeightCore

final class FeedbackLinksTests: XCTestCase {

    private let diagnostics = FeedbackLinks.Diagnostics(
        appVersion: "0.5.0",
        build: "123",
        osVersion: "26.0",
        deviceModel: "iPhone17,1"
    )

    private func components(_ url: URL?) throws -> URLComponents {
        let url = try XCTUnwrap(url)
        return try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    }

    func testMailtoTargetsSupportAddress() throws {
        let parts = try components(FeedbackLinks.mailtoURL(subject: "LogWeight feedback", diagnostics: diagnostics))
        XCTAssertEqual(parts.scheme, "mailto")
        XCTAssertEqual(parts.path, "support@juuronina.de")
    }

    func testMailtoRoundTripsSubjectAndBody() throws {
        let parts = try components(FeedbackLinks.mailtoURL(subject: "LogWeight feedback", diagnostics: diagnostics))
        let items = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["subject"], "LogWeight feedback")
        XCTAssertEqual(items["body"], "\n\n\n---\nLogWeight 0.5.0 (123)\niOS 26.0\niPhone17,1")
    }

    func testReservedCharactersInSubjectStayInsideOneQueryItem() throws {
        let parts = try components(FeedbackLinks.mailtoURL(subject: "a&b=c+d?e", diagnostics: diagnostics))
        let items = parts.queryItems ?? []
        XCTAssertEqual(items.map(\.name), ["subject", "body"])
        XCTAssertEqual(items.first?.value, "a&b=c+d?e")
    }

    func testNonASCIISubjectRoundTrips() throws {
        let parts = try components(FeedbackLinks.mailtoURL(subject: "LogWeight 反馈 – Rückmeldung", diagnostics: diagnostics))
        XCTAssertEqual(parts.queryItems?.first?.value, "LogWeight 反馈 – Rückmeldung")
    }

    func testWriteReviewURLPointsAtAppStoreReviewAction() {
        XCTAssertEqual(
            FeedbackLinks.writeReviewURL.absoluteString,
            "https://apps.apple.com/app/id6764679748?action=write-review"
        )
    }
}
