import Foundation
import XCTest
@testable import VideoWorkspace

final class OpenAITranscriptionLiveTests: XCTestCase {
    func testLiveTranscribeLocalVideoViaProjectAPI() async throws {
        let env = ProcessInfo.processInfo.environment
        let sourcePath = env["VIDEO_TRANSCRIBE_PATH"]
            ?? "/Users/ipanda/Downloads/Human_+_AI__The_New_Romance_.mp4"

        guard FileManager.default.fileExists(atPath: sourcePath) else {
            throw XCTSkip("Missing source video at path: \(sourcePath)")
        }

        let secretsStore = LiveOpenAISecretsStore()
        let hasKey = try await secretsStore.hasSecret(for: ProviderType.openAI.rawValue)
        guard hasKey else {
            throw XCTSkip("OpenAI key not found. Set OPENAI_API_KEY or configure app keychain secret first.")
        }

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("videoworkspace-live-transcripts", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let preprocessing = AudioPreprocessingService(
            commandExecutor: ProcessCommandExecutor(),
            toolLocator: ExternalToolLocator(),
            logger: ConsoleLogger()
        )

        let service = OpenAITranscriptionService(
            preprocessor: preprocessing,
            secretsStore: secretsStore,
            logger: ConsoleLogger()
        )

        let request = TranscriptionRequest(
            taskID: UUID(),
            sourcePath: sourcePath,
            sourceType: .localFile,
            backend: .openAI,
            modelIdentifier: env["OPENAI_TRANSCRIBE_MODEL"] ?? "gpt-4o-mini-transcribe",
            outputKinds: [.txt],
            languageHint: env["OPENAI_TRANSCRIBE_LANGUAGE"],
            promptHint: nil,
            temperature: nil,
            outputDirectory: outputDirectory.path,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: true,
            debugDiagnosticsEnabled: true,
            whisperExecutablePath: nil,
            whisperModelPath: nil
        )

        let result = try await service.transcribe(
            request: request,
            progressHandler: { progress in
                print("LIVE_TRANSCRIBE_PROGRESS=\(Int(progress.fractionCompleted * 100))%\t\(progress.currentStep)")
            }
        )

        XCTAssertFalse(result.transcript.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(result.artifacts.isEmpty)

        let artifactPath = result.artifacts.first?.path ?? "<none>"
        let preview = result.transcript.content
            .prefix(160)
            .replacingOccurrences(of: "\n", with: " ")

        print("LIVE_TRANSCRIBE_SOURCE=\(sourcePath)")
        print("LIVE_TRANSCRIBE_ARTIFACT=\(artifactPath)")
        print("LIVE_TRANSCRIBE_MODEL=\(result.modelUsed)")
        print("LIVE_TRANSCRIBE_LANG=\(result.detectedLanguage ?? "unknown")")
        print("LIVE_TRANSCRIBE_PREVIEW=\(preview)")
    }
}

private actor LiveOpenAISecretsStore: SecretsStoreProtocol {
    private let keychain = KeychainSecretsStore()
    private let env = ProcessInfo.processInfo.environment

    func setSecret(_ secret: String, for key: String) async throws {
        try await keychain.setSecret(secret, for: key)
    }

    func getSecret(for key: String) async throws -> String? {
        if key == ProviderType.openAI.rawValue {
            if let envValue = env["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !envValue.isEmpty {
                return envValue
            }

            if let envValue = env["VIDEO_WORKSPACE_OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !envValue.isEmpty {
                return envValue
            }
        }

        return try await keychain.getSecret(for: key)
    }

    func removeSecret(for key: String) async throws {
        try await keychain.removeSecret(for: key)
    }
}
