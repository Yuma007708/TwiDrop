import SwiftUI

/// ルート。画面は「保存」の 1 つだけ。
struct ContentView: View {
    @EnvironmentObject private var viewModel: TweetViewModel

    var body: some View {
        SaveView()
            .tint(Theme.accent)
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
