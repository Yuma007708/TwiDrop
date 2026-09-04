import Foundation

/// syndication エンドポイントの応答を素直に写した DTO。
///
/// 応答には利用しないキーが多数含まれるため、必要な分だけを定義している。
struct SyndicationResponse: Decodable {
    let typename: String?
    let idString: String?
    let text: String?
    let language: String?
    let createdAt: String?
    let favoriteCount: Int?
    let conversationCount: Int?
    let possiblySensitive: Bool?
    let user: User?
    let mediaDetails: [MediaDetail]?
    let tombstone: Tombstone?

    enum CodingKeys: String, CodingKey {
        case typename = "__typename"
        case idString = "id_str"
        case text
        case language = "lang"
        case createdAt = "created_at"
        case favoriteCount = "favorite_count"
        case conversationCount = "conversation_count"
        case possiblySensitive = "possibly_sensitive"
        case user
        case mediaDetails
        case tombstone
    }

    struct User: Decodable {
        let name: String?
        let screenName: String?
        let profileImageURL: String?

        enum CodingKeys: String, CodingKey {
            case name
            case screenName = "screen_name"
            case profileImageURL = "profile_image_url_https"
        }
    }

    struct MediaDetail: Decodable {
        let type: String?
        let mediaURL: String?
        let originalInfo: OriginalInfo?
        let videoInfo: VideoInfo?

        enum CodingKeys: String, CodingKey {
            case type
            case mediaURL = "media_url_https"
            case originalInfo = "original_info"
            case videoInfo = "video_info"
        }
    }

    struct OriginalInfo: Decodable {
        let width: Int?
        let height: Int?
    }

    struct VideoInfo: Decodable {
        let durationMillis: Int?
        let variants: [Variant]?

        enum CodingKeys: String, CodingKey {
            case durationMillis = "duration_millis"
            case variants
        }
    }

    struct Variant: Decodable {
        let bitrate: Int?
        let contentType: String?
        let url: String?

        enum CodingKeys: String, CodingKey {
            case bitrate
            case contentType = "content_type"
            case url
        }
    }

    struct Tombstone: Decodable {
        let text: TombstoneText?

        struct TombstoneText: Decodable {
            let text: String?
        }
    }

    /// 削除済み・非公開などで本文が取れない応答かどうか。
    var isTombstone: Bool { typename == "TweetTombstone" }

    /// ツイートとして成立しているか。
    var looksLikeTweet: Bool { idString != nil || text != nil }
}
