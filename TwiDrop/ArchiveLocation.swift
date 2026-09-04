import Foundation
import TwiDropKit

/// 保存先の決定。
///
/// App Group を使うことで、共有拡張から保存したツイートを本体アプリでもそのまま見られる。
enum ArchiveLocation {
    /// 本体アプリと共有拡張で共有するコンテナ。
    ///
    /// - Important: Xcode の Signing & Capabilities で、両ターゲットに
    ///   同じ App Group を設定してください（`project.yml` の値と揃えます）。
    static let appGroupIdentifier = "group.dev.twidrop.shared"

    /// ツイートを保存するディレクトリ。
    ///
    /// App Group が未設定の場合はアプリ自身の Documents にフォールバックするので、
    /// 設定前でも本体アプリだけは動作する。
    static var archiveDirectory: URL {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let directory = container.appendingPathComponent("Tweets", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 共有のアーカイブ。
    static func makeArchive() -> TweetArchive {
        TweetArchive(baseDirectory: archiveDirectory)
    }
}
