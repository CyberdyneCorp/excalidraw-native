import XCTest
@testable import ExcalidrawModel

final class EmbedAllowListTests: XCTestCase {
    func testYouTubeWatchBecomesEmbed() {
        let url = EmbedAllowList.embedURL(for: "https://www.youtube.com/watch?v=abc123")
        XCTAssertEqual(url?.absoluteString, "https://www.youtube.com/embed/abc123")
    }

    func testYouTubeShortLink() {
        let url = EmbedAllowList.embedURL(for: "https://youtu.be/xyz789")
        XCTAssertEqual(url?.absoluteString, "https://www.youtube.com/embed/xyz789")
    }

    func testVimeoBecomesPlayerURL() {
        let url = EmbedAllowList.embedURL(for: "https://vimeo.com/123456789")
        XCTAssertEqual(url?.absoluteString, "https://player.vimeo.com/video/123456789")
    }

    func testAllowListedHostPassesThroughAsIs() {
        let url = EmbedAllowList.embedURL(for: "https://www.figma.com/file/abc/Design")
        XCTAssertEqual(url?.host, "www.figma.com")
    }

    func testDisallowedHostReturnsNil() {
        XCTAssertNil(EmbedAllowList.embedURL(for: "https://evil.example.com/page"))
        XCTAssertFalse(EmbedAllowList.isEmbeddable("https://evil.example.com"))
        XCTAssertFalse(EmbedAllowList.isEmbeddable(nil))
    }

    func testNonHTTPSchemeRejected() {
        XCTAssertNil(EmbedAllowList.embedURL(for: "javascript:alert(1)"))
        XCTAssertNil(EmbedAllowList.embedURL(for: "ftp://youtube.com/x"))
    }

    func testIsEmbeddableMatchesAllowList() {
        XCTAssertTrue(EmbedAllowList.isEmbeddable("https://youtu.be/abc"))
    }
}
