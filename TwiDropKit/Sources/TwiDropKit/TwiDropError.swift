import Foundation

/// TwiDrop が投げるエラー。
public enum TwiDropError: LocalizedError, Equatable {
    /// ツイート URL として解釈できなかった。
    case invalidURL(String)
    /// 削除済み・非公開などで取得できなかった。
    case tweetNotFound(String)
    /// ネットワークや応答形式の問題で取得に失敗した。
    case fetchFailed(String)
    /// レート制限に達した。
    case rateLimited
    /// メディアのダウンロードに失敗した。
    case mediaDownloadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let detail):
            return detail
        case .tweetNotFound(let detail):
            return detail
        case .fetchFailed(let detail):
            return "取得に失敗しました: \(detail)"
        case .rateLimited:
            return "レート制限に達しました。しばらく待ってから再試行してください。"
        case .mediaDownloadFailed(let detail):
            return "メディアの保存に失敗しました: \(detail)"
        }
    }
}
