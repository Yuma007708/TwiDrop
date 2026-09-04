import SwiftUI

@main
struct TwiDropApp: App {
    @StateObject private var viewModel = TweetViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .task { viewModel.refreshSaved() }
                .onOpenURL { url in
                    Task { await viewModel.handleIncoming(url: url) }
                }
        }
    }
}
