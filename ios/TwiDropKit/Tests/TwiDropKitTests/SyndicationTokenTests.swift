import XCTest
@testable import TwiDropKit

final class SyndicationTokenTests: XCTestCase {
    /// 同じアルゴリズムの Python 実装（`twidrop/syndication.py`）が出す値と一致すること。
    /// どちらかを直したときにずれたら気付けるようにしている。
    func testMatchesReferenceImplementation() {
        let expected = [
            "20": "6dq1a2xwd93",
            "111": "zeyp3r4jfxrc",
            "999": "8uqo9xs4uzmbt",
            "1234567890123456789": "2zqic77uqyke67ncb9wqxgv",
            "1362551461910114310": "3awkxu29rh51vhryh1l9pb9",
        ]

        for (tweetID, token) in expected {
            XCTAssertEqual(SyndicationToken.make(for: tweetID), token, "id: \(tweetID)")
        }
    }

    func testIsDeterministic() {
        XCTAssertEqual(
            SyndicationToken.make(for: "1362551461910114310"),
            SyndicationToken.make(for: "1362551461910114310")
        )
    }

    func testDifferentIDsProduceDifferentTokens() {
        XCTAssertNotEqual(SyndicationToken.make(for: "20"), SyndicationToken.make(for: "21"))
    }

    func testTokenIsURLSafe() {
        let token = SyndicationToken.make(for: "1362551461910114310")

        XCTAssertFalse(token.isEmpty)
        XCTAssertFalse(token.contains("0"))
        XCTAssertFalse(token.contains("."))
        XCTAssertTrue(token.allSatisfy { $0.isLetter || $0.isNumber })
    }

    func testBase36OfKnownValues() {
        XCTAssertTrue(SyndicationToken.base36(0).hasPrefix("0."))
        XCTAssertTrue(SyndicationToken.base36(35).hasPrefix("z."))
        XCTAssertTrue(SyndicationToken.base36(36).hasPrefix("10."))
    }
}
