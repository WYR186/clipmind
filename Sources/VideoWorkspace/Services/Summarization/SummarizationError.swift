import Foundation

enum SummarizationError: Error, Sendable {
    case invalidSummaryRequest(reason: String)
    case transcriptMissing
    case transcriptTooLargeWithoutChunking
    case providerUnavailable(ProviderType)
    case modelUnavailable(provider: ProviderType, modelID: String)
    case apiKeyMissing(provider: ProviderType)
    case requestFailed(provider: ProviderType, details: String)
    case responseDecodeFailed(provider: ProviderType, details: String)
    case structuredOutputNotSupported(provider: ProviderType)
    case localProviderNotRunning(provider: ProviderType)
    case normalizationFailed(details: String)
    case aggregationFailed(details: String)
}

extension SummarizationError {
    var userMessage: String {
        switch self {
        case let .invalidSummaryRequest(reason):
            return reason
        case .transcriptMissing:
            return "Transcript is missing."
        case .transcriptTooLargeWithoutChunking:
            return "Transcript is too long and requires chunking."
        case .providerUnavailable:
            return "Summary provider is unavailable."
        case .modelUnavailable:
            return "Selected summary model is unavailable."
        case .apiKeyMissing:
            return "API key is missing for summary provider."
        case .requestFailed:
            return "Summary request failed."
        case .responseDecodeFailed:
            return "Failed to decode summary response."
        case .structuredOutputNotSupported:
            return "Selected provider does not support structured summary output."
        case .localProviderNotRunning:
            return "Local provider is not running."
        case .normalizationFailed:
            return "Failed to normalize summary output."
        case .aggregationFailed:
            return "Failed to aggregate chunk summaries."
        }
    }

    var diagnostics: String {
        switch self {
        case let .invalidSummaryRequest(reason):
            return "invalid_summary_request=\(reason)"
        case .transcriptMissing:
            return "transcript_missing"
        case .transcriptTooLargeWithoutChunking:
            return "transcript_too_large_without_chunking"
        case let .providerUnavailable(provider):
            return "provider_unavailable=\(provider.rawValue)"
        case let .modelUnavailable(provider, modelID):
            return "model_unavailable provider=\(provider.rawValue) model=\(modelID)"
        case let .apiKeyMissing(provider):
            return "api_key_missing provider=\(provider.rawValue)"
        case let .requestFailed(provider, details):
            return "request_failed provider=\(provider.rawValue) details=\(details)"
        case let .responseDecodeFailed(provider, details):
            return "response_decode_failed provider=\(provider.rawValue) details=\(details)"
        case let .structuredOutputNotSupported(provider):
            return "structured_output_not_supported provider=\(provider.rawValue)"
        case let .localProviderNotRunning(provider):
            return "local_provider_not_running provider=\(provider.rawValue)"
        case let .normalizationFailed(details):
            return "normalization_failed details=\(details)"
        case let .aggregationFailed(details):
            return "aggregation_failed details=\(details)"
        }
    }
}
