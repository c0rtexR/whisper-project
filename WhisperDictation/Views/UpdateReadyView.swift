import SwiftUI

struct UpdateReadyView: View {
    let zipPath: URL
    @ObservedObject var updateChecker: UpdateChecker
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Update Ready to Install")
                .font(.title2)
                .fontWeight(.semibold)

            Text("The app will restart to complete installation")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Install Later") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Restart & Install") {
                    updateChecker.installUpdate(zipPath: zipPath)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 400)
    }
}
