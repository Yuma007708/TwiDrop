import SwiftUI
import TwiDropKit

/// 「保存」タブ。URL を貼ると自動でプレビューし、ボタン 1 つで保存する。
struct SaveView: View {
    @EnvironmentObject private var viewModel: TweetViewModel
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if viewModel.clipboardHasContent, viewModel.urlText.isEmpty {
                    clipboardChip
                }
                previewArea
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { dock }
        .onAppear {
            viewModel.refreshClipboardHint()
            viewModel.refreshSaved()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { viewModel.refreshClipboardHint() }
        }
        .onChange(of: viewModel.urlText) {
            viewModel.urlTextChanged()
        }
    }

    // MARK: - 上部

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.accent).frame(width: 10, height: 10)
            Text("TwiDrop")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.text)
        }
        .frame(height: 44)
    }

    private var clipboardChip: some View {
        Button {
            viewModel.useClipboard()
        } label: {
            Label("クリップボードの URL を使う", systemImage: "doc.on.clipboard")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Theme.accent.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Theme.accent.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewArea: some View {
        switch viewModel.phase {
        case .idle:
            emptyState

        case .loading:
            VStack(spacing: 12) {
                ProgressView().tint(Theme.accent)
                Text("ツイートを取得しています…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous))

        case .loaded(let tweet):
            VStack(alignment: .leading, spacing: 10) {
                TweetCardView(tweet: tweet)
                if let status = viewModel.statusMessage {
                    Label(status, systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 4)
                } else if viewModel.isPreviewSaved {
                    Label("保存済み", systemImage: "checkmark.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                }
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("取得できませんでした", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.danger)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.faint)
            Text("ツイートの URL を貼り付けると\nここにプレビューが出ます")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
            Text("X アプリの共有シートからも保存できます")
                .font(.caption)
                .foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        )
    }

    // MARK: - 下部の操作エリア

    private var dock: some View {
        VStack(spacing: 10) {
            urlField

            Button {
                urlFieldFocused = false
                Task { await viewModel.save() }
            } label: {
                if viewModel.isSaving {
                    ProgressView().tint(Theme.onAccent)
                } else {
                    Label("保存する", systemImage: "arrow.down.to.line")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.canSubmit)
            .opacity(viewModel.canSubmit ? 1 : 0.5)

            Toggle(isOn: $viewModel.saveToPhotos) {
                Text("写真アプリにも保存")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Theme.accent)
            .fixedSize()
            .frame(maxWidth: .infinity)
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
            TextField("ツイートの URL を貼り付け", text: $viewModel.urlText)
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
                    viewModel.clearURL()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 20, height: 20)
                        .background(Theme.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("URL を消去")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(urlFieldFocused ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: 1)
        )
    }
}
