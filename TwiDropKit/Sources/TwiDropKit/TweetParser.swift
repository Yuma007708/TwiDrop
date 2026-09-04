import Foundation

/// syndication API の応答を ``Tweet`` に変換する。
public enum TweetParser {
    /// 応答の JSON をパースする。
    ///
    /// - Throws: 削除済み・非公開の場合は ``TwiDropError/tweetNotFound(_:)``、
    ///   JSON として読めない場合は ``TwiDropError/fetchFailed(_:)``。
    public static func parse(data: Data, tweetID: String) throws -> Tweet {
        let response: SyndicationResponse
        do {
            response = try JSONDecoder().decode(SyndicationResponse.self, from: data)
        } catch {
            // 削除済み・非公開のときは JSON ではなく HTML が返ることがある。
            throw TwiDropError.tweetNotFound(
                "ツイートを取得できませんでした（ID: \(tweetID)）。"
                    + "削除済み、非公開アカウント、または存在しない ID の可能性があります。"
            )
        }

        if response.isTombstone {
            throw TwiDropError.tweetNotFound(
                response.tombstone?.text?.text ?? "削除済み、または非公開のツイートです。"
            )
        }
        guard response.looksLikeTweet else {
            throw TwiDropError.tweetNotFound("ツイートが見つかりませんでした（ID: \(tweetID)）。")
        }

        return build(from: response, fallbackID: tweetID)
    }

    static func build(from response: SyndicationResponse, fallbackID: String) -> Tweet {
        let id = response.idString ?? fallbackID
        let screenName = response.user?.screenName ?? "unknown"
        let media = parseMedia(response.mediaDetails ?? [], tweetID: id)

        return Tweet(
            id: id,
            text: cleanText(response.text, stripMediaLink: !media.isEmpty),
            authorName: response.user?.name ?? screenName,
            authorScreenName: screenName,
            createdAt: parseDate(response.createdAt),
            url: TweetURL.canonicalURL(id: id, screenName: screenName),
            likeCount: response.favoriteCount,
            replyCount: response.conversationCount,
            language: response.language,
            authorAvatarURL: response.user?.profileImageURL.flatMap(URL.init(string:)),
            possiblySensitive: response.possiblySensitive ?? false,
            media: media
        )
    }

    static func parseMedia(_ details: [SyndicationResponse.MediaDetail], tweetID: String) -> [TweetMedia] {
        details.enumerated().compactMap { index, detail in
            let thumbnail = detail.mediaURL.flatMap(URL.init(string:))
            let width = detail.originalInfo?.width
            let height = detail.originalInfo?.height
            let id = "\(tweetID)_\(index + 1)"

            switch detail.type {
            case "photo":
                guard let thumbnail, let original = originalPhotoURL(thumbnail) else { return nil }
                return TweetMedia(
                    id: id, kind: .photo, url: original, thumbnailURL: thumbnail,
                    width: width, height: height
                )

            case "video", "animated_gif":
                guard let variant = bestVideoVariant(detail.videoInfo?.variants ?? []),
                      let url = variant.url.flatMap(URL.init(string:))
                else { return nil }
                return TweetMedia(
                    id: id,
                    kind: detail.type == "video" ? .video : .animatedGIF,
                    url: url,
                    thumbnailURL: thumbnail,
                    width: width,
                    height: height,
                    durationMilliseconds: detail.videoInfo?.durationMillis,
                    bitrate: variant.bitrate
                )

            default:
                return nil
            }
        }
    }

    /// mp4 のうち最もビットレートの高いものを選ぶ（HLS プレイリストは除外）。
    static func bestVideoVariant(
        _ variants: [SyndicationResponse.Variant]
    ) -> SyndicationResponse.Variant? {
        variants
            .filter { ($0.contentType ?? "").hasPrefix("video/mp4") && $0.url != nil }
            .max { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }
    }

    /// pbs.twimg.com の画像 URL を原寸（`name=orig`）に書き換える。
    static func originalPhotoURL(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let format = url.pathExtension.lowercased()

        var items = [URLQueryItem(name: "name", value: "orig")]
        if !format.isEmpty {
            components.path = (components.path as NSString).deletingPathExtension
            items.insert(URLQueryItem(name: "format", value: format), at: 0)
        }
        components.queryItems = items
        return components.url ?? url
    }

    /// HTML エスケープを戻し、末尾のメディア用 t.co リンクを取り除く。
    static func cleanText(_ raw: String?, stripMediaLink: Bool) -> String {
        var text = HTMLEntities.decode(raw ?? "")
        if stripMediaLink {
            text = removeTrailingShortLink(from: text)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeTrailingShortLink(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: "https://t.co/", options: .backwards),
              range.upperBound < trimmed.endIndex || range.upperBound == trimmed.endIndex
        else { return trimmed }

        let suffix = trimmed[range.upperBound...]
        // 末尾が `https://t.co/<英数字>` で終わっているときだけ落とす。
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return trimmed
        }
        return String(trimmed[trimmed.startIndex..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}
