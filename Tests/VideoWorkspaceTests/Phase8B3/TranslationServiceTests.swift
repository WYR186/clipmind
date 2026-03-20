import XCTest
@testable import VideoWorkspace

final class TranslationServiceTests: XCTestCase {
    func testPlainTranslationRequestProducesArtifact() async throws {
        let provider = StubLLMProvider(type: .openAI)
        let registry = StubProviderRegistry(provider: provider)
        let exporter = CapturingExportService()
        let service = TranslationService(
            providerRegistry: registry,
            exportService: exporter,
            logger: ConsoleLogger()
        )

        let request = TranslationRequest(
            taskID: UUID(),
            sourceText: "hello world",
            languagePair: TranslationLanguagePair(sourceLanguage: "en", targetLanguage: "zh"),
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .plain,
            bilingualOutputEnabled: false,
            preserveTimestamps: false,
            preserveTerminology: true,
            outputFormats: [.txt]
        )

        let result = try await service.translate(request: request)
        XCTAssertEqual(result.provider, .openAI)
        XCTAssertEqual(result.mode, .plain)
        XCTAssertTrue(result.translatedText.contains("hello world"))
        XCTAssertEqual(result.artifacts.first?.format, .txt)
    }

    func testSubtitlePreservingTranslationUsesSegmentFlow() async throws {
        let provider = StubLLMProvider(type: .openAI)
        let registry = StubProviderRegistry(provider: provider)
        let exporter = CapturingExportService()
        let service = TranslationService(
            providerRegistry: registry,
            exportService: exporter,
            logger: ConsoleLogger()
        )

        let request = TranslationRequest(
            taskID: UUID(),
            sourceText: "line 1\nline 2",
            sourceSegments: [
                TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 1, text: "line 1"),
                TranscriptSegment(index: 1, startSeconds: 2, endSeconds: 3, text: "line 2")
            ],
            sourceFormat: .srt,
            languagePair: TranslationLanguagePair(sourceLanguage: "en", targetLanguage: "zh"),
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .subtitlePreserving,
            bilingualOutputEnabled: true,
            preserveTimestamps: true,
            preserveTerminology: true,
            outputFormats: [.srt]
        )

        let result = try await service.translate(request: request)
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertNotNil(result.bilingualText)
        XCTAssertEqual(exporter.lastSegmentCount, 2)
        XCTAssertEqual(result.artifacts.first?.format, .srt)
    }
}

private actor StubProviderRegistry: ProviderRegistryProtocol {
    let provider: any LLMProviderProtocol

    init(provider: any LLMProviderProtocol) {
        self.provider = provider
    }

    func availableProviders() async -> [ProviderType] {
        [provider.type]
    }

    func connectionStatus(for provider: ProviderType) async -> ProviderConnectionStatus {
        provider == self.provider.type ? .connected : .disconnected
    }

    func provider(for providerType: ProviderType) async -> (any LLMProviderProtocol)? {
        providerType == provider.type ? provider : nil
    }
}

private struct StubLLMProvider: LLMProviderProtocol {
    let type: ProviderType

    func models() async throws -> [ModelDescriptor] {
        [
            ModelDescriptor(
                id: "gpt-4.1-mini",
                displayName: "gpt-4.1-mini",
                contextWindow: 128_000,
                capabilities: ProviderCapability(
                    supportsTranscription: false,
                    supportsSummarization: true,
                    supportsStreaming: false
                )
            )
        ]
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        SummaryResult(
            taskID: taskID,
            provider: type,
            modelID: request.modelID,
            mode: .abstractSummary,
            length: .short,
            content: "[\(request.outputLanguage)] \(transcript.content)",
            plainText: "[\(request.outputLanguage)] \(transcript.content)"
        )
    }
}

private final class CapturingExportService: TranslationExportServiceProtocol, @unchecked Sendable {
    private(set) var lastSegmentCount: Int = 0

    func write(
        request: TranslationRequest,
        translatedText: String,
        bilingualText: String?,
        translatedSegments: [TranslationSegment]
    ) throws -> [TranslationArtifact] {
        _ = request
        _ = translatedText
        _ = bilingualText
        lastSegmentCount = translatedSegments.count

        if request.outputFormats.contains(.srt) {
            return [TranslationArtifact(format: .srt, path: "/tmp/out.srt")]
        }
        return [TranslationArtifact(format: .txt, path: "/tmp/out.txt")]
    }
}
