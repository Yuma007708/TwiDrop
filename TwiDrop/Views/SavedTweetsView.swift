import AVFoundation
import SwiftUI
import TwiDropKit

/// 「ライブラリ」タブ。保存済みをサムネイルのグリッドで見せる。
struct LibraryView: View {
    @EnvironmentObject private var viewModel: TweetViewModel

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.savedTweets.isEmpty {
                    ContentUnavailableView(
                        "まだ何も保存していません",
                        systemImage: "tray",
                        description: Text("「保存」タブで URL を貼り付けるか、X アプリの共有シートから保存してください。")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.savedTweets) { saved in
                            NavigationLink(value: saved.id) {
                                LibraryTile(saved: saved)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.delete(saved)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("ライブラリ")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(viewModel.savedTweets.count) 件")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .navigationDestination(for: String.self) { id in
                if let saved = viewModel.savedTweets.first(where: { $0.id == id }) {
                    SavedTweetDetailView(saved: saved)
                }
            }
            .refreshable { viewModel.refreshSaved() }
            .onAppear { viewModel.refreshSaved() }
        }
    }
}

/// グリッドの 1 マス。動画・画像はサムネイル、テキストだけなら引用風。
struct LibraryTile: View {
    let saved: SavedTweet

    private let height: CGFloat = 200

    var body: some View {
        Group {
            if let media = saved.tweet.media.first {
                mediaTile(media)
            } else {
                textTile
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium, style: .continuous))
    }

    private func mediaTile(_ media: TweetMedia) -> some View {
        ZStack(alignment: .bottomLeading) {
            MediaThumbnail(media: media, localURL: saved.mediaFiles.first)

            if media.kind.isVideo {
                Circle()
                    .fill(Theme.accent.opacity(0.92))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "play.fill").foregroundStyle(Theme.onAccent))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -8)
            }

            LinearGradient(colors: [.clear, Theme.background.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .frame(height: 64)

            Text("@\(saved.tweet.authorScreenName)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .overlay(alignment: .topLeading) {
            badge(for: media).padding(10)
        }
    }

    private func badge(for media: TweetMedia) -> some View {
        Group {
            if media.kind.isVideo {
                MediaBadge(systemImage: "film", text: media.formattedDuration ?? "動画")
            } else {
                MediaBadge(systemImage: "photo", text: "\(saved.tweet.media.count)")
            }
        }
    }

    private var textTile: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "quote.opening")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accent)
            Spacer(minLength: 8)
            Text(saved.tweet.text)
                .font(.footnote)
                .lineSpacing(3)
                .lineLimit(4)
                .foregroundStyle(Theme.text.opacity(0.85))
            Spacer(minLength: 8)
            Text("@\(saved.tweet.authorScreenName)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface)
    }
}

/// メディアの静止画サムネイル。動画はローカルファイルから 1 コマ切り出す。
struct MediaThumbnail: View {
    let media: TweetMedia
    var localURL: URL? = nil

    @State private var frame: UIImage?

    var body: some View {
        ZStack {
            Theme.mediaPlaceholder
            if let frame {
                Image(uiImage: frame).resizable().scaledToFill()
            } else if !media.kind.isVideo || localURL == nil {
                AsyncImage(url: media.kind.isVideo ? media.thumbnailURL : (localURL ?? media.thumbnailURL ?? media.url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
        }
        .task(id: localURL) {
            guard media.kind.isVideo, let localURL else { return }
            frame = await Self.firstFrame(of: localURL)
        }
    }

    /// 動画の先頭付近から 1 コマを取り出す。失敗したら nil。
    private static func firstFrame(of url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        guard let result = try? await generator.image(at: time) else { return nil }
        return UIImage(cgImage: result.image)
    }
}

/// 保存済みツイート 1 件の詳細。メディアを上いっぱいに、操作は下に。
struct SavedTweetDetailView: View {
    @EnvironmentObject private var viewModel: TweetViewModel
    @Environment(\.dismiss) private var dismiss
    let saved: SavedTweet

    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TweetCardView(tweet: saved.tweet, localMedia: saved.mediaFiles)

                HStack(spacing: 10) {
                    if !saved.mediaFiles.isEmpty {
                        Button {
                            Task { await addToPhotos() }
                        } label: {
                            Label("写真に追加", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    ShareLink(items: shareItems) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                fileList

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("この保存を削除", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("@\(saved.tweet.authorScreenName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .confirmationDialog("この保存を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                viewModel.delete(saved)
                dismiss()
            }
        } message: {
            Text("端末内のファイルを削除します。写真アプリに追加したものは残ります。")
        }
    }

    private var shareItems: [URL] {
        saved.mediaFiles.isEmpty ? [saved.markdownFile] : saved.mediaFiles
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("保存したファイル")
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Theme.faint)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(saved.mediaFiles.enumerated()), id: \.element) { index, file in
                    fileRow(file, icon: saved.tweet.media[safe: index]?.kind.isVideo == true ? "film" : "photo",
                            trailing: Self.size(of: file))
                    divider
                }
                fileRow(saved.markdownFile, icon: "doc.text", trailing: "本文")
                divider
                fileRow(saved.metadataFile, icon: "curlybraces", trailing: "メタデータ")
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerMedium, style: .continuous))
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 48)
    }

    private func fileRow(_ file: URL, icon: String, trailing: String) -> some View {
        ShareLink(item: file) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundStyle(Theme.accent)
                Text(file.lastPathComponent)
                    .font(.footnote)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
        }
    }

    private static func size(of file: URL) -> String {
        let bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func addToPhotos() async {
        do {
            let added = try await PhotoLibrarySaver.addToPhotoLibrary(saved)
            viewModel.statusMessage = "写真アプリに \(added) 件追加しました"
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
