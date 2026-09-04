import Foundation
@testable import TwiDropKit

/// 通信せずに決め打ちの応答を返す ``HTTPClient``。
struct StubHTTPClient: HTTPClient {
    /// 呼び出しの記録先。テスト本体から参照する。
    let recorder: CallRecorder
    let dataResult: @Sendable (URL) throws -> (Data, Int)
    let downloadResult: @Sendable (URL) throws -> (Data, Int)

    init(
        recorder: CallRecorder = CallRecorder(),
        dataResult: @escaping @Sendable (URL) throws -> (Data, Int) = { _ in (Data(), 200) },
        downloadResult: @escaping @Sendable (URL) throws -> (Data, Int) = { _ in
            (Data("media".utf8), 200)
        }
    ) {
        self.recorder = recorder
        self.dataResult = dataResult
        self.downloadResult = downloadResult
    }

    func data(from url: URL, headers: [String: String]) async throws -> (Data, Int) {
        await recorder.record(url: url, headers: headers)
        return try dataResult(url)
    }

    func download(from url: URL, headers: [String: String], to destination: URL) async throws -> Int {
        await recorder.record(url: url, headers: headers)
        let (payload, status) = try downloadResult(url)
        guard (200..<300).contains(status) else { return status }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try payload.write(to: destination)
        return status
    }
}

/// スタブへの呼び出しを順番に覚えておく。
actor CallRecorder {
    private(set) var urls: [URL] = []
    private(set) var headers: [[String: String]] = []

    func record(url: URL, headers: [String: String]) {
        urls.append(url)
        self.headers.append(headers)
    }
}

/// 通信エラーを再現するためのエラー。
struct StubNetworkError: Error {}
