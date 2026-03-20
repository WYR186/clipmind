import SwiftUI

struct ErrorBannerView: View {
    let error: UserFacingError
    let showDiagnostics: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.headline)
                    Text(error.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !error.suggestions.isEmpty {
                Text(error.suggestions.map(\.message).joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showDiagnostics {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Code: \(error.code) | Service: \(error.service)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let diagnostics = error.diagnostics, !diagnostics.isEmpty {
                        Text(diagnostics)
                            .font(.caption2)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
