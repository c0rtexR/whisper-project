import SwiftUI

struct UpdateDownloadView: View {
    @ObservedObject var updateChecker: UpdateChecker
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Downloading Update...")
                .font(.title2)
                .fontWeight(.semibold)

            ProgressView(value: updateChecker.downloadProgress) {
                Text("\(Int(updateChecker.downloadProgress * 100))%")
            }
            .progressViewStyle(.linear)

            Button("Cancel") {
                updateChecker.cancelDownload()
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(width: 400)
    }
}
