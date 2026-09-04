import XCTest
@testable import TwiDropKit

final class MediaDownloaderTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("twidrop-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func videoMedia(
        _ urlString: String = "https://video.twimg.com/amplify_video/1/vid/1280x720/high.mp4?tag=13"
    ) throws -> TweetMedia {
        TweetMedia(id: "1", kind: .video, url: try XCTUnwrap(URL(string: urlString)))
    }

    func testSanitizeStripsUnsafeCharacters() {
        XCTAssertEqual(MediaDownloader.sanitize("NASA_123"), "NASA_123")
        XCTAssertEqual(MediaDownloader.sanitize("../../etc/passwd"), "etc_passwd")
        XCTAssertEqual(MediaDownloader.sanitize("a/b\\c"), "a_b_c")
        XCTAssertEqual(MediaDownloader.sanitize(""), "tweet")
    }

    func testFileNameUsesSlugIndexAndExtension() throws {
        let tweet = try TweetParser.parse(data: SampleResponses.videoTweet(), tweetID: "x")
        let media = try XCTUnwrap(tweet.media.first)

        XCTAssertEqual(
            MediaDownloader.fileName(for: media, tweet: tweet, index: 1),
            "test_user_1234567890123456789_1.mp4"
        )
    }

    func testDownloadWritesFile() async throws {
        let downloader = MediaDownloader(http: StubHTTPClient())
        let destination = directory.appendingPathComponent("video.mp4")

        let result = try await downloader.download(try videoMedia(), to: destination)

        XCTAssertEqual(result, destination)
        XCTAssertEqual(try Data(contentsOf: destination), Data("media".utf8))
    }

    func testDownloadSkipsExistingFile() async throws {
        let destination = directory.appendingPathComponent("video.mp4")
        try Data("existing".utf8).write(to: destination)
        let recorder = CallRecorder()

        _ = try await MediaDownloader(http: StubHTTPClient(recorder: recorder))
            .download(try videoMedia(), to: destination)

        XCTAssertEqual(try Data(contentsOf: destination), Data("existing".utf8))
        let requested = await recorder.urls
        XCTAssertTrue(requested.isEmpty, "既存ファイルがあるのに再取得された")
    }

    func testDownloadOverwritesWhenRequested() async throws {
        let destination = directory.appendingPathComponent("video.mp4")
        try Data("existing".utf8).write(to: destination)

        _ = try await MediaDownloader(http: StubHTTPClient())
            .download(try videoMedia(), to: destination, overwrite: true)

        XCTAssertEqual(try Data(contentsOf: destination), Data("media".utf8))
    }

    func testRejectsUnknownHostWithoutRequesting() async throws {
        let recorder = CallRecorder()
        let downloader = MediaDownloader(http: StubHTTPClient(recorder: recorder))
        let media = try videoMedia("https://evil.example.com/payload.mp4")
        let destination = directory.appendingPathComponent("evil.mp4")

        await assertThrows(TwiDropError.self, "許可されていないホスト") {
            _ = try await downloader.download(media, to: destination)
        } check: { error in
            guard case .mediaDownloadFailed(let detail) = error else {
                return XCTFail("mediaDownloadFailed を期待したが \(error) だった")
            }
            XCTAssertTrue(detail.contains("許可されていない"))
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        let requested = await recorder.urls
        XCTAssertTrue(requested.isEmpty)
    }

    func testHTTPErrorLeavesNoFile() async throws {
        let downloader = MediaDownloader(
            http: StubHTTPClient(downloadResult: { _ in (Data(), 403) })
        )
        let destination = directory.appendingPathComponent("video.mp4")

        await assertThrows(TwiDropError.self, "403") {
            _ = try await downloader.download(try self.videoMedia(), to: destination)
        } check: { error in
            XCTAssertEqual(error, .mediaDownloadFailed("HTTP 403"))
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testSendsRefererHeader() async throws {
        let recorder = CallRecorder()

        _ = try await MediaDownloader(http: StubHTTPClient(recorder: recorder))
            .download(try videoMedia(), to: directory.appendingPathComponent("v.mp4"))

        let sent = await recorder.headers
        XCTAssertEqual(sent.first?["Referer"], "https://x.com/")
    }
}
