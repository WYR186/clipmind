import Foundation

enum TranslationError: Error, Sendable {
    case invalidRequest(reason: String)
    case sourceTextMissing
    case providerUnavailable(ProviderType)
    case modelUnavailable(provider: ProviderType, modelID: String)
    case apiKeyMissing(provider: ProviderType)
    case requestFailed(provider: ProviderType, details: String)
    case responseDecodeFailed(provider: ProviderType, details: String)
    case subtitleStructureUnavailable(format: TranslationOutputFormat)
    case exportFailed(details: String)
}

extension TranslationError {
    var userMessage: String {
        switch self {
        case let .invalidRequest(reason):
            return reason
        case .sourceTextMissing:
            return "Transcript content is empty."
        case .providerUnavailable:
            return "Selected translation provider is unavailable."
        case .modelUnavailable:
            return "Selected translation model is unavailable."
        case .apiKeyMissing:
            return "API key is missing for translation provider."
        case .requestFailed:
            return "Translation request failed."
        case .responseDecodeFailed:
            return "Failed to parse translation output."
        case .subtitleStructureUnavailable:
            return "Subtitle timing structure is unavailable for subtitle export."
        case .exportFailed:
            return "Failed to export translated output files."
        }
    }

    var diagnostics: String {
        switch self {
        case let .invalidRequest(reason):
            return "invalid_translation_request=\(reason)"
        case .sourceTextMissing:
            return "translation_source_text_missing"
        case let .providerUnavailable(provider):
            return "translation_provider_unavailable=\(provider.rawValue)"
        case let .modelUnavailable(provider, modelID):
            return "translation_model_unavailable provider=\(provider.rawValue) model=\(modelID)"
        case let .apiKeyMissing(provider):
            return "translation_api_key_missing provider=\(provider.rawValue)"
        case let .requestFailed(provider, details):
            return "translation_request_failed provider=\(provider.rawValue) details=\(details)"
        case let .responseDecodeFailed(provider, details):
            return "translation_response_decode_failed provider=\(provider.rawValue) details=\(details)"
        case let .subtitleStructureUnavailable(format):
            return "translation_subtitle_structure_unavailable format=\(format.rawValue)"
        case let .exportFailed(details):
            return "translation_export_failed details=\(details)"
        }
    }
}
