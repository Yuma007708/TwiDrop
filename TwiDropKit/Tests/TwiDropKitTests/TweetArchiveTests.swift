import XCTest
@testable import TwiDropKit

final class TweetArchiveTests: XCTestCase {
    private var baseDirectory: URL!

    override func setUpWithError() throws {
        baseDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("twidrop-archive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: baseDirectory)
    }

    private func archive(
        _ stub: StubHTTPClient = StubHTTPClient()
    ) -> TweetArchive {
        TweetArchive(baseDirectory: baseDirectory, downloader: MediaDownloader(http: stub))
    }

    private func videoTweet() throws -> Tweet {
        try TweetParser.parse(data: SampleResponses.videoTweet(), tweetID: "x")
    }

    func testSaveWritesMetadataMarkdownAndMedia() async throws {
        let tweet = try videoTweet()

        let saved = try await archive().save(tweet)

        XCTAssertEqual(saved.directory.lastPathComponent, "test_user_1234567890123456789")
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.metadataFile.path))
        XCTAssertEqual(saved.mediaFiles.map(\.lastPathComponent), [
            "test_user_1234567890123456789_1.mp4"
        ])
        XCTAssertTrue(saved.skipped.isEmpty)

        let markdown = try String(contentsOf: saved.markdownFile, encoding: .utf8)
        XCTAssertTrue(markdown.contains("@test_user"))
        XCTAssertTrue(markdown.contains("テスト投稿です"))
    }

    func testSavedMetadataRoundTrips() async throws {
        let tweet = try videoTweet()

        _ = try await archive().save(tweet)
        let reloaded = try XCTUnwrap(archive().saved().first)

        XCTAssertEqual(reloaded.tweet, tweet)
        XCTAssertEqual(reloaded.mediaFiles.count, 1)
        XCTAssertEqual(reloaded.videoFiles.count, 1)
    }

    func testSaveWithoutMedia() async throws {
        let saved = try await archive().save(try videoTweet(), includeMedia: false)

        XCTAssertTrue(saved.mediaFiles.isEmpty)
        let contents = try FileManager.default.contentsOfDirectory(atPath: saved.directory.path)
        XCTAssertEqual(contents.sorted(), ["tweet.json", "tweet.md"])
    }

    func testFailedMediaIsRecordedButTextIsKept() async throws {
        let failing = StubHTTPClient(downloadResult: { _ in (Data(), 500) })

        let saved = try await archive(failing).save(try videoTweet())

        XCTAssertTrue(saved.mediaFiles.isEmpty)
        XCTAssertEqual(saved.skipped.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.markdownFile.path))
    }

    func testIsSavedReflectsState() async throws {
        let tweet = try videoTweet()
        let archive = archive()

        XCTAssertFalse(archive.isSaved(tweet))
        _ = try await archive.save(tweet)
        XCTAssertTrue(archive.isSaved(tweet))
    }

    func testSavedListIsEmptyInitially() {
        XCTAssertTrue(archive().saved().isEmpty)
    }

    func testSavedListsEveryStoredTweet() async throws {
        let archive = archive()

        _ = try await archive.save(try videoTweet())
        _ = try await archive.save(
            try TweetParser.parse(data: SampleResponses.textTweet(), tweetID: "x")
        )

        XCTAssertEqual(Set(archive.saved().map(\.tweet.id)), ["1234567890123456789", "111"])
    }

    func testDeleteRemovesDirectory() async throws {
        let archive = archive()
        let saved = try await archive.save(try videoTweet())

        try archive.delete(saved)

        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.directory.path))
        XCTAssertTrue(archive.saved().isEmpty)
    }

    func testUnrelatedDirectoriesAreIgnored() async throws {
        let stray = baseDirectory.appendingPathComponent("not-a-tweet")
        try FileManager.default.createDirectory(at: stray, withIntermediateDirectories: true)

        _ = try await archive().save(try videoTweet())

        XCTAssertEqual(archive().saved().count, 1)
    }
}
