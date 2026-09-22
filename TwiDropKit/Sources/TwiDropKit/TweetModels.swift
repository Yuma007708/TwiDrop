import Foundation

/// メディアの種類。
public enum MediaKind: String, Codable, Sendable {
    case photo
    case video
    case animatedGIF = "animated_gif"

    /// 動画として再生・保存すべきか。
    public var isVideo: Bool { self != .photo }
}

/// ツイートに添付された 1 件のメディア。
public struct TweetMedia: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let kind: MediaKind
    /// 実際にダウンロードする URL（画像は原寸、動画は最高画質の mp4）。
    public let url: URL
    /// サムネイル / ポスター画像。
    public let thumbnailURL: URL?
    public let width: Int?
    public let height: Int?
    public let durationMilliseconds: Int?
    public let bitrate: Int?

    public init(
        id: String,
        kind: MediaKind,
        url: URL,
        thumbnailURL: URL? = nil,
        width: Int? = nil,
        height: Int? = nil,
        durationMilliseconds: Int? = nil,
        bitrate: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.width = width
        self.height = height
        self.durationMilliseconds = durationMilliseconds
        self.bitrate = bitrate
    }

    /// 保存時の拡張子（ドットなし）。
    public var fileExtension: String {
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty, !name.isEmpty {
            return ext
        }
        return kind.isVideo ? "mp4" : "jpg"
    }

    /// 表示用の再生時間（`1:23` 形式）。
    public var formattedDuration: String? {
        guard let milliseconds = durationMilliseconds, milliseconds > 0 else { return nil }
        let totalSeconds = milliseconds / 1000
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

/// 1 件のツイート。
public struct Tweet: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let text: String
    public let authorName: String
    public let authorScreenName: String
    public let createdAt: Date?
    public let url: URL?
    public let likeCount: Int?
    public let replyCount: Int?
    public let language: String?
    public let authorAvatarURL: URL?
    public let possiblySensitive: Bool
    public let media: [TweetMedia]

    public init(
        id: String,
        text: String,
        authorName: String,
        authorScreenName: String,
        createdAt: Date? = nil,
        url: URL? = nil,
        likeCount: Int? = nil,
        replyCount: Int? = nil,
        language: String? = nil,
        authorAvatarURL: URL? = nil,
        possiblySensitive: Bool = false,
        media: [TweetMedia] = []
    ) {
        self.id = id
        self.text = text
        self.authorName = authorName
        self.authorScreenName = authorScreenName
        self.createdAt = createdAt
        self.url = url
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.language = language
        self.authorAvatarURL = authorAvatarURL
        self.possiblySensitive = possiblySensitive
        self.media = media
    }

    public var hasVideo: Bool { media.contains { $0.kind.isVideo } }

    /// 保存フォルダ名などに使う識別子。
    public var slug: String { "\(authorScreenName)_\(id)" }

    /// 人が読む用の Markdown。
    public func markdown() -> String {
        var lines = [
            "# @\(authorScreenName) (\(authorName))",
            "",
        ]
        if let createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone.current
            lines.append("- 投稿日時: \(formatter.string(from: createdAt))")
        }
        if let url {
            lines.append("- URL: \(url.absoluteString)")
        }
        if let likeCount {
            lines.append("- いいね: \(likeCount)")
        }
        lines.append(contentsOf: ["", "---", "", text, ""])
        if !media.isEmpty {
            lines.append(contentsOf: ["", "## 添付メディア", ""])
            for (index, item) in media.enumerated() {
                lines.append("\(index + 1). [\(item.kind.rawValue)] \(item.url.absoluteString)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
