import Foundation

public enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard
    case onlineVideo
    case localFiles
    case batchJobs
    case tasks
    case history
    case settings

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .onlineVideo:
            return "Online Video"
        case .localFiles:
            return "Local Files"
        case .batchJobs:
            return "Batch Jobs"
        case .tasks:
            return "Tasks"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:
            return "square.grid.2x2"
        case .onlineVideo:
            return "link"
        case .localFiles:
            return "folder"
        case .batchJobs:
            return "square.stack.3d.down.right"
        case .tasks:
            return "list.bullet.rectangle"
        case .history:
            return "clock.arrow.circlepath"
        case .settings:
            return "gearshape"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedRoute: AppRoute = .dashboard
}
