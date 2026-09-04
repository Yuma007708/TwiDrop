import SwiftUI
import TwiDropKit

/// 保存済みツイートの一覧。スワイプで削除、共有シートで書き出しができる。
struct SavedTweetsView: View {
    @EnvironmentObject private var viewModel: TweetViewModel

    var body: some View {
        List {
            ForEach(viewModel.savedTweets) { saved in
                NavigationLink {
                    SavedTweetDetailView(saved: saved)
                } label: {
                    row(for: saved)
                }
            }
            .onDelete { viewModel.delete(at: $0) }
        }
        .navigationTitle("保存済み")
        .toolbar { EditButton() }
        .overlay {
            if viewModel.savedTweets.isEmpty {
                ContentUnavailableView(
                    "保存したツイートはありません",
                    systemImage: "tray",
                    description: Text("ツイートの URL を貼り付けて保存してみてください。")
                )
            }
        }
    }

    private func row(for saved: SavedTweet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("@\(saved.tweet.authorScreenName)")
                .font(.subheadline.bold())
            Text(saved.tweet.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !saved.mediaFiles.isEmpty {
                Label(
                    "\(saved.mediaFiles.count) 件",
                    systemImage: saved.tweet.hasVideo ? "film" : "photo"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// 保存済みツイート 1 件の詳細。
struct SavedTweetDetailView: View {
    @EnvironmentObject private var viewModel: TweetViewModel
    let saved: SavedTweet

    var body: some View {
        List {
            Section("ツイート") {
                TweetCardView(tweet: saved.tweet)
            }

            if !saved.mediaFiles.isEmpty {
                Section("保存したファイル") {
                    ForEach(saved.mediaFiles, id: \.self) { file in
                        ShareLink(item: file) {
                            Label(file.lastPathComponent, systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        Task { await addToPhotos() }
                    } label: {
                        Label("写真アプリに追加", systemImage: "photo.badge.plus")
                    }
                }
            }

            Section("本文ファイル") {
                ShareLink(item: saved.markdownFile) {
                    Label(saved.markdownFile.lastPathComponent, systemImage: "doc.text")
                }
                ShareLink(item: saved.metadataFile) {
                    Label(saved.metadataFile.lastPathComponent, systemImage: "curlybraces")
                }
            }
        }
        .navigationTitle("@\(saved.tweet.authorScreenName)")
        .navigationBarTitleDisplayMode(.inline)
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
