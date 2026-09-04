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
    /// クリップボードに何か入っているか（中身は読まない。読むのはユーザーが押したとき）。
    @Published private(set) var clipboardHasContent = false
    @Published var statusMessage: String?
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

    /// 表示中のツイートが保存済みか。
    var isPreviewSaved: Bool {
        guard let tweet = previewedTweet else { return false }
        return archive.isSaved(tweet)
    }

    // MARK: - 入力

    /// URL 欄が変わるたびに呼ぶ。ツイート URL になったら少し待ってから自動でプレビューする。
    func urlTextChanged() {
        previewTask?.cancel()
        let source = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        statusMessage = nil

        guard !source.isEmpty else {
            phase = .idle
            loadedSource = nil
            return
        }
        guard TweetURL.firstID(inText: source) != nil, source != loadedSource else { return }

        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.loadPreview()
        }
    }

    func clearURL() {
        urlText = ""
        urlTextChanged()
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
        Task { await loadPreview() }
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

    /// 取得済みのツイートを端末に保存する。未取得なら先に取得する。
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
            statusMessage = parts.joined(separator: " · ")
            refreshSaved()
        } catch {
            errorMessage = message(for: error)
        }
    }

    // MARK: - ライブラリ

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

    /// 共有シートなどから渡された URL を受け取って処理する。
    func handleIncoming(url: URL) async {
        urlText = url.absoluteString
        previewTask?.cancel()
        await loadPreview()
    }

    private func message(for error: Error) -> String {
        (error as? TwiDropError)?.errorDescription
            ?? (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
    }
}
