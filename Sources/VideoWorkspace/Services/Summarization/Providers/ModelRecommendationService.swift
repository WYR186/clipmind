import Foundation

struct ModelRecommendationService {
    private let modelDiscovery: any ModelDiscoveryServiceProtocol

    init(modelDiscovery: any ModelDiscoveryServiceProtocol) {
        self.modelDiscovery = modelDiscovery
    }

    func recommendations(for provider: ProviderType) async throws -> [ModelRecommendation] {
        let models = try await modelDiscovery.discoverModels(for: provider)
        return models.map { model in
            let reasons = model.tags.isEmpty ? model.capabilities.capabilityTags : model.tags
            return ModelRecommendation(provider: provider, modelID: model.id, reasons: reasons)
        }
    }

    func bestModel(
        for provider: ProviderType,
        preferredTags: [ModelCapabilityTag]
    ) async throws -> ModelRecommendation? {
        let candidates = try await recommendations(for: provider)
        guard !candidates.isEmpty else { return nil }

        let scored = candidates.map { recommendation in
            let score = Set(recommendation.reasons).intersection(preferredTags).count
            return (recommendation, score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.modelID < rhs.0.modelID
                }
                return lhs.1 > rhs.1
            }
            .first?
            .0
    }
}
