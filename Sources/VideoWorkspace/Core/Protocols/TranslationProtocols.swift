import Foundation

public protocol TranslationServiceProtocol: Sendable {
    func translate(
        request: TranslationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranslationResult
}

public protocol TranslationProviderProtocol: Sendable {
    var providerType: ProviderType { get }
    func translate(request: TranslationRequest, prompt: String) async throws -> String
}

public extension TranslationServiceProtocol {
    func translate(request: TranslationRequest) async throws -> TranslationResult {
        try await translate(request: request, progressHandler: nil)
    }
}
