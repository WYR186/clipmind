import XCTest
@testable import VideoWorkspace

final class TranscriptionRequestValidatorTests: XCTestCase {
    func testValidatePassesForLocalWhisperRequest() throws {
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("validator-src-\(UUID().uuidString).wav")
        let modelURL = FileManager.default.temporaryDirectory.appendingPathComponent("validator-model-\(UUID().uuidString).bin")

        try Data("audio".utf8).write(to: sourceURL)
        try Data("model".utf8).write(to: modelURL)

        let request = TranscriptionRequest(
            taskID: UUID(),
            sourcePath: sourceURL.path,
            sourceType: .localFile,
            backend: .whisperCPP,
            modelIdentifier: "base",
            outputKinds: [.txt],
            languageHint: "en",
            promptHint: nil,
            temperature: nil,
            outputDirectory: nil,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: true,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: modelURL.path
        )

        XCTAssertNoThrow(try TranscriptionRequestValidator().validate(request))
    }

    func testValidateRejectsURLSourceType() {
        let request = TranscriptionRequest(
            taskID: UUID(),
            sourcePath: "https://youtube.com/watch?v=abc",
            sourceType: .url,
            backend: .openAI,
            modelIdentifier: "gpt-4o-mini-transcribe",
            outputKinds: [.txt],
            languageHint: "en",
            promptHint: nil,
            temperature: nil,
            outputDirectory: nil,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: true,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: nil
        )

        XCTAssertThrowsError(try TranscriptionRequestValidator().validate(request))
    }
}
