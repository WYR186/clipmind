import Foundation

enum BatchCreationError: LocalizedError {
    case emptyInput
    case allInputsInvalid

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No valid inputs were provided for batch creation."
        case .allInputsInvalid:
            return "All provided batch inputs were invalid or duplicated."
        }
    }
}

struct BatchCreationService: BatchCreationServiceProtocol {
    private let batchRepository: any BatchJobRepositoryProtocol
    private let logger: any AppLoggerProtocol

    init(
        batchRepository: any BatchJobRepositoryProtocol,
        logger: any AppLoggerProtocol
    ) {
        self.batchRepository = batchRepository
        self.logger = logger
    }

    func createBatch(request: BatchCreationRequest) async throws -> BatchJob {
        guard !request.sources.isEmpty else {
            throw BatchCreationError.emptyInput
        }

        let normalizedSources = normalizeSources(request.sources, sourceType: request.sourceType)
        guard !normalizedSources.isEmpty else {
            throw BatchCreationError.allInputsInvalid
        }

        let now = Date()
        let progress = BatchJobProgress(
            totalCount: normalizedSources.count,
            completedCount: 0,
            failedCount: 0,
            runningCount: 0,
            pendingCount: normalizedSources.count,
            cancelledCount: 0,
            fractionCompleted: 0
        )

        let resolvedTitle = makeBatchTitle(request: request, count: normalizedSources.count)
        let job = BatchJob(
            title: resolvedTitle,
            sourceType: request.sourceType,
            createdAt: now,
            updatedAt: now,
            status: .queued,
            progress: progress,
            operationTemplate: request.operationTemplate,
            childTaskIDs: [],
            lastErrorSummary: nil,
            sourceDescriptor: request.sourceDescriptor?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            sourceMetadataJSON: request.sourceMetadataJSON?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        )

        let items = normalizedSources.map { source in
            BatchJobItem(
                batchJobID: job.id,
                source: source,
                status: .pending,
                progress: 0,
                createdAt: now,
                updatedAt: now,
                failureReason: nil,
                errorCode: nil
            )
        }

        await batchRepository.createBatch(job: job, items: items)
        logger.info("Batch created: id=\(job.id) count=\(items.count) type=\(request.sourceType.rawValue)")
        return job
    }

    private func normalizeSources(_ sources: [MediaSource], sourceType: BatchSourceType) -> [MediaSource] {
        var seen: Set<String> = []
        var filtered: [MediaSource] = []

        for source in sources {
            guard isValid(source: source, expected: sourceType) else {
                continue
            }

            let normalizedValue = source.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedValue.isEmpty else {
                continue
            }

            let dedupeKey = "\(source.type.rawValue)::\(normalizedValue.lowercased())"
            guard seen.insert(dedupeKey).inserted else {
                continue
            }

            filtered.append(MediaSource(type: source.type, value: normalizedValue))
        }

        return filtered
    }

    private func isValid(source: MediaSource, expected: BatchSourceType) -> Bool {
        switch expected {
        case .urlBatch:
            guard source.type == .url else { return false }
            return isValidURL(source.value)
        case .localFilesBatch:
            guard source.type == .localFile else { return false }
            return !source.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .mixed:
            if source.type == .url {
                return isValidURL(source.value)
            }
            return !source.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func isValidURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme else {
            return false
        }
        return ["http", "https"].contains(scheme.lowercased())
    }

    private func makeBatchTitle(request: BatchCreationRequest, count: Int) -> String {
        if let title = request.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }

        let sourceLabel: String
        switch request.sourceType {
        case .urlBatch:
            sourceLabel = "URLs"
        case .localFilesBatch:
            sourceLabel = "Local Files"
        case .mixed:
            sourceLabel = "Mixed"
        }

        return "\(request.operationTemplate.operationType.rawValue.capitalized) Batch (\(count) \(sourceLabel))"
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
