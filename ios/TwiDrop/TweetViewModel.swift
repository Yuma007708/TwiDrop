import Foundation
import SwiftUI
import TwiDropKit
import UIKit

/// 画面の状態を持ち、取得と保存を進める。
@MainActor
final class TweetViewModel: ObservableObject {
    /// プレビュー領域の状態。
    enum Phase: Equatable {
        case idle
        case loading
        case loaded(Tweet)
        case failed(String)
    }

    @Published var urlText = ""
    @Published var saveToPhotos = true
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var savedTweets: [SavedTweet] = []
    @Published private(set) var isSaving = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let client: SyndicationClient
    private let archive: TweetArchive

    init(
        client: SyndicationClient = SyndicationClient(),
        archive: TweetArchive = ArchiveLocation.makeArchive()
    ) {
        self.client = client
        self.archive = archive
    }

    var previewedTweet: Tweet? {
        if case .loaded(let tweet) = phase { return tweet }
        return nil
    }

    var canSubmit: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    /// クリップボードにツイート URL があれば入力欄に入れる。
    func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string,
              let id = TweetURL.firstID(inText: text)
        else {
            errorMessage = "クリップボードにツイートの URL が見つかりませんでした。"
            return
        }
        urlText = TweetURL.canonicalURL(id: id, screenName: nil)?.absoluteString ?? id
    }

    /// 入力された URL のツイートを取得して表示する（保存はしない）。
    func loadPreview() async {
        let source = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }

        phase = .loading
        statusMessage = nil
        do {
            phase = .loaded(try await client.tweet(from: source))
        } catch {
            phase = .failed(message(for: error))
        }
    }

    /// 取得済みのツイートを端末に保存する。未取得なら先に取得する。
    func save() async {
        let tweet: Tweet
        if let previewed = previewedTweet {
            tweet = previewed
        } else {
            await loadPreview()
            guard let loaded = previewedTweet else { return }
            tweet = loaded
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let saved = try await archive.save(tweet)
            var parts = ["保存しました"]
            if !saved.mediaFiles.isEmpty {
                parts.append("メディア \(saved.mediaFiles.count) 件")
            }
            if saveToPhotos, !saved.mediaFiles.isEmpty {
                let added = try await PhotoLibrarySaver.addToPhotoLibrary(saved)
                parts.append("写真アプリに \(added) 件追加")
            }
            if !saved.skipped.isEmpty {
                parts.append("\(saved.skipped.count) 件は取得できませんでした")
            }
            statusMessage = parts.joined(separator: " / ")
            refreshSaved()
        } catch {
            errorMessage = message(for: error)
        }
    }

    /// 保存済み一覧を読み直す。
    func refreshSaved() {
        savedTweets = archive.saved()
    }

    /// 保存済みツイートを削除する。
    func delete(_ saved: SavedTweet) {
        do {
            try archive.delete(saved)
            refreshSaved()
        } catch {
            errorMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            delete(savedTweets[index])
        }
    }

    /// 共有シートなどから渡された URL を受け取って処理する。
    func handleIncoming(url: URL) async {
        urlText = url.absoluteString
        await loadPreview()
    }

    private func message(for error: Error) -> String {
        (error as? TwiDropError)?.errorDescription
            ?? (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
    }
}
