import SwiftUI

// Note: This view is not currently used. Menu creation is handled in AppDelegate.
// Keeping this for potential future SwiftUI-based menu bar implementation.
struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack {
            Text(appState.transcriptionState.displayText)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var isEnabled = true
}
