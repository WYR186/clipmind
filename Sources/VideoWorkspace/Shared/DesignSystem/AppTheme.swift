import SwiftUI

// MARK: - Layout constants

enum AppTheme {
    // MARK: Sidebar / layout
    static let sidebarMinWidth: CGFloat = 190
    static let detailMinWidth: CGFloat = 760

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner radius
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let pill: CGFloat = 999
    }

    // MARK: Icon sizes
    enum Icon {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
        static let hero: CGFloat = 64
    }

    // MARK: Animation
    enum Animation {
        static let fast: SwiftUI.Animation = .easeInOut(duration: 0.15)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.4)
        static let spring: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.75)
    }

    // MARK: Typography scale
    enum Typography {
        static let caption2 = Font.caption2
        static let caption = Font.caption
        static let footnote = Font.footnote
        static let subheadline = Font.subheadline
        static let body = Font.body
        static let headline = Font.headline
        static let title3 = Font.title3
        static let title2 = Font.title2
        static let title = Font.title
        static let largeTitle = Font.largeTitle

        static let code = Font.system(.body, design: .monospaced)
        static let codeSmall = Font.system(.caption, design: .monospaced)
    }

    // MARK: Semantic colors
    enum Colors {
        // Status
        static var success: Color { Color.green }
        static var warning: Color { Color.yellow }
        static var error: Color { Color.red }
        static var info: Color { Color.blue }

        // Neutral
        static var muted: Color { Color.secondary }
        static var placeholder: Color { Color(nsColor: .placeholderTextColor) }

        // Background variants
        static var cardBackground: Color { Color(nsColor: .windowBackgroundColor) }
        static var rowBackground: Color { Color(nsColor: .controlBackgroundColor) }
        static var separatorColor: Color { Color(nsColor: .separatorColor) }

        // Status badge tints by task status
        static func statusTint(for status: String) -> Color {
            switch status.lowercased() {
            case "completed": return success
            case "running": return Color.orange
            case "paused": return info
            case "failed": return error
            case "cancelled", "skipped": return muted
            case "queued", "pending": return Color.gray
            case "interrupted": return Color.pink
            default: return muted
            }
        }
    }

    // MARK: Shadow
    enum Shadow {
        static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        static let subtle = ShadowStyle(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        static let card = ShadowStyle(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        static let elevated = ShadowStyle(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Shadow style helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func appShadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    func cardStyle() -> some View {
        self
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            .appShadow(AppTheme.Shadow.subtle)
    }
}
