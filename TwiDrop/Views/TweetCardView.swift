import AVKit
import SwiftUI
import TwiDropKit

/// ツイート 1 件のカード。メディアを上に大きく、本文を下に。
struct TweetCardView: View {
    let tweet: Tweet
    var isSaved = false
    var onCopyText: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tweet.media.enumerated()), id: \.element.id) { index, media in
                MediaView(media: media, isSaved: isSaved && index == 0)
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
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 16, y: 8)
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            AvatarView(name: tweet.authorName, url: tweet.authorAvatarURL)
            VStack(alignment: .leading, spacing: 1) {
                Text(tweet.authorName)
                    .font(.subheadline.weight(.heavy))
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
            Spacer()
            if let onCopyText, !tweet.text.isEmpty {
                Button(action: onCopyText) {
                    Label("本文をコピー", systemImage: "doc.on.doc")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.muted)
    }
}

/// 添付メディア 1 件。動画はその場で再生、画像はそのまま表示。
struct MediaView: View {
    let media: TweetMedia
    var isSaved = false

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
                        if player == nil { player = AVPlayer(url: media.url) }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = media.formattedDuration {
                            MediaBadge(text: duration).padding(12)
                        }
                    }
            } else {
                AsyncImage(url: media.thumbnailURL ?? media.url) { image in
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
        .background(Theme.tint)
        .clipped()
        .overlay(alignment: .topLeading) {
            Group {
                if isSaved {
                    MediaBadge(systemImage: "checkmark", text: "保存済み", highlighted: true)
                } else {
                    MediaBadge(
                        systemImage: media.kind.isVideo ? "film" : "photo",
                        text: media.kind == .animatedGIF ? "GIF" : (media.kind.isVideo ? "動画" : "画像")
                    )
                }
            }
            .padding(12)
        }
    }
}
