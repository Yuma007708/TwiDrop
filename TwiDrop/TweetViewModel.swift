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

    /// 保存の結果。写真アプリへ何件入ったかを覚えておく。
    struct SaveOutcome: Equatable {
        let tweetID: String
        let addedToPhotos: Int
        let skipped: Int
    }

    @Published var urlText = ""
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isSaving = false
    @Published private(set) var outcome: SaveOutcome?
    /// クリップボードに何か入っているか（中身は読まない。読むのはユーザーが押したとき）。
    @Published private(set) var clipboardHasContent = false
    @Published var errorMessage: String?

    private let client: SyndicationClient
    private let archive: TweetArchive
    private var previewTask: Task<Void, Never>?
    private var loadedSource: String?

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

    var isLoading: Bool { phase == .loading }

    var canSubmit: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    /// 表示中のツイートを今回保存し終えたか。
    var isPreviewSaved: Bool {
        guard let tweet = previewedTweet, let outcome else { return false }
        return outcome.tweetID == tweet.id
    }

    // MARK: - 入力

    /// URL 欄が変わるたびに呼ぶ。ツイート URL になったら少し待ってから自動でプレビューする。
    func urlTextChanged() {
        previewTask?.cancel()
        let source = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !source.isEmpty else {
            phase = .idle
            loadedSource = nil
            outcome = nil
            return
        }
        guard TweetURL.firstID(inText: source) != nil, source != loadedSource else { return }

        outcome = nil
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.loadPreview()
        }
    }

    /// 入力を空に戻して最初の状態にする。
    func reset() {
        previewTask?.cancel()
        urlText = ""
        phase = .idle
        loadedSource = nil
        outcome = nil
        refreshClipboardHint()
    }

    /// クリップボードに何かあるかだけを確かめる（貼り付けの許可ダイアログは出ない）。
    func refreshClipboardHint() {
        let pasteboard = UIPasteboard.general
        clipboardHasContent = pasteboard.hasURLs || pasteboard.hasStrings
    }

    /// クリップボードのツイート URL を入力欄に入れてプレビューする。
    func useClipboard() {
        guard let text = UIPasteboard.general.string,
              let id = TweetURL.firstID(inText: text)
        else {
            errorMessage = "クリップボードにツイートの URL が見つかりませんでした。"
            clipboardHasContent = false
            return
        }
        urlText = TweetURL.canonicalURL(id: id, screenName: nil)?.absoluteString ?? id
        previewTask?.cancel()
        outcome = nil
        Task { await loadPreview() }
    }

    /// 本文をクリップボードにコピーする。
    func copyText() {
        guard let tweet = previewedTweet else { return }
        UIPasteboard.general.string = tweet.text
    }

    // MARK: - 取得と保存

    /// 入力された URL のツイートを取得して表示する（保存はしない）。
    func loadPreview() async {
        let source = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }

        phase = .loading
        do {
            let tweet = try await client.tweet(from: source)
            guard !Task.isCancelled else { return }
            phase = .loaded(tweet)
            loadedSource = source
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(message(for: error))
            loadedSource = nil
        }
    }

    /// 取得済みのツイートを保存し、動画・画像を写真アプリに追加する。未取得なら先に取得する。
    func save() async {
        previewTask?.cancel()
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
            let added = try await PhotoLibrarySaver.addToPhotoLibrary(saved)
            // 写真アプリに入ったら端末内のコピーは不要。本文（tweet.md / tweet.json）は残す。
            PhotoLibrarySaver.removeLocalMedia(of: saved)
            outcome = SaveOutcome(tweetID: tweet.id, addedToPhotos: added, skipped: saved.skipped.count)
        } catch {
            errorMessage = message(for: error)
        }
    }

    /// 共有シートなどから渡された URL を受け取って処理する。
    func handleIncoming(url: URL) async {
        urlText = url.absoluteString
        previewTask?.cancel()
        outcome = nil
        await loadPreview()
    }

    private func message(for error: Error) -> String {
        (error as? TwiDropError)?.errorDescription
            ?? (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
    }
}
