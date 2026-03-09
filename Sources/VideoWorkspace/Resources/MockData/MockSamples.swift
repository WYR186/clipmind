import Foundation

enum MockSamples {
    static let onlineURL = "https://youtube.com/watch?v=mock-video"
    static let localPath = "/tmp/videoworkspace-sample.mp4"

    static let transcriptText = """
    Welcome to this mock transcript. This content demonstrates the local-first video workspace flow.
    We inspect media, extract transcript, summarize key points, and persist history records.
    """

    static let summaryText = """
    Key points:
    1. The workflow starts from online or local media sources.
    2. Metadata inspection and transcript generation happen before summarization.
    3. Results are persisted locally for future review.
    """
}
