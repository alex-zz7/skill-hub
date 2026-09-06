import SwiftUI

/// Standard macOS sheet chrome: title, grouped form, and a trailing Cancel / primary button row.
struct SheetFrame<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let primaryTitle: String
    let primaryEnabled: Bool
    let primaryAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

            Form {
                content
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                Spacer()
                Button("取消", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button(primaryTitle, action: primaryAction)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!primaryEnabled)
            }
            .padding(20)
        }
        .frame(width: 480)
    }

    private func cancel() {
        dismiss()
    }
}
