import AVKit
import SwiftUI
import TwiDropKit

/// ツイート 1 件のカード。メディアを上に大きく、本文を下に。
struct TweetCardView: View {
    let tweet: Tweet
    /// 保存済みならローカルのファイル（`tweet.media` と同じ順）。無ければ配信元から再生する。
    var localMedia: [URL] = []

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tweet.media.enumerated()), id: \.element.id) { index, media in
                MediaView(media: media, localURL: localMedia[safe: index])
            }

            VStack(alignment: .leading, spacing: 12) {
                authorRow
                if !tweet.text.isEmpty {
                    Text(tweet.text)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(Theme.text)
                        .textSelection(.enabled)
                }
                metaRow
            }
            .padding(16)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous))
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            AvatarView(name: tweet.authorName, url: tweet.authorAvatarURL)
            VStack(alignment: .leading, spacing: 1) {
                Text(tweet.authorName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(handleAndDate)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if let url = tweet.url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("元のツイートを開く")
            }
        }
    }

    private var handleAndDate: String {
        var parts = ["@\(tweet.authorScreenName)"]
        if let createdAt = tweet.createdAt {
            parts.append(createdAt.formatted(.dateTime.month().day()))
        }
        return parts.joined(separator: " · ")
    }

    private var metaRow: some View {
        HStack(spacing: 14) {
            if let likeCount = tweet.likeCount {
                Label(likeCount.formatted(), systemImage: "heart")
            }
            if let first = tweet.media.first, let width = first.width, let height = first.height {
                Text(first.kind.isVideo ? "\(width) × \(height) · 最高画質" : "\(width) × \(height) · 原寸")
            } else if tweet.media.isEmpty {
                Text("テキストのみ")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.muted)
    }
}

/// 添付メディア 1 件。動画はその場で再生、画像はそのまま表示。
struct MediaView: View {
    let media: TweetMedia
    var localURL: URL? = nil

    @State private var player: AVPlayer?

    private var aspectRatio: CGFloat {
        guard let width = media.width, let height = media.height, height > 0 else { return 16 / 9 }
        return CGFloat(width) / CGFloat(height)
    }

    var body: some View {
        Group {
            if media.kind.isVideo {
                VideoPlayer(player: player)
                    .onAppear {
                        // 再描画のたびに作り直すと再生位置が戻ってしまう。
                        if player == nil { player = AVPlayer(url: localURL ?? media.url) }
                    }
                    .overlay(alignment: .topLeading) {
                        MediaBadge(systemImage: "film", text: media.kind == .animatedGIF ? "GIF" : "動画")
                            .padding(12)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = media.formattedDuration {
                            MediaBadge(text: duration).padding(12)
                        }
                    }
            } else {
                AsyncImage(url: localURL ?? media.thumbnailURL ?? media.url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Theme.mediaPlaceholder
                        ProgressView().tint(Theme.accent)
                    }
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .background(Theme.surfaceRaised)
        .clipped()
    }
}
