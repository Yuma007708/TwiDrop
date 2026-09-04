import Foundation
import Photos
import TwiDropKit

/// 保存したメディアを「写真」アプリに書き出す。
enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "写真への追加が許可されていません。設定アプリから許可してください。"
            }
        }
    }

    /// 写真アプリを開く URL。
    static let photosAppURL = URL(string: "photos-redirect://")!

    /// 追加のみの権限を要求する。
    static func requestAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .authorized || status == .limited { return true }
        let updated = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return updated == .authorized || updated == .limited
    }

    /// 保存済みツイートのメディアをまとめて写真アプリに追加し、追加できた件数を返す。
    /// メディアが無いツイート（テキストのみ）は 0 を返す。
    @discardableResult
    static func addToPhotoLibrary(_ saved: SavedTweet) async throws -> Int {
        guard !saved.mediaFiles.isEmpty else { return 0 }
        guard await requestAuthorization() else { throw SaveError.notAuthorized }

        var added = 0
        for (media, file) in zip(saved.tweet.media, saved.mediaFiles) {
            try await add(file: file, isVideo: media.kind.isVideo)
            added += 1
        }
        return added
    }

    /// 写真アプリに入った後の端末内コピーを消す。本文ファイルは残す。
    static func removeLocalMedia(of saved: SavedTweet) {
        for file in saved.mediaFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func add(file: URL, isVideo: Bool) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: isVideo ? .video : .photo, fileURL: file, options: nil)
        }
    }
}
