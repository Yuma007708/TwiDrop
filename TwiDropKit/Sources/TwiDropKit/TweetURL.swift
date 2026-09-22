import Foundation

/// ツイート URL の解析。
public enum TweetURL {
    /// ツイート URL として受け付けるホスト。
    public static let allowedHosts: Set<String> = [
        "twitter.com", "www.twitter.com", "mobile.twitter.com",
        "x.com", "www.x.com", "mobile.x.com",
        // よく使われるフロントエンド。パスの形式は本家と同じ。
        "fxtwitter.com", "vxtwitter.com", "fixupx.com", "nitter.net",
    ]

    private static let maxIDLength = 25

    /// ツイート URL（または ID そのもの）からツイート ID を取り出す。
    ///
    /// クエリ付き URL、`mobile.` / `www.` 付きドメイン、`/i/web/status/` 形式、
    /// 末尾の `/photo/1` などに対応する。
    public static func extractID(from source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TwiDropError.invalidURL("URL が空です。")
        }

        if isNumericID(text) {
            return text
        }

        let normalized = text.contains("://") ? text : "https://\(text)"
        guard let components = URLComponents(string: normalized),
              let host = components.host?.lowercased()
        else {
            throw TwiDropError.invalidURL("URL として解釈できません: \(text)")
        }

        guard allowedHosts.contains(host) else {
            throw TwiDropError.invalidURL(
                "対応していないドメインです: \(host)（twitter.com / x.com の URL を指定してください）"
            )
        }

        let segments = components.path.split(separator: "/").map(String.init)
        guard let statusIndex = segments.firstIndex(where: { $0 == "status" || $0 == "statuses" }),
              statusIndex + 1 < segments.count
        else {
            throw TwiDropError.invalidURL(
                "ツイート URL ではありません: \(text)（.../status/<数字> の形式が必要です）"
            )
        }

        let candidate = segments[statusIndex + 1]
        guard isNumericID(candidate) else {
            throw TwiDropError.invalidURL("ツイート ID が数字ではありません: \(candidate)")
        }
        return candidate
    }

    /// 文字列中から最初に見つかったツイート URL の ID を取り出す。
    ///
    /// 共有シートから「〜 https://x.com/user/status/123」のような
    /// テキストが渡ってくる場合に使う。
    public static func firstID(inText text: String) -> String? {
        for token in text.split(whereSeparator: { $0.isWhitespace || $0 == "\n" }) {
            if let id = try? extractID(from: String(token)) {
                return id
            }
        }
        return nil
    }

    /// ツイート ID から x.com の正規 URL を組み立てる。
    public static func canonicalURL(id: String, screenName: String?) -> URL? {
        URL(string: "https://x.com/\(screenName ?? "i/web")/status/\(id)")
    }

    private static func isNumericID(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= maxIDLength
            && value.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
