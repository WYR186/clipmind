import Foundation

struct BatchProgressAggregator {
    func aggregate(items: [BatchJobItem]) -> BatchJobProgress {
        guard !items.isEmpty else {
            return .empty
        }

        var completed = 0
        var failed = 0
        var running = 0
        var pending = 0
        var cancelled = 0
        var runningProgressTotal: Double = 0

        for item in items {
            switch item.status {
            case .completed:
                completed += 1
            case .failed:
                failed += 1
            case .running:
                running += 1
                runningProgressTotal += item.progress
            case .pending:
                pending += 1
            case .skipped, .cancelled:
                cancelled += 1
            case .interrupted:
                failed += 1
            }
        }

        let total = items.count
        let terminalCount = completed + failed + cancelled
        let raw = (Double(terminalCount) + runningProgressTotal) / Double(max(total, 1))

        return BatchJobProgress(
            totalCount: total,
            completedCount: completed,
            failedCount: failed,
            runningCount: running,
            pendingCount: pending,
            cancelledCount: cancelled,
            fractionCompleted: raw
        )
    }

    func status(for items: [BatchJobItem], progress: BatchJobProgress) -> BatchJobStatus {
        guard !items.isEmpty else {
            return .completed
        }

        if items.contains(where: { $0.status == .running }) {
            return .running
        }

        if items.contains(where: { $0.status == .pending }) {
            return progress.terminalCount == 0 ? .queued : .running
        }

        if items.contains(where: { $0.status == .interrupted }) {
            return .interrupted
        }

        if progress.cancelledCount == progress.totalCount {
            return .cancelled
        }

        if progress.failedCount == progress.totalCount {
            return .failed
        }

        if progress.failedCount > 0 || progress.cancelledCount > 0 {
            return .completedWithFailures
        }

        return .completed
    }
}
