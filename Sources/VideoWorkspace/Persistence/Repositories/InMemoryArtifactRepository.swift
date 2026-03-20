import Foundation

actor InMemoryArtifactRepository: ArtifactRepositoryProtocol {
    private var storage: [UUID: ArtifactRecord] = [:]

    func addArtifacts(_ artifacts: [ArtifactRecord]) async {
        for artifact in artifacts {
            storage[artifact.id] = artifact
        }
    }

    func artifacts(forTaskID taskID: UUID) async -> [ArtifactRecord] {
        storage.values
            .filter { $0.relatedTaskID == taskID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func artifacts(forHistoryID historyID: UUID) async -> [ArtifactRecord] {
        storage.values
            .filter { $0.relatedHistoryID == historyID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func artifacts(ofType type: ArtifactType) async -> [ArtifactRecord] {
        storage.values
            .filter { $0.artifactType == type }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
