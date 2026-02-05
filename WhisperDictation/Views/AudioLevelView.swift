import SwiftUI

struct AudioLevelView: View {
    @ObservedObject var recorder: AudioRecorder

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
                .font(.system(size: 12))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(levelColor)
                        .frame(width: geometry.size.width * CGFloat(recorder.audioLevel))
                        .animation(.easeOut(duration: 0.1), value: recorder.audioLevel)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 120, height: 30)
    }

    private var levelColor: Color {
        if recorder.audioLevel > 0.8 {
            return .red
        } else if recorder.audioLevel > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}
