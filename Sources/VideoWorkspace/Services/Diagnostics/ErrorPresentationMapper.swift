import Foundation

struct ErrorPresentationMapper {
    static func map(_ error: Error, context: String) -> UserFacingError {
        if let mediaError = error as? MediaInspectionError {
            return mapMediaInspectionError(mediaError)
        }

        if let downloadError = error as? DownloadError {
            return mapDownloadError(downloadError)
        }

        if let transcriptionError = error as? TranscriptionError {
            return mapTranscriptionError(transcriptionError)
        }

        if let summarizationError = error as? SummarizationError {
            return mapSummarizationError(summarizationError)
        }

        if let translationError = error as? TranslationError {
            return mapTranslationError(translationError)
        }

        if let externalToolError = error as? ExternalToolError {
            return mapExternalToolError(externalToolError)
        }

        if let sourceExpansionError = error as? SourceExpansionError {
            return mapSourceExpansionError(sourceExpansionError)
        }

        if let expandedSourceMapperError = error as? ExpandedSourceMapperError {
            return mapExpandedSourceMapperError(expandedSourceMapperError)
        }

        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }

        if let cocoaError = error as? CocoaError {
            return mapCocoaError(cocoaError)
        }

        return UserFacingError(
            title: AppCopy.Errors.operationFailedTitle,
            message: "The operation failed in \(context).",
            code: "UNKNOWN_ERROR",
            service: context,
            diagnostics: error.localizedDescription,
            suggestions: [.retry]
        )
    }

    private static func mapMediaInspectionError(_ error: MediaInspectionError) -> UserFacingError {
        switch error {
        case let .external(external):
            return mapExternalToolError(external)
        case let .failed(reason):
            return UserFacingError(
                title: "Inspection Failed",
                message: reason,
                code: "INSPECTION_FAILED",
                service: "MediaInspection",
                diagnostics: reason,
                suggestions: [.verifyURL, .retry]
            )
        }
    }

    private static func mapDownloadError(_ error: DownloadError) -> UserFacingError {
        switch error {
        case let .invalidSelection(reason):
            return UserFacingError(
                title: "Invalid Download Selection",
                message: reason,
                code: "DOWNLOAD_INVALID_SELECTION",
                service: "Download",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case let .outputDirectoryUnavailable(path):
            return UserFacingError(
                title: "Output Directory Unavailable",
                message: "The selected output directory cannot be used. Grant access permission or choose another directory: \(path)",
                code: "DOWNLOAD_OUTPUT_DIRECTORY_UNAVAILABLE",
                service: "Download",
                diagnostics: error.diagnostics,
                suggestions: [.chooseWritableDirectory, .checkPermissions]
            )
        case .filenameResolutionFailed:
            return UserFacingError(
                title: "File Name Resolution Failed",
                message: "The app could not determine the output file name.",
                code: "DOWNLOAD_FILENAME_FAILED",
                service: "Download",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .ytDLPNotFound:
            return UserFacingError(
                title: "yt-dlp Missing",
                message: "yt-dlp is required for online downloads.",
                code: "DOWNLOAD_YTDLP_NOT_FOUND",
                service: "Download",
                diagnostics: error.diagnostics,
                suggestions: [.installExternalTools, .installViaHomebrew]
            )
        case .ffmpegNotFound:
            return UserFacingError(
                title: "ffmpeg Missing",
                message: "ffmpeg is required for this download flow.",
                code: "DOWNLOAD_FFMPEG_NOT_FOUND",
                service: "Download",
                diagnostics: error.diagnostics,
                suggestions: [.installExternalTools, .installViaHomebrew]
            )
        case .commandExecutionFailed:
            return UserFacingError(
                title: "Download Command Failed",
                message: "The download command failed. Please retry or switch source.",
                code: "DOWNLOAD_COMMAND_FAILED",
                service: "yt-dlp",
                diagnostics: error.diagnostics,
                suggestions: [.retry, .verifyNetwork]
            )
        case .progressParseFailed:
            return UserFacingError(
                title: "Progress Parsing Failed",
                message: "The download is running but progress parsing failed.",
                code: "DOWNLOAD_PROGRESS_PARSE_FAILED",
                service: "Download",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .outputNotProduced:
            return UserFacingError(
                title: "Output File Not Found",
                message: "The download finished but no output file was detected.",
                code: "DOWNLOAD_OUTPUT_NOT_PRODUCED",
                service: "Download",
                diagnostics: error.diagnostics,
                suggestions: [.retry, .chooseWritableDirectory]
            )
        }
    }

    private static func mapTranscriptionError(_ error: TranscriptionError) -> UserFacingError {
        switch error {
        case let .invalidTranscriptionRequest(reason):
            return UserFacingError(
                title: "Invalid Transcription Request",
                message: reason,
                code: "TRANSCRIPTION_INVALID_REQUEST",
                service: "Transcription",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case let .sourceFileMissing(path):
            return UserFacingError(
                title: "Source File Missing",
                message: "The source file was not found: \(path)",
                code: "TRANSCRIPTION_SOURCE_MISSING",
                service: "Transcription",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .unsupportedSourceType:
            return UserFacingError(
                title: "Unsupported Source Type",
                message: "This source type is not supported for transcription.",
                code: "TRANSCRIPTION_SOURCE_UNSUPPORTED",
                service: "Transcription",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .openAIKeyMissing:
            return UserFacingError(
                title: "OpenAI API Key Missing",
                message: "Configure your OpenAI API key in Settings.",
                code: "TRANSCRIPTION_OPENAI_KEY_MISSING",
                service: "OpenAI",
                diagnostics: error.diagnostics,
                suggestions: [.configureAPIKey]
            )
        case .openAIRequestFailed:
            return UserFacingError(
                title: "OpenAI Request Failed",
                message: "OpenAI transcription request failed.",
                code: "TRANSCRIPTION_OPENAI_REQUEST_FAILED",
                service: "OpenAI",
                diagnostics: error.diagnostics,
                suggestions: [.verifyNetwork, .retry, .configureAPIKey]
            )
        case .openAIResponseDecodeFailed:
            return UserFacingError(
                title: "OpenAI Response Invalid",
                message: "The transcription response format was unexpected.",
                code: "TRANSCRIPTION_OPENAI_DECODE_FAILED",
                service: "OpenAI",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .whisperExecutableNotFound:
            return UserFacingError(
                title: "whisper.cpp Missing",
                message: "whisper.cpp executable was not found.",
                code: "TRANSCRIPTION_WHISPER_EXECUTABLE_NOT_FOUND",
                service: "whisper.cpp",
                diagnostics: error.diagnostics,
                suggestions: [.installExternalTools, .installViaHomebrew]
            )
        case .whisperModelNotFound:
            return UserFacingError(
                title: "Whisper Model Missing",
                message: "The configured Whisper model file was not found.",
                code: "TRANSCRIPTION_WHISPER_MODEL_NOT_FOUND",
                service: "whisper.cpp",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .whisperExecutionFailed:
            return UserFacingError(
                title: "whisper.cpp Failed",
                message: "Local transcription failed during execution.",
                code: "TRANSCRIPTION_WHISPER_EXECUTION_FAILED",
                service: "whisper.cpp",
                diagnostics: error.diagnostics,
                suggestions: [.retry, .startLocalService]
            )
        case .whisperOutputParseFailed:
            return UserFacingError(
                title: "Whisper Output Invalid",
                message: "Failed to parse local transcription output.",
                code: "TRANSCRIPTION_WHISPER_OUTPUT_PARSE_FAILED",
                service: "whisper.cpp",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .ffmpegNotFound:
            return UserFacingError(
                title: "ffmpeg Missing",
                message: "ffmpeg is required for preprocessing.",
                code: "TRANSCRIPTION_FFMPEG_NOT_FOUND",
                service: "ffmpeg",
                diagnostics: error.diagnostics,
                suggestions: [.installExternalTools, .installViaHomebrew]
            )
        case .audioPreprocessFailed:
            return UserFacingError(
                title: "Audio Preprocessing Failed",
                message: "Audio preprocessing failed before transcription.",
                code: "TRANSCRIPTION_AUDIO_PREPROCESS_FAILED",
                service: "ffmpeg",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .transcriptExportFailed:
            return UserFacingError(
                title: "Transcript Export Failed",
                message: "Transcript generation succeeded, but export failed.",
                code: "TRANSCRIPTION_EXPORT_FAILED",
                service: "TranscriptExport",
                diagnostics: error.diagnostics,
                suggestions: [.chooseWritableDirectory, .checkPermissions]
            )
        case .backendUnavailable:
            return UserFacingError(
                title: "Backend Unavailable",
                message: "The selected transcription backend is unavailable.",
                code: "TRANSCRIPTION_BACKEND_UNAVAILABLE",
                service: "Transcription",
                diagnostics: error.diagnostics,
                suggestions: [.switchProvider, .retry]
            )
        }
    }

    private static func mapSummarizationError(_ error: SummarizationError) -> UserFacingError {
        switch error {
        case let .invalidSummaryRequest(reason):
            return UserFacingError(
                title: "Invalid Summary Request",
                message: reason,
                code: "SUMMARY_INVALID_REQUEST",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .transcriptMissing:
            return UserFacingError(
                title: "Transcript Missing",
                message: "Generate a transcript before summarizing.",
                code: "SUMMARY_TRANSCRIPT_MISSING",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .transcriptTooLargeWithoutChunking:
            return UserFacingError(
                title: "Transcript Too Large",
                message: "The transcript is too large for the selected mode.",
                code: "SUMMARY_TRANSCRIPT_TOO_LARGE",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.switchProvider, .retry]
            )
        case .providerUnavailable:
            return UserFacingError(
                title: "Provider Unavailable",
                message: "The selected summary provider is unavailable.",
                code: "SUMMARY_PROVIDER_UNAVAILABLE",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.switchProvider, .retry]
            )
        case .modelUnavailable:
            return UserFacingError(
                title: "Model Unavailable",
                message: "The selected model is unavailable.",
                code: "SUMMARY_MODEL_UNAVAILABLE",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.switchProvider, .retry]
            )
        case .apiKeyMissing:
            return UserFacingError(
                title: "API Key Missing",
                message: "Configure provider API key in Settings.",
                code: "SUMMARY_API_KEY_MISSING",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.configureAPIKey]
            )
        case .requestFailed:
            return UserFacingError(
                title: "Summary Request Failed",
                message: "The summary provider request failed.",
                code: "SUMMARY_REQUEST_FAILED",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.verifyNetwork, .switchProvider, .retry]
            )
        case .responseDecodeFailed:
            return UserFacingError(
                title: "Summary Response Invalid",
                message: "The provider response could not be decoded.",
                code: "SUMMARY_RESPONSE_DECODE_FAILED",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .structuredOutputNotSupported:
            return UserFacingError(
                title: "Structured Output Unsupported",
                message: "The selected provider does not support structured output.",
                code: "SUMMARY_STRUCTURED_OUTPUT_UNSUPPORTED",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.switchProvider]
            )
        case .localProviderNotRunning:
            return UserFacingError(
                title: "Local Provider Offline",
                message: "The local provider service is not running.",
                code: "SUMMARY_LOCAL_PROVIDER_OFFLINE",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.startLocalService, .retry]
            )
        case .normalizationFailed:
            return UserFacingError(
                title: "Summary Normalization Failed",
                message: "The summary was generated, but normalization failed.",
                code: "SUMMARY_NORMALIZATION_FAILED",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .aggregationFailed:
            return UserFacingError(
                title: "Summary Aggregation Failed",
                message: "Failed to combine chunk summaries.",
                code: "SUMMARY_AGGREGATION_FAILED",
                service: "Summarization",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        }
    }

    private static func mapTranslationError(_ error: TranslationError) -> UserFacingError {
        switch error {
        case let .invalidRequest(reason):
            return UserFacingError(
                title: "Invalid Translation Request",
                message: reason,
                code: "TRANSLATION_INVALID_REQUEST",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .sourceTextMissing:
            return UserFacingError(
                title: "Transcript Missing",
                message: "Translation requires transcript text.",
                code: "TRANSLATION_SOURCE_MISSING",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .providerUnavailable:
            return UserFacingError(
                title: "Provider Unavailable",
                message: "The selected translation provider is unavailable.",
                code: "TRANSLATION_PROVIDER_UNAVAILABLE",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.switchProvider, .retry]
            )
        case .modelUnavailable:
            return UserFacingError(
                title: "Model Unavailable",
                message: "The selected translation model is unavailable.",
                code: "TRANSLATION_MODEL_UNAVAILABLE",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.switchProvider, .retry]
            )
        case .apiKeyMissing:
            return UserFacingError(
                title: "API Key Missing",
                message: "Configure provider API key in Settings.",
                code: "TRANSLATION_API_KEY_MISSING",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.configureAPIKey]
            )
        case .requestFailed:
            return UserFacingError(
                title: "Translation Request Failed",
                message: "The translation provider request failed.",
                code: "TRANSLATION_REQUEST_FAILED",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.verifyNetwork, .switchProvider, .retry]
            )
        case .responseDecodeFailed:
            return UserFacingError(
                title: "Translation Response Invalid",
                message: "The provider response could not be decoded.",
                code: "TRANSLATION_RESPONSE_DECODE_FAILED",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .subtitleStructureUnavailable:
            return UserFacingError(
                title: "Subtitle Structure Unavailable",
                message: "Subtitle export requires segment timing data.",
                code: "TRANSLATION_SUBTITLE_STRUCTURE_UNAVAILABLE",
                service: "Translation",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .exportFailed:
            return UserFacingError(
                title: "Translation Export Failed",
                message: "Translation succeeded but exporting files failed.",
                code: "TRANSLATION_EXPORT_FAILED",
                service: "TranslationExport",
                diagnostics: error.diagnostics,
                suggestions: [.chooseWritableDirectory, .checkPermissions]
            )
        }
    }

    private static func mapExternalToolError(_ error: ExternalToolError) -> UserFacingError {
        switch error {
        case let .toolNotFound(tool, _):
            return UserFacingError(
                title: AppCopy.Errors.toolMissingTitle,
                message: "Required tool is missing: \(tool).",
                code: "TOOL_NOT_FOUND",
                service: tool,
                diagnostics: error.diagnostics,
                suggestions: [.installExternalTools, .installViaHomebrew]
            )
        case .invalidSource:
            return UserFacingError(
                title: "Invalid Source",
                message: "The media source is invalid.",
                code: "INVALID_SOURCE",
                service: "Media",
                diagnostics: error.diagnostics,
                suggestions: [.verifyURL]
            )
        case .unsupportedSourceType:
            return UserFacingError(
                title: "Unsupported Source",
                message: "The source type is not supported.",
                code: "UNSUPPORTED_SOURCE_TYPE",
                service: "Media",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .executionFailed:
            return UserFacingError(
                title: "External Command Failed",
                message: "Media command execution failed.",
                code: "TOOL_EXECUTION_FAILED",
                service: "ExternalTool",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .invalidOutput:
            return UserFacingError(
                title: "Invalid Tool Output",
                message: "The external tool returned invalid output.",
                code: "TOOL_INVALID_OUTPUT",
                service: "ExternalTool",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .decodeFailed:
            return UserFacingError(
                title: "Output Decode Failed",
                message: "Failed to decode external tool output.",
                code: "TOOL_DECODE_FAILED",
                service: "ExternalTool",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        }
    }

    private static func mapSourceExpansionError(_ error: SourceExpansionError) -> UserFacingError {
        switch error {
        case let .invalidInput(reason):
            return UserFacingError(
                title: "Invalid Source Input",
                message: reason,
                code: "SOURCE_EXPANSION_INVALID_INPUT",
                service: "SourceExpansion",
                diagnostics: error.diagnostics,
                suggestions: [.verifyURL, .retry]
            )
        case .playlistNotDetected:
            return UserFacingError(
                title: "Playlist Not Detected",
                message: "The URL does not appear to be a playlist source.",
                code: "SOURCE_EXPANSION_PLAYLIST_NOT_DETECTED",
                service: "SourceExpansion",
                diagnostics: error.diagnostics,
                suggestions: [.verifyURL, .retry]
            )
        case .noPlaylistEntries:
            return UserFacingError(
                title: "Playlist Is Empty",
                message: "No playlist entries were returned from the source.",
                code: "SOURCE_EXPANSION_EMPTY_PLAYLIST",
                service: "SourceExpansion",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        case .noSelectableItems:
            return UserFacingError(
                title: "No Valid Items",
                message: "No valid entries could be selected from this source.",
                code: "SOURCE_EXPANSION_NO_SELECTABLE_ITEMS",
                service: "SourceExpansion",
                diagnostics: error.diagnostics,
                suggestions: [.verifyURL, .retry]
            )
        case let .external(externalError):
            return mapExternalToolError(externalError)
        case .decodeFailed:
            return UserFacingError(
                title: "Expansion Decode Failed",
                message: "Failed to decode the expanded source payload.",
                code: "SOURCE_EXPANSION_DECODE_FAILED",
                service: "SourceExpansion",
                diagnostics: error.diagnostics,
                suggestions: [.retry]
            )
        }
    }

    private static func mapExpandedSourceMapperError(_ error: ExpandedSourceMapperError) -> UserFacingError {
        switch error {
        case .noSelectedItems:
            return UserFacingError(
                title: "No Items Selected",
                message: "Select at least one valid source item before creating a batch.",
                code: "EXPANDED_SOURCE_NO_SELECTION",
                service: "BatchCreation",
                diagnostics: error.localizedDescription,
                suggestions: [.retry]
            )
        }
    }

    private static func mapURLError(_ error: URLError) -> UserFacingError {
        let suggestion: [RecoverySuggestion]
        let message: String
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut:
            message = "Network connection failed."
            suggestion = [.verifyNetwork, .retry]
        case .badURL, .unsupportedURL:
            message = "The URL is invalid."
            suggestion = [.verifyURL]
        default:
            message = "A network error occurred."
            suggestion = [.verifyNetwork, .retry]
        }

        return UserFacingError(
            title: AppCopy.Errors.networkTitle,
            message: message,
            code: "NETWORK_ERROR_\(error.code.rawValue)",
            service: "Network",
            diagnostics: error.localizedDescription,
            suggestions: suggestion
        )
    }

    private static func mapCocoaError(_ error: CocoaError) -> UserFacingError {
        switch error.code {
        case .fileWriteOutOfSpace:
            return UserFacingError(
                title: AppCopy.Errors.diskInsufficientTitle,
                message: "There is not enough disk space for this operation.",
                code: "DISK_SPACE_INSUFFICIENT",
                service: "FileSystem",
                diagnostics: error.localizedDescription,
                suggestions: [.freeDiskSpace, .retry]
            )
        case .fileWriteNoPermission, .fileReadNoPermission:
            return UserFacingError(
                title: AppCopy.Errors.permissionDeniedTitle,
                message: "The app does not have permission for this file operation.",
                code: "FILESYSTEM_PERMISSION_DENIED",
                service: "FileSystem",
                diagnostics: error.localizedDescription,
                suggestions: [.checkPermissions]
            )
        default:
            return UserFacingError(
                title: "File Operation Failed",
                message: "A file operation failed.",
                code: "FILESYSTEM_ERROR_\(error.code.rawValue)",
                service: "FileSystem",
                diagnostics: error.localizedDescription,
                suggestions: [.retry]
            )
        }
    }
}
