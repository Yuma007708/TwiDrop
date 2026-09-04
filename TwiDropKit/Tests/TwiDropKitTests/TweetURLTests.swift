import XCTest
@testable import TwiDropKit

final class TweetURLTests: XCTestCase {
    func testExtractsIDFromSupportedURLs() throws {
        let cases: [(String, String)] = [
            ("https://x.com/NASA/status/1362551461910114310", "1362551461910114310"),
            ("https://twitter.com/jack/status/20", "20"),
            ("https://twitter.com/jack/status/20?s=20&t=abc", "20"),
            ("https://mobile.twitter.com/i/web/status/123456", "123456"),
            ("http://www.x.com/user/statuses/777", "777"),
            ("x.com/user/status/888", "888"),
            ("  https://x.com/user/status/999/photo/1  ", "999"),
            ("https://fxtwitter.com/user/status/555", "555"),
            ("1362551461910114310", "1362551461910114310"),
        ]

        for (input, expected) in cases {
            XCTAssertEqual(try TweetURL.extractID(from: input), expected, "input: \(input)")
        }
    }

    func testRejectsUnsupportedInput() {
        let cases = [
            "",
            "   ",
            "https://example.com/user/status/1",
            "https://x.com/NASA",
            "https://x.com/NASA/status/abc",
            "ただの文字列",
        ]

        for input in cases {
            XCTAssertThrowsError(try TweetURL.extractID(from: input), "input: \(input)") { error in
                guard case TwiDropError.invalidURL = error else {
                    return XCTFail("invalidURL を期待したが \(error) だった")
                }
            }
        }
    }

    func testFindsIDInSharedText() {
        // 共有シートからは本文つきのテキストが渡ってくることがある。
        let shared = "この動画すごい https://x.com/NASA/status/1362551461910114310?s=46 見て"
        XCTAssertEqual(TweetURL.firstID(inText: shared), "1362551461910114310")
    }

    func testFindsNothingInPlainText() {
        XCTAssertNil(TweetURL.firstID(inText: "ただのメモ https://example.com/a"))
    }

    func testCanonicalURL() {
        XCTAssertEqual(
            TweetURL.canonicalURL(id: "20", screenName: "jack")?.absoluteString,
            "https://x.com/jack/status/20"
        )
        XCTAssertEqual(
            TweetURL.canonicalURL(id: "20", screenName: nil)?.absoluteString,
            "https://x.com/i/web/status/20"
        )
    }
}
