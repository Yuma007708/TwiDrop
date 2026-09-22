import Foundation

/// ディスクに保存済みの 1 件のツイート。
public struct SavedTweet: Identifiable, Sendable, Equatable {
    public let tweet: Tweet
    /// このツイート専用のディレクトリ。
    public let directory: URL
    /// 保存できたメディアファイル。
    public let mediaFiles: [URL]
    /// 保存に失敗したメディアの説明。
    public let skipped: [String]

    public var id: String { tweet.id }

    public init(tweet: Tweet, directory: URL, mediaFiles: [URL] = [], skipped: [String] = []) {
        self.tweet = tweet
        self.directory = directory
        self.mediaFiles = mediaFiles
        self.skipped = skipped
    }

    public var metadataFile: URL { directory.appendingPathComponent(TweetArchive.metadataFileName) }
    public var markdownFile: URL { directory.appendingPathComponent(TweetArchive.markdownFileName) }

    /// 動画ファイル（Photos への保存や共有に使う）。
    public var videoFiles: [URL] {
        zip(tweet.media, mediaFiles).filter { $0.0.kind.isVideo }.map(\.1)
    }
}

/// ツイートを端末上のディレクトリへ保存し、一覧・削除する。
///
/// 保存先は `<baseDirectory>/<screenName>_<tweetID>/` 以下:
/// `tweet.json`（メタデータ）、`tweet.md`（本文）、メディアファイル。
public struct TweetArchive: Sendable {
    public static let metadataFileName = "tweet.json"
    public static let markdownFileName = "tweet.md"

    public let baseDirectory: URL
    private let downloader: MediaDownloader
    private let fileManager: FileManager

    public init(
        baseDirectory: URL,
        downloader: MediaDownloader = MediaDownloader(),
        fileManager: FileManager = .default
    ) {
        self.baseDirectory = baseDirectory
        self.downloader = downloader
        self.fileManager = fileManager
    }

    /// ツイート専用の保存先ディレクトリ。
    public func directory(for tweet: Tweet) -> URL {
        baseDirectory.appendingPathComponent(MediaDownloader.sanitize(tweet.slug), isDirectory: true)
    }

    /// 既に保存済みかどうか。
    public func isSaved(_ tweet: Tweet) -> Bool {
        fileManager.fileExists(
            atPath: directory(for: tweet).appendingPathComponent(Self.metadataFileName).path
        )
    }

    /// 本文とメディアを保存する。
    ///
    /// メディアが 1 件失敗しても、残りと本文は保存して ``SavedTweet/skipped`` に理由を残す。
    @discardableResult
    public func save(
        _ tweet: Tweet, includeMedia: Bool = true, overwrite: Bool = false
    ) async throws -> SavedTweet {
        let directory = directory(for: tweet)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(tweet.markdown().utf8)
                .write(to: directory.appendingPathComponent(Self.markdownFileName))
            try Self.encoder.encode(tweet)
                .write(to: directory.appendingPathComponent(Self.metadataFileName))
        } catch {
            throw TwiDropError.mediaDownloadFailed(error.localizedDescription)
        }

        guard includeMedia else { return SavedTweet(tweet: tweet, directory: directory) }

        var files: [URL] = []
        var skipped: [String] = []
        for (index, media) in tweet.media.enumerated() {
            let destination = directory.appendingPathComponent(
                MediaDownloader.fileName(for: media, tweet: tweet, index: index + 1)
            )
            do {
                files.append(try await downloader.download(media, to: destination, overwrite: overwrite))
            } catch {
                skipped.append("\(media.url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return SavedTweet(tweet: tweet, directory: directory, mediaFiles: files, skipped: skipped)
    }

    /// 保存済みツイートを新しい順に返す。
    public func saved() -> [SavedTweet] {
        let entries = (try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return entries
            .compactMap { directory -> (SavedTweet, Date)? in
                guard let saved = load(from: directory) else { return nil }
                let modified = (try? directory.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return (saved, modified)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// 保存済みツイートを削除する。
    public func delete(_ saved: SavedTweet) throws {
        try fileManager.removeItem(at: saved.directory)
    }

    /// ディレクトリ 1 件を ``SavedTweet`` として読み込む。
    func load(from directory: URL) -> SavedTweet? {
        let metadata = directory.appendingPathComponent(Self.metadataFileName)
        guard let data = try? Data(contentsOf: metadata),
              let tweet = try? Self.decoder.decode(Tweet.self, from: data)
        else { return nil }

        let mediaFiles = tweet.media.enumerated().compactMap { index, media -> URL? in
            let file = directory.appendingPathComponent(
                MediaDownloader.fileName(for: media, tweet: tweet, index: index + 1)
            )
            return fileManager.fileExists(atPath: file.path) ? file : nil
        }
        return SavedTweet(tweet: tweet, directory: directory, mediaFiles: mediaFiles)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
