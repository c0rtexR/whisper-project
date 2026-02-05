import SwiftUI

class AppState: ObservableObject {
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var isEnabled = true
}
