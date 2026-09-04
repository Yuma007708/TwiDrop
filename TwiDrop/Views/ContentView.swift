import SwiftUI

/// ルート。「保存」と「ライブラリ」の 2 タブ。
struct ContentView: View {
    @EnvironmentObject private var viewModel: TweetViewModel

    var body: some View {
        TabView {
            SaveView()
                .tabItem { Label("保存", systemImage: "arrow.down.to.line") }

            LibraryView()
                .tabItem { Label("ライブラリ", systemImage: "square.grid.2x2") }
        }
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
