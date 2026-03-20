import XCTest
@testable import VideoWorkspace

final class BatchProgressAggregatorTests: XCTestCase {
    private let aggregator = BatchProgressAggregator()

    func testAggregateCountsAndProgress() {
        let batchID = UUID()
        let items: [BatchJobItem] = [
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "a"), status: .completed, progress: 1),
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "b"), status: .failed, progress: 0.2),
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "c"), status: .running, progress: 0.5),
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "d"), status: .pending, progress: 0)
        ]

        let progress = aggregator.aggregate(items: items)

        XCTAssertEqual(progress.totalCount, 4)
        XCTAssertEqual(progress.completedCount, 1)
        XCTAssertEqual(progress.failedCount, 1)
        XCTAssertEqual(progress.runningCount, 1)
        XCTAssertEqual(progress.pendingCount, 1)
        XCTAssertEqual(progress.cancelledCount, 0)
        XCTAssertEqual(progress.fractionCompleted, 0.625, accuracy: 0.001)
    }

    func testStatusBecomesCompletedWithFailuresForMixedTerminalStates() {
        let batchID = UUID()
        let items: [BatchJobItem] = [
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "a"), status: .completed, progress: 1),
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "b"), status: .failed, progress: 1)
        ]

        let progress = aggregator.aggregate(items: items)
        let status = aggregator.status(for: items, progress: progress)

        XCTAssertEqual(status, .completedWithFailures)
    }

    func testStatusBecomesCancelledWhenAllItemsCancelled() {
        let batchID = UUID()
        let items: [BatchJobItem] = [
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "a"), status: .cancelled, progress: 1),
            BatchJobItem(batchJobID: batchID, source: MediaSource(type: .url, value: "b"), status: .skipped, progress: 1)
        ]

        let progress = aggregator.aggregate(items: items)
        let status = aggregator.status(for: items, progress: progress)

        XCTAssertEqual(status, .cancelled)
    }
}
