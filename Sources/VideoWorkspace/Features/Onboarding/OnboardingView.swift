import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to VideoWorkspace")
                .font(.largeTitle.bold())

            Text("Inspect videos, generate transcript, summarize content, and keep everything local-first.")
                .font(.title3)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Paste an online video URL or import a local file")
                Text("2. Run transcript and summarization tasks")
                Text("3. Review outputs from Tasks and History")
            }

            Spacer()

            HStack {
                Spacer()
                Button("Start") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 540, minHeight: 360)
    }
}
