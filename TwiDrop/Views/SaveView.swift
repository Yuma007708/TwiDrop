import SwiftUI
import TwiDropKit

/// 唯一の画面。URL を貼ると自動でプレビューし、ボタン 1 つで写真アプリに保存する。
struct SaveView: View {
    @EnvironmentObject private var viewModel: TweetViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .top)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { dock }
        .onAppear { viewModel.refreshClipboardHint() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { viewModel.refreshClipboardHint() }
        }
        .onChange(of: viewModel.urlText) {
            viewModel.urlTextChanged()
        }
    }

    /// 空の状態で案内を画面中央に置くための高さ。
    private var contentMinHeight: CGFloat {
        if case .idle = viewModel.phase { return 420 }
        return 0
    }

    // MARK: - 上部

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.accent).frame(width: 10, height: 10)
            Text("TwiDrop")
                .font(.title2.weight(.black))
                .foregroundStyle(Theme.text)
            Spacer()
            if viewModel.clipboardHasContent, viewModel.urlText.isEmpty {
                clipboardChip
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 4)
    }

    private var clipboardChip: some View {
        Button {
            viewModel.useClipboard()
        } label: {
            Label("クリップボードから", systemImage: "doc.on.clipboard")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .overlay(Capsule().stroke(Theme.accent, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            emptyState

        case .loading:
            VStack(spacing: 12) {
                ProgressView().tint(Theme.accent)
                Text("ツイートを取得しています…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous))

        case .loaded(let tweet):
            TweetCardView(tweet: tweet, isSaved: viewModel.isPreviewSaved) {
                viewModel.copyText()
            }
            if let outcome = viewModel.outcome, outcome.tweetID == tweet.id {
                outcomeBanner(outcome, tweet: tweet)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("取得できませんでした", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.danger)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Theme.tint)
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "link")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.accent)
                )
            Text("ツイートの URL を貼り付け")
                .font(.title3.weight(.black))
                .foregroundStyle(Theme.text)
            Text("貼り付けるとすぐにプレビューが出ます。\n動画と画像は写真アプリに保存されます。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
            Label("X アプリの共有シートからも保存できます", systemImage: "square.and.arrow.up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.tint, lineWidth: 1.5))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private func outcomeBanner(_ outcome: TweetViewModel.SaveOutcome, tweet: Tweet) -> some View {
        let message: String
        if outcome.addedToPhotos > 0 {
            let kind = tweet.hasVideo ? "動画" : "画像"
            message = "写真アプリに\(kind) \(outcome.addedToPhotos) 件を追加しました"
        } else {
            message = "本文を保存しました（メディアなし）"
        }
        return HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.bold))
            Text(message)
                .font(.footnote.weight(.heavy))
            if outcome.skipped > 0 {
                Text("· \(outcome.skipped) 件は取得できず")
                    .font(.footnote.weight(.semibold))
            }
        }
        .foregroundStyle(Theme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 下部の操作エリア

    @ViewBuilder
    private var dock: some View {
        VStack(spacing: 10) {
            if viewModel.isPreviewSaved {
                Button {
                    openURL(PhotoLibrarySaver.photosAppURL)
                } label: {
                    Label("写真アプリで見る", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    viewModel.reset()
                } label: {
                    Label("別の URL を保存", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                urlField

                Button {
                    urlFieldFocused = false
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(Theme.onAccent)
                    } else {
                        Label("写真アプリに保存", systemImage: "arrow.down.to.line")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.canSubmit)
                .opacity(viewModel.canSubmit ? 1 : 0.4)

                if viewModel.previewedTweet != nil {
                    Label("動画と画像は写真アプリに入ります", systemImage: "photo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private var urlField: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(Theme.muted)
            TextField("https://x.com/…/status/…", text: $viewModel.urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($urlFieldFocused)
                .foregroundStyle(Theme.text)
                .onSubmit {
                    urlFieldFocused = false
                    Task { await viewModel.loadPreview() }
                }
            if !viewModel.urlText.isEmpty {
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 22, height: 22)
                        .background(Theme.tint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("URL を消去")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(urlFieldFocused ? Theme.accent : Theme.tint, lineWidth: 1.5))
    }
}
