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
        )

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

/// 共有シート内に出す小さな画面。開いた時点で保存まで進める。
struct ShareRootView: View {
    enum Phase {
        case working(String)
        case done(String)
        case failed(String)
    }

    let attachments: [NSItemProvider]
    let finish: () -> Void

    @State private var phase: Phase = .working("ツイートを読み込んでいます…")

    var body: some View {
        VStack(spacing: 16) {
            switch phase {
            case .working(let message):
                ProgressView()
                Text(message).foregroundStyle(.secondary)

            case .done(let message):
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text(message).multilineTextAlignment(.center)

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
            }

            Button("閉じる", action: finish)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .task { await run() }
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
            var message = "@\(tweet.authorScreenName) のツイートを保存しました"
            if !saved.mediaFiles.isEmpty {
                message += "（メディア \(saved.mediaFiles.count) 件）"
            }
            if !saved.skipped.isEmpty {
                message += "\n\(saved.skipped.count) 件は取得できませんでした"
            }
            phase = .done(message)
        } catch {
            phase = .failed((error as? TwiDropError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
