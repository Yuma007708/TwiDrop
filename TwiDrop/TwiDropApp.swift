import SwiftUI

@main
struct TwiDropApp: App {
    @StateObject private var viewModel = TweetViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .fontDesign(.rounded)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    Task { await viewModel.handleIncoming(url: url) }
                }
        }
    }
}
