import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP 取得の抽象。テストではスタブに差し替える。
public protocol HTTPClient: Sendable {
    /// 本文をメモリ上に読み込む。
    func data(from url: URL, headers: [String: String]) async throws -> (Data, Int)
    /// 大きなファイルを一時ファイルへ書き出す。呼び出し側が移動・削除の責任を持つ。
    func download(from url: URL, headers: [String: String], to destination: URL) async throws -> Int
}

/// `URLSession` を使う既定の実装。
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL, headers: [String: String]) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request(url, headers))
        return (data, statusCode(of: response))
    }

    public func download(
        from url: URL, headers: [String: String], to destination: URL
    ) async throws -> Int {
        let (temporaryURL, response) = try await session.download(for: request(url, headers))
        let status = statusCode(of: response)
        guard (200..<300).contains(status) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            return status
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // 同名ファイルがあると moveItem が失敗するので先に取り除く。
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return status
    }

    private func request(_ url: URL, _ headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func statusCode(of response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}
