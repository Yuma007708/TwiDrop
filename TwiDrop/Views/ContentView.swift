import SwiftUI
import TwiDropKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: TweetViewModel
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                inputSection
                previewSection
                savedSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("TwiDrop")
            .refreshable { viewModel.refreshSaved() }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(viewModel.errorMessage ?? "") }
            )
        }
    }

    private var inputSection: some View {
        Section {
            HStack {
                TextField("https://x.com/…/status/…", text: $viewModel.urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($urlFieldFocused)
                    .submitLabel(.go)
                    .onSubmit { load() }

                Button {
                    viewModel.pasteFromClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("クリップボードから貼り付け")
            }

            Toggle("写真アプリにも保存する", isOn: $viewModel.saveToPhotos)

            HStack {
                Button("プレビュー", action: load)
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canSubmit)

                Spacer()

                Button {
                    urlFieldFocused = false
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("保存する")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)
            }

            if let status = viewModel.statusMessage {
                Label(status, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("ツイートの URL")
        } footer: {
            Text("X アプリの共有シートから TwiDrop を選んでも保存できます。")
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        switch viewModel.phase {
        case .idle:
            EmptyView()

        case .loading:
            Section {
                HStack {
                    ProgressView()
                    Text("取得しています…").foregroundStyle(.secondary)
                }
            }

        case .loaded(let tweet):
            Section("プレビュー") {
                TweetCardView(tweet: tweet)
            }

        case .failed(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        if viewModel.savedTweets.isEmpty {
            Section("保存済み") {
                Text("まだ保存したツイートはありません。")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        } else {
            Section("保存済み（\(viewModel.savedTweets.count) 件）") {
                NavigationLink {
                    SavedTweetsView()
                } label: {
                    Label("保存したツイートを見る", systemImage: "tray.full")
                }
            }
        }
    }

    private func load() {
        urlFieldFocused = false
        Task { await viewModel.loadPreview() }
    }
}
