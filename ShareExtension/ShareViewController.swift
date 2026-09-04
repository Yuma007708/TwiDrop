import SwiftUI
import TwiDropKit
import UIKit
import UniformTypeIdentifiers

/// X アプリなどの共有シートから渡されたツイートを保存する。
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = ((extensionContext?.inputItems as? [NSExtensionItem]) ?? [])
            .flatMap { $0.attachments ?? [] }

        let hosting = UIHostingController(
            rootView: ShareRootView(attachments: attachments) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
            .fontDesign(.rounded)
            .preferredColorScheme(.dark)
        )
        hosting.view.backgroundColor = UIColor(Theme.surface)

        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }
}

extension NSItemProvider {
    /// `loadItem` を async/await で扱えるようにする。
    func loadValue<T>(ofType type: UTType, as: T.Type) async -> T? {
        guard hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: type.identifier, options: nil) { value, _ in
                continuation.resume(returning: value as? T)
            }
        }
    }
}

/// 共有シート内に出す画面。開いた時点で保存まで進める。
struct ShareRootView: View {
    enum Phase {
        case working(String)
        case done(tweet: Tweet, mediaCount: Int, skipped: Int)
        case failed(String)
    }

    let attachments: [NSItemProvider]
    let finish: () -> Void

    @State private var phase: Phase = .working("ツイートを読み込んでいます…")

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Spacer(minLength: 0)

            switch phase {
            case .working(let message):
                ProgressView().tint(Theme.accent).controlSize(.large)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

            case .done(let tweet, let mediaCount, let skipped):
                statusIcon(systemImage: "checkmark", color: Theme.accent)
                VStack(spacing: 4) {
                    Text("保存しました")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.text)
                    Text(summary(tweet: tweet, mediaCount: mediaCount, skipped: skipped))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                tweetRow(tweet)

            case .failed(let message):
                statusIcon(systemImage: "exclamationmark", color: Theme.danger)
                VStack(spacing: 4) {
                    Text("保存できませんでした")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.text)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer(minLength: 0)

            Button("閉じる", action: finish)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .task { await run() }
    }

    private func statusIcon(systemImage: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.14))
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(color)
            )
    }

    private func summary(tweet: Tweet, mediaCount: Int, skipped: Int) -> String {
        var parts = ["@\(tweet.authorScreenName)"]
        if mediaCount > 0 {
            parts.append(tweet.hasVideo ? "動画 \(mediaCount) 件" : "画像 \(mediaCount) 件")
        }
        if skipped > 0 {
            parts.append("\(skipped) 件は取得できず")
        }
        return parts.joined(separator: " · ")
    }

    private func tweetRow(_ tweet: Tweet) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Theme.mediaPlaceholder
                if let thumbnail = tweet.media.first?.thumbnailURL {
                    AsyncImage(url: thumbnail) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
                if tweet.hasVideo {
                    Image(systemName: "play.fill").foregroundStyle(Theme.accent)
                }
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(tweet.authorName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(tweet.text.isEmpty ? "（本文なし）" : tweet.text)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.cornerMedium, style: .continuous))
    }

    /// 共有された添付から、ツイート URL として使える文字列を取り出す。
    private func extractSource() async -> String? {
        for provider in attachments {
            if let url = await provider.loadValue(ofType: .url, as: URL.self),
               let id = TweetURL.firstID(inText: url.absoluteString) {
                return id
            }
            // X アプリは「本文 + URL」のテキストとして渡してくることがある。
            if let text = await provider.loadValue(ofType: .plainText, as: String.self),
               let id = TweetURL.firstID(inText: text) {
                return id
            }
        }
        return nil
    }

    private func run() async {
        guard let source = await extractSource() else {
            phase = .failed("共有された内容にツイートの URL が見つかりませんでした。")
            return
        }

        do {
            let tweet = try await SyndicationClient().tweet(from: source)
            phase = .working("@\(tweet.authorScreenName) を保存しています…")

            let saved = try await ArchiveLocation.makeArchive().save(tweet)
            phase = .done(tweet: tweet, mediaCount: saved.mediaFiles.count, skipped: saved.skipped.count)
        } catch {
            phase = .failed((error as? TwiDropError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
