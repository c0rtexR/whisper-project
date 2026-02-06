import SwiftUI

struct FloatingRecordButton: View {
    let transcriptionState: TranscriptionState
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: shadowColor, radius: isPulsing ? 8 : 4)

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .colorScheme(.dark)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { recording in
            withAnimation(recording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default) {
                isPulsing = recording
            }
        }
    }

    private var isRecording: Bool {
        if case .recording = transcriptionState { return true }
        return false
    }

    private var isProcessing: Bool {
        if case .processing = transcriptionState { return true }
        return false
    }

    private var backgroundColor: Color {
        switch transcriptionState {
        case .recording: return .red
        case .processing: return .orange
        default: return .accentColor
        }
    }

    private var shadowColor: Color {
        isRecording ? .red.opacity(0.5) : .clear
    }
}
