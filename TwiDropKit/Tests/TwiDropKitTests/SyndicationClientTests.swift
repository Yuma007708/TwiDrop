import XCTest
@testable import TwiDropKit

final class SyndicationClientTests: XCTestCase {
    func testRequestURLContainsIDLanguageAndToken() throws {
        let client = SyndicationClient(http: StubHTTPClient(), language: "ja")
        let url = try XCTUnwrap(client.requestURL(for: "20"))
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        XCTAssertTrue(url.absoluteString.hasPrefix(SyndicationClient.endpoint))
        XCTAssertEqual(query.first { $0.name == "id" }?.value, "20")
        XCTAssertEqual(query.first { $0.name == "lang" }?.value, "ja")
        XCTAssertEqual(query.first { $0.name == "token" }?.value, SyndicationToken.make(for: "20"))
    }

    func testFetchesTweetFromURL() async throws {
        let recorder = CallRecorder()
        let client = SyndicationClient(
            http: StubHTTPClient(recorder: recorder, dataResult: { _ in (SampleResponses.videoTweet(), 200) })
        )

        let tweet = try await client.tweet(from: "https://x.com/test_user/status/1234567890123456789")

        XCTAssertEqual(tweet.authorScreenName, "test_user")
        XCTAssertTrue(tweet.hasVideo)

        let requested = await recorder.urls
        XCTAssertEqual(requested.count, 1)
        XCTAssertTrue(requested[0].absoluteString.contains("id=1234567890123456789"))
    }

    func testSendsBrowserLikeHeaders() async throws {
        let recorder = CallRecorder()
        let client = SyndicationClient(
            http: StubHTTPClient(recorder: recorder, dataResult: { _ in (SampleResponses.textTweet(), 200) })
        )

        _ = try await client.tweet(id: "111")

        let sent = await recorder.headers
        XCTAssertEqual(sent.first?["Accept"], "application/json")
        XCTAssertNotNil(sent.first?["User-Agent"])
    }

    func testInvalidURLThrowsBeforeAnyRequest() async {
        let recorder = CallRecorder()
        let client = SyndicationClient(http: StubHTTPClient(recorder: recorder))

        await assertThrows(TwiDropError.self, "不正な URL") {
            _ = try await client.tweet(from: "https://example.com/nope")
        } check: { error in
            guard case .invalidURL = error else {
                return XCTFail("invalidURL を期待したが \(error) だった")
            }
        }

        let requested = await recorder.urls
        XCTAssertTrue(requested.isEmpty, "解析に失敗した時点で通信すべきでない")
    }

    func testNotFoundStatusThrows() async {
        let client = SyndicationClient(http: StubHTTPClient(dataResult: { _ in (Data(), 404) }))

        await assertThrows(TwiDropError.self, "404") {
            _ = try await client.tweet(id: "20")
        } check: { error in
            guard case .tweetNotFound = error else {
                return XCTFail("tweetNotFound を期待したが \(error) だった")
            }
        }
    }

    func testRateLimitThrows() async {
        let client = SyndicationClient(http: StubHTTPClient(dataResult: { _ in (Data(), 429) }))

        await assertThrows(TwiDropError.self, "429") {
            _ = try await client.tweet(id: "20")
        } check: { error in
            XCTAssertEqual(error, .rateLimited)
        }
    }

    func testServerErrorThrowsFetchFailed() async {
        let client = SyndicationClient(http: StubHTTPClient(dataResult: { _ in (Data(), 503) }))

        await assertThrows(TwiDropError.self, "503") {
            _ = try await client.tweet(id: "20")
        } check: { error in
            XCTAssertEqual(error, .fetchFailed("HTTP 503"))
        }
    }

    func testTransportErrorThrowsFetchFailed() async {
        let client = SyndicationClient(http: StubHTTPClient(dataResult: { _ in throw StubNetworkError() }))

        await assertThrows(TwiDropError.self, "通信断") {
            _ = try await client.tweet(id: "20")
        } check: { error in
            guard case .fetchFailed = error else {
                return XCTFail("fetchFailed を期待したが \(error) だった")
            }
        }
    }
}

extension XCTestCase {
    /// 非同期処理が指定した型のエラーを投げることを確かめる。
    func assertThrows<E: Error>(
        _ type: E.Type,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void,
        check: (E) -> Void
    ) async {
        do {
            try await operation()
            XCTFail("エラーを期待したが成功した: \(message)", file: file, line: line)
        } catch let error as E {
            check(error)
        } catch {
            XCTFail("\(type) を期待したが \(error) だった: \(message)", file: file, line: line)
        }
    }
}
