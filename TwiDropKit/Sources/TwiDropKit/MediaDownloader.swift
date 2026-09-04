import Foundation

/// メディアファイルのダウンロード。
public struct MediaDownloader: Sendable {
    /// 取得を許可するホスト。ここに無い URL は取りに行かない。
    public static let allowedHosts: Set<String> = ["pbs.twimg.com", "video.twimg.com"]

    public static let defaultHeaders = [
        "User-Agent": SyndicationClient.defaultHeaders["User-Agent"] ?? "",
        "Referer": "https://x.com/",
    ]

    private let http: HTTPClient

    public init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    /// メディア 1 件を `destination` に保存する。
    ///
    /// 既にファイルがあり `overwrite` が false なら再取得しない。
    @discardableResult
    public func download(
        _ media: TweetMedia, to destination: URL, overwrite: Bool = false
    ) async throws -> URL {
        guard let host = media.url.host?.lowercased(), Self.allowedHosts.contains(host) else {
            throw TwiDropError.mediaDownloadFailed("許可されていない配信元です: \(media.url.host ?? "不明")")
        }
        if FileManager.default.fileExists(atPath: destination.path), !overwrite {
            return destination
        }

        let status: Int
        do {
            status = try await http.download(
                from: media.url, headers: Self.defaultHeaders, to: destination
            )
        } catch {
            throw TwiDropError.mediaDownloadFailed(error.localizedDescription)
        }
        guard (200..<300).contains(status) else {
            throw TwiDropError.mediaDownloadFailed("HTTP \(status)")
        }
        return destination
    }

    /// 保存時のファイル名（例: `NASA_1362551461910114310_1.mp4`）。
    public static func fileName(for media: TweetMedia, tweet: Tweet, index: Int) -> String {
        "\(sanitize(tweet.slug))_\(index).\(media.fileExtension)"
    }

    /// ファイル名に使えない文字を落とす。
    public static func sanitize(_ value: String, fallback: String = "tweet") -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let mapped = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let collapsed = String(mapped)
            .split(separator: "_", omittingEmptySubsequences: true)
            .joined(separator: "_")
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "._"))
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(80))
    }
}
