import Foundation

enum TranscriptionError: Error, Sendable {
    case invalidTranscriptionRequest(reason: String)
    case sourceFileMissing(path: String)
    case unsupportedSourceType(SourceType)
    case openAIKeyMissing
    case openAIRequestFailed(details: String)
    case openAIResponseDecodeFailed(details: String)
    case whisperExecutableNotFound
    case whisperModelNotFound(path: String)
    case whisperExecutionFailed(details: String)
    case whisperOutputParseFailed(details: String)
    case ffmpegNotFound
    case audioPreprocessFailed(details: String)
    case transcriptExportFailed(details: String)
    case backendUnavailable(TranscriptionBackend)
}

extension TranscriptionError {
    var userMessage: String {
        switch self {
        case let .invalidTranscriptionRequest(reason):
            return reason
        case let .sourceFileMissing(path):
            return "Source file is missing: \(path)"
        case .unsupportedSourceType:
            return "Unsupported source type for transcription."
        case .openAIKeyMissing:
            return "OpenAI API key is missing."
        case .openAIRequestFailed:
            return "OpenAI transcription request failed."
        case .openAIResponseDecodeFailed:
            return "Failed to decode OpenAI transcription response."
        case .whisperExecutableNotFound:
            return "whisper.cpp executable was not found."
        case let .whisperModelNotFound(path):
            return "Whisper model file is missing: \(path)"
        case .whisperExecutionFailed:
            return "whisper.cpp transcription failed."
        case .whisperOutputParseFailed:
            return "Failed to parse whisper.cpp output."
        case .ffmpegNotFound:
            return "ffmpeg is not installed."
        case .audioPreprocessFailed:
            return "Audio preprocessing failed."
        case .transcriptExportFailed:
            return "Transcript export failed."
        case .backendUnavailable:
            return "Transcription backend is unavailable."
        }
    }

    var diagnostics: String {
        switch self {
        case let .invalidTranscriptionRequest(reason):
            return "invalid_transcription_request=\(reason)"
        case let .sourceFileMissing(path):
            return "source_file_missing=\(path)"
        case let .unsupportedSourceType(type):
            return "unsupported_source_type=\(type.rawValue)"
        case .openAIKeyMissing:
            return "openai_key_missing"
        case let .openAIRequestFailed(details):
            return "openai_request_failed=\(details)"
        case let .openAIResponseDecodeFailed(details):
            return "openai_decode_failed=\(details)"
        case .whisperExecutableNotFound:
            return "whisper_executable_not_found"
        case let .whisperModelNotFound(path):
            return "whisper_model_not_found=\(path)"
        case let .whisperExecutionFailed(details):
            return "whisper_execution_failed=\(details)"
        case let .whisperOutputParseFailed(details):
            return "whisper_output_parse_failed=\(details)"
        case .ffmpegNotFound:
            return "ffmpeg_not_found"
        case let .audioPreprocessFailed(details):
            return "audio_preprocess_failed=\(details)"
        case let .transcriptExportFailed(details):
            return "transcript_export_failed=\(details)"
        case let .backendUnavailable(backend):
            return "backend_unavailable=\(backend.rawValue)"
        }
    }
}
