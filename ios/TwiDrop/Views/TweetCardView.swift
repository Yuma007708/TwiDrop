import AVKit
import SwiftUI
import TwiDropKit

/// ツイート 1 件の見た目（作者・本文・添付メディア）。
struct TweetCardView: View {
    let tweet: Tweet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !tweet.text.isEmpty {
                Text(tweet.text)
                    .font(.body)
                    .textSelection(.enabled)
            }

            ForEach(tweet.media) { media in
                MediaPreview(media: media)
            }

            metadata
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AsyncImage(url: tweet.authorAvatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(tweet.authorName).font(.subheadline.bold())
                Text("@\(tweet.authorScreenName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = tweet.url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                }
                .accessibilityLabel("元のツイートを開く")
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 12) {
            if let createdAt = tweet.createdAt {
                Text(createdAt, format: .dateTime.year().month().day().hour().minute())
            }
            if let likeCount = tweet.likeCount {
                Label("\(likeCount)", systemImage: "heart")
            }
            if tweet.media.isEmpty {
                Text("メディアなし")
            } else {
                Label("\(tweet.media.count)", systemImage: tweet.hasVideo ? "film" : "photo")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// 添付メディア 1 件のプレビュー。動画はその場で再生できる。
struct MediaPreview: View {
    let media: TweetMedia
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
                            Text(duration)
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: Capsule())
                                .foregroundStyle(.white)
                                .padding(6)
                        }
                    }
            } else {
                AsyncImage(url: media.thumbnailURL ?? media.url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        ProgressView()
                    }
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
