import Foundation

struct TranscriptMapper {
    func mapToTranscriptItem(
        taskID: UUID,
        format: TranscriptFormat,
        content: String,
        languageCode: String,
        sourceType: SubtitleSourceType = .asr,
        segments: [TranscriptSegment],
        artifacts: [TranscriptArtifact],
        backend: TranscriptionBackend,
        modelID: String,
        detectedLanguage: String?
    ) -> TranscriptItem {
        TranscriptItem(
            taskID: taskID,
            sourceType: sourceType,
            languageCode: languageCode,
            format: format,
            content: content,
            segments: segments,
            artifacts: artifacts,
            backend: backend,
            modelID: modelID,
            detectedLanguage: detectedLanguage
        )
    }
}
