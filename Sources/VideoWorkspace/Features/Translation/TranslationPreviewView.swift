import SwiftUI

struct TranslationPreviewView: View {
    let result: TranslationResult
    let showAdvanced: Bool
    let onRevealArtifact: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showAdvanced {
                Text("Provider: \(result.provider.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Model: \(result.modelID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Mode: \(result.mode.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(result.translatedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if let bilingual = result.bilingualText, !bilingual.isEmpty {
                Divider()
                Text("Bilingual")
                    .font(.subheadline.bold())
                Text(bilingual)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            if showAdvanced, !result.segments.isEmpty {
                Divider()
                Text("Subtitle Segments: \(result.segments.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !result.artifacts.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.artifacts, id: \.path) { artifact in
                        HStack {
                            Text("\(artifact.format.rawValue.uppercased()): \(artifact.path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Spacer()
                            Button(AppCopy.Buttons.revealInFinder) {
                                onRevealArtifact(artifact.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
