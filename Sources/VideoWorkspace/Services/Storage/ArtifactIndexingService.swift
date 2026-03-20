import Foundation

protocol ArtifactIndexingServiceProtocol: Sendable {
    func indexArtifacts(for entry: HistoryEntry) async
}

struct ArtifactIndexingService: ArtifactIndexingServiceProtocol {
    let artifactRepository: any ArtifactRepositoryProtocol
    let logger: any AppLoggerProtocol

    init(
        artifactRepository: any ArtifactRepositoryProtocol,
        logger: any AppLoggerProtocol
    ) {
        self.artifactRepository = artifactRepository
        self.logger = logger
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

        if let translation = entry.translation {
            for artifact in translation.artifacts {
                let type: ArtifactType
                switch artifact.format {
                case .txt:
                    type = .translationTXT
                case .srt:
                    type = .translationSRT
                case .vtt:
                    type = .translationVTT
                case .markdown:
                    type = .translationMarkdown
                }

                records.append(
                    ArtifactRecord(
                        ownerType: .translation,
                        ownerID: translation.id,
                        relatedTaskID: entry.taskID ?? translation.taskID,
                        relatedHistoryID: entry.id,
                        artifactType: type,
                        filePath: artifact.path,
                        fileFormat: artifact.format.rawValue,
                        sizeBytes: fileSize(at: artifact.path),
                        backend: nil,
                        provider: translation.provider,
                        model: translation.modelID,
                        createdAt: translation.createdAt
                    )
                )
            }
        }

        // TODO: Add artifact deduplication and cleanup policy hooks.
        return records
    }

    private func fileSize(at path: String) -> Int64? {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let number = attributes[.size] as? NSNumber
        else {
            return nil
        }
        return number.int64Value
    }
}
