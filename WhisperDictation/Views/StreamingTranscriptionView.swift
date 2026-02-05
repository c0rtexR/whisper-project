import SwiftUI

class StreamingTranscriptionState: ObservableObject {
    @Published var text: String = ""
}

struct StreamingTranscriptionView: View {
    @ObservedObject var state: StreamingTranscriptionState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text("Live Preview")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            if state.text.isEmpty {
                Text("Listening...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(state.text)
                    .font(.system(size: 12))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 330, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
