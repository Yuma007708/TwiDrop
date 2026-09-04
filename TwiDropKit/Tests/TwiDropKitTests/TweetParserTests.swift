import XCTest
@testable import TwiDropKit

final class TweetParserTests: XCTestCase {
    func testParsesVideoTweetAndPicksHighestBitrateMP4() throws {
        let tweet = try TweetParser.parse(data: SampleResponses.videoTweet(), tweetID: "x")

        XCTAssertEqual(tweet.id, "1234567890123456789")
        XCTAssertEqual(tweet.authorScreenName, "test_user")
        XCTAssertEqual(tweet.authorName, "テスト太郎")
        XCTAssertEqual(tweet.likeCount, 42)
        XCTAssertEqual(tweet.replyCount, 7)
        XCTAssertEqual(tweet.language, "ja")
        XCTAssertTrue(tweet.hasVideo)
        XCTAssertEqual(tweet.slug, "test_user_1234567890123456789")

        XCTAssertEqual(tweet.media.count, 1)
        let media = try XCTUnwrap(tweet.media.first)
        XCTAssertEqual(media.kind, .video)
        XCTAssertEqual(media.bitrate, 2176000)
        XCTAssertTrue(media.url.absoluteString.hasSuffix("1280x720/high.mp4?tag=13"))
        XCTAssertEqual(media.fileExtension, "mp4")
        XCTAssertEqual(media.formattedDuration, "1:15")
    }

    func testStripsTrailingMediaLinkFromText() throws {
        let tweet = try TweetParser.parse(data: SampleResponses.videoTweet(), tweetID: "x")

        XCTAssertEqual(tweet.text, "テスト投稿です")
    }

    func testParsesCreatedAt() throws {
        let tweet = try TweetParser.parse(data: SampleResponses.videoTweet(), tweetID: "x")
        let createdAt = try XCTUnwrap(tweet.createdAt)

        var components = DateComponents()
        components.year = 2024
        components.month = 5
        components.day = 1
        components.hour = 12
        components.minute = 34
        components.second = 56
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        XCTAssertEqual(createdAt, calendar.date(from: components))
    }

    func testParsesPhotoTweetAtOriginalSize() throws {
        let tweet = try TweetParser.parse(data: SampleResponses.photoTweet(), tweetID: "x")

        XCTAssertFalse(tweet.hasVideo)
        XCTAssertEqual(tweet.media.map(\.kind), [.photo, .photo])
        XCTAssertEqual(
            tweet.media[0].url.absoluteString,
            "https://pbs.twimg.com/media/AAA?format=jpg&name=orig"
        )
        XCTAssertEqual(
            tweet.media[0].thumbnailURL?.absoluteString,
            "https://pbs.twimg.com/media/AAA.jpg"
        )
        // HTML エスケープが戻り、末尾のメディアリンクが落ちている。
        XCTAssertEqual(tweet.text, "写真つき & テキスト")
    }

    func testParsesTextOnlyTweet() throws {
        let tweet = try TweetParser.parse(data: SampleResponses.textTweet(), tweetID: "x")

        XCTAssertTrue(tweet.media.isEmpty)
        XCTAssertFalse(tweet.hasVideo)
        XCTAssertEqual(tweet.text, "ただのテキスト")
        XCTAssertEqual(tweet.url?.absoluteString, "https://x.com/plain/status/111")
    }

    func testTombstoneThrowsNotFound() {
        XCTAssertThrowsError(
            try TweetParser.parse(data: SampleResponses.tombstone(), tweetID: "20")
        ) { error in
            guard case TwiDropError.tweetNotFound(let detail) = error else {
                return XCTFail("tweetNotFound を期待したが \(error) だった")
            }
            XCTAssertEqual(detail, "この投稿は削除されました")
        }
    }

    func testHTMLResponseThrowsNotFound() {
        XCTAssertThrowsError(try TweetParser.parse(data: SampleResponses.html(), tweetID: "20")) { error in
            guard case TwiDropError.tweetNotFound = error else {
                return XCTFail("tweetNotFound を期待したが \(error) だった")
            }
        }
    }

    func testHLSOnlyVideoIsSkipped() {
        let variants = [
            SyndicationResponse.Variant(
                bitrate: nil,
                contentType: "application/x-mpegURL",
                url: "https://video.twimg.com/a/pl/x.m3u8"
            )
        ]

        XCTAssertNil(TweetParser.bestVideoVariant(variants))
    }

    func testMarkdownContainsMetadataAndMedia() throws {
        let markdown = try TweetParser.parse(data: SampleResponses.videoTweet(), tweetID: "x").markdown()

        XCTAssertTrue(markdown.contains("@test_user (テスト太郎)"))
        XCTAssertTrue(markdown.contains("テスト投稿です"))
        XCTAssertTrue(markdown.contains("いいね: 42"))
        XCTAssertTrue(markdown.contains("high.mp4"))
    }

    func testHTMLEntityDecoding() {
        XCTAssertEqual(HTMLEntities.decode("a &amp; b"), "a & b")
        XCTAssertEqual(HTMLEntities.decode("&lt;tag&gt;"), "<tag>")
        XCTAssertEqual(HTMLEntities.decode("&quot;quoted&quot;"), "\"quoted\"")
        XCTAssertEqual(HTMLEntities.decode("&#39;"), "'")
        XCTAssertEqual(HTMLEntities.decode("&#x3042;"), "あ")
        // エンティティでない & はそのまま残す。
        XCTAssertEqual(HTMLEntities.decode("R&D and Q&A"), "R&D and Q&A")
        XCTAssertEqual(HTMLEntities.decode("エンティティなし"), "エンティティなし")
    }
}
