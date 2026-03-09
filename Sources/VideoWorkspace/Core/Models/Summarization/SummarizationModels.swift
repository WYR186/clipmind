import Foundation

public enum SummaryOutputFormat: String, Codable, CaseIterable, Sendable {
    case markdown
    case plainText
    case json
}

public enum SummaryChunkingStrategy: String, Codable, CaseIterable, Sendable {
    case sizeBased
    case segmentAware
}

public enum ModelCapabilityTag: String, Codable, CaseIterable, Hashable, Sendable {
    case lowCost
    case fast
    case longContext
    case structuredOutputFriendly
    case localPrivacy
    case highQuality
}

public struct ModelRecommendation: Codable, Hashable, Sendable {
    public let provider: ProviderType
    public let modelID: String
    public let reasons: [ModelCapabilityTag]

    public init(provider: ProviderType, modelID: String, reasons: [ModelCapabilityTag]) {
        self.provider = provider
        self.modelID = modelID
        self.reasons = reasons
    }
}

public struct SummarySection: Codable, Hashable, Sendable {
    public let title: String
    public let content: String

    public init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}

public struct SummaryChapter: Codable, Hashable, Sendable {
    public let title: String
    public let startSeconds: Double?
    public let endSeconds: Double?
    public let summary: String

    public init(title: String, startSeconds: Double? = nil, endSeconds: Double? = nil, summary: String) {
        self.title = title
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.summary = summary
    }
}

public struct TimelineEntry: Codable, Hashable, Sendable {
    public let timestampSeconds: Double?
    public let text: String

    public init(timestampSeconds: Double? = nil, text: String) {
        self.timestampSeconds = timestampSeconds
        self.text = text
    }
}

public struct StructuredSummaryPayload: Codable, Hashable, Sendable {
    public let title: String?
    public let abstractSummary: String?
    public let keyPoints: [String]
    public let chapters: [SummaryChapter]
    public let sections: [SummarySection]
    public let timeline: [TimelineEntry]
    public let actionItems: [String]
    public let quotes: [String]

    public init(
        title: String? = nil,
        abstractSummary: String? = nil,
        keyPoints: [String] = [],
        chapters: [SummaryChapter] = [],
        sections: [SummarySection] = [],
        timeline: [TimelineEntry] = [],
        actionItems: [String] = [],
        quotes: [String] = []
    ) {
        self.title = title
        self.abstractSummary = abstractSummary
        self.keyPoints = keyPoints
        self.chapters = chapters
        self.sections = sections
        self.timeline = timeline
        self.actionItems = actionItems
        self.quotes = quotes
    }
}

public struct SummaryArtifact: Codable, Hashable, Sendable {
    public let format: SummaryOutputFormat
    public let path: String

    public init(format: SummaryOutputFormat, path: String) {
        self.format = format
        self.path = path
    }
}

public struct SummarizationRequest: Sendable {
    public let taskID: UUID
    public let transcript: TranscriptItem
    public let summaryRequest: SummaryRequest

    public init(taskID: UUID, transcript: TranscriptItem, summaryRequest: SummaryRequest) {
        self.taskID = taskID
        self.transcript = transcript
        self.summaryRequest = summaryRequest
    }
}
