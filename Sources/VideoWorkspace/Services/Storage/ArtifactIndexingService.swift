import Foundation

protocol ArtifactIndexingServiceProtocol: Sendable {
    func indexArtifacts(for entry: HistoryEntry) async
}

struct ArtifactIndexingService: ArtifactIndexingServiceProtocol {
    let artifactRepository: any ArtifactRepositoryProtocol
    let logger: any AppLoggerProtocol
    let fileManager: FileManager

    init(
        artifactRepository: any ArtifactRepositoryProtocol,
        logger: any AppLoggerProtocol,
        fileManager: FileManager = .default
    ) {
        self.artifactRepository = artifactRepository
        self.logger = logger
        self.fileManager = fileManager
    }

    func indexArtifacts(for entry: HistoryEntry) async {
        let records = buildArtifacts(entry: entry)
        guard !records.isEmpty else { return }
        await artifactRepository.addArtifacts(records)
        logger.debug("Artifact indexing completed: history=\(entry.id), count=\(records.count)")
    }

    private func buildArtifacts(entry: HistoryEntry) -> [ArtifactRecord] {
        var records: [ArtifactRecord] = []

        if let download = entry.downloadResult {
            let type: ArtifactType
            switch download.kind {
            case .video:
                type = .downloadVideo
            case .audioOnly:
                type = .downloadAudio
            case .subtitle:
                type = .downloadSubtitle
            }

            records.append(
                ArtifactRecord(
                    ownerType: .download,
                    ownerID: entry.id,
                    relatedTaskID: entry.taskID,
                    relatedHistoryID: entry.id,
                    artifactType: type,
                    filePath: download.outputPath,
                    fileFormat: URL(fileURLWithPath: download.outputPath).pathExtension.lowercased(),
                    sizeBytes: fileSize(at: download.outputPath),
                    backend: nil,
                    provider: nil,
                    model: nil,
                    createdAt: entry.createdAt
                )
            )
        }

        if let transcript = entry.transcript {
            for artifact in transcript.artifacts {
                let type: ArtifactType
                switch artifact.kind {
                case .txt:
                    type = .transcriptTXT
                case .srt:
                    type = .transcriptSRT
                case .vtt:
                    type = .transcriptVTT
                }

                records.append(
                    ArtifactRecord(
                        ownerType: .transcript,
                        ownerID: transcript.id,
                        relatedTaskID: entry.taskID ?? transcript.taskID,
                        relatedHistoryID: entry.id,
                        artifactType: type,
                        filePath: artifact.path,
                        fileFormat: artifact.kind.rawValue,
                        sizeBytes: fileSize(at: artifact.path),
                        backend: transcript.backend?.rawValue,
                        provider: nil,
                        model: transcript.modelID,
                        createdAt: entry.createdAt
                    )
                )
            }
        }

        if let summary = entry.summary {
            for artifact in summary.artifacts {
                let type: ArtifactType
                switch artifact.format {
                case .markdown:
                    type = .summaryMarkdown
                case .plainText:
                    type = .summaryPlainText
                case .json:
                    type = .summaryJSON
                }

                records.append(
                    ArtifactRecord(
                        ownerType: .summary,
                        ownerID: summary.id,
                        relatedTaskID: entry.taskID ?? summary.taskID,
                        relatedHistoryID: entry.id,
                        artifactType: type,
                        filePath: artifact.path,
                        fileFormat: artifact.format.rawValue,
                        sizeBytes: fileSize(at: artifact.path),
                        backend: nil,
                        provider: summary.provider,
                        model: summary.modelID,
                        createdAt: summary.createdAt
                    )
                )
            }
        }

        // TODO: Add artifact deduplication and cleanup policy hooks.
        return records
    }

    private func fileSize(at path: String) -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let number = attributes[.size] as? NSNumber
        else {
            return nil
        }
        return number.int64Value
    }
}
