import SwiftUI

struct SectionCardView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox(title) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }
}
