import Foundation

/// x.com の公開 syndication エンドポイントからツイートを取得する。
///
/// 埋め込みツイートが使うのと同じ公開 API なので、API キーや認証は不要。
/// 取得できるのは公開ツイートのみ。
public struct SyndicationClient: Sendable {
    public static let endpoint = "https://cdn.syndication.twimg.com/tweet-result"

    /// ブラウザからのアクセスに見せるための最低限のヘッダー。
    public static let defaultHeaders = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept": "application/json",
    ]

    private let http: HTTPClient
    private let language: String

    public init(http: HTTPClient = URLSessionHTTPClient(), language: String = "ja") {
        self.http = http
        self.language = language
    }

    /// 取得用の URL を組み立てる。
    public func requestURL(for tweetID: String) -> URL? {
        var components = URLComponents(string: Self.endpoint)
        components?.queryItems = [
            URLQueryItem(name: "id", value: tweetID),
            URLQueryItem(name: "lang", value: language),
            URLQueryItem(name: "token", value: SyndicationToken.make(for: tweetID)),
        ]
        return components?.url
    }

    /// ツイート URL（または ID）からツイートを取得する。
    public func tweet(from source: String) async throws -> Tweet {
        try await tweet(id: TweetURL.extractID(from: source))
    }

    /// ツイート ID からツイートを取得する。
    public func tweet(id tweetID: String) async throws -> Tweet {
        guard let url = requestURL(for: tweetID) else {
            throw TwiDropError.invalidURL("リクエスト URL を組み立てられませんでした。")
        }

        let data: Data
        let status: Int
        do {
            (data, status) = try await http.data(from: url, headers: Self.defaultHeaders)
        } catch {
            throw TwiDropError.fetchFailed(error.localizedDescription)
        }

        switch status {
        case 200..<300:
            return try TweetParser.parse(data: data, tweetID: tweetID)
        case 404:
            throw TwiDropError.tweetNotFound("ツイートが見つかりませんでした（ID: \(tweetID)）。")
        case 429:
            throw TwiDropError.rateLimited
        default:
            throw TwiDropError.fetchFailed("HTTP \(status)")
        }
    }
}
