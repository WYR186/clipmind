import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @State private var currentStep: Int = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to VideoWorkspace",
            subtitle: "A local-first workspace for video-to-text and summarization.",
            bullets: [
                "Online Video focuses on URL inspection, download, and subtitle extraction.",
                "Local Files focuses on transcription and structured summary workflows.",
                "Your core workspace data stays local by default."
            ]
        ),
        OnboardingStep(
            title: "Transcription vs Summary",
            subtitle: "Understand the two engines before running tasks.",
            bullets: [
                "Transcription Engine converts media audio into transcript artifacts.",
                "Summary Engine transforms transcript into concise notes and key points.",
                "You can run transcription only or transcription plus summary."
            ]
        ),
        OnboardingStep(
            title: "Providers and Privacy",
            subtitle: "Configure cloud or local providers based on your workflow.",
            bullets: [
                "Add API keys in Settings > Providers for OpenAI/Claude/Gemini.",
                "Local providers (Ollama/LM Studio) require local service availability.",
                "Cloud requests happen only when you explicitly choose a cloud provider."
            ]
        ),
        OnboardingStep(
            title: "Simple vs Advanced Mode",
            subtitle: "Choose the right UI depth for your current task.",
            bullets: [
                "Simple Mode keeps the common controls and hides diagnostics noise.",
                "Advanced Mode unlocks provider diagnostics, debug details, and runtime options.",
                "You can switch modes anytime from Settings."
            ]
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(steps[currentStep].title)
                .font(.largeTitle.bold())
            Text(steps[currentStep].subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(steps[currentStep].bullets, id: \.self) { bullet in
                    Label(bullet, systemImage: "checkmark.circle")
                        .labelStyle(.titleAndIcon)
                }
            }

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 6)

            Spacer()

            HStack {
                Button("Skip") {
                    onComplete()
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if currentStep > 0 {
                    Button("Back") {
                        currentStep = max(0, currentStep - 1)
                    }
                }

                Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                    if currentStep == steps.count - 1 {
                        onComplete()
                        isPresented = false
                    } else {
                        currentStep += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 620, minHeight: 420)
    }
}

private struct OnboardingStep {
    let title: String
    let subtitle: String
    let bullets: [String]
}
