import XCTest
@testable import VideoWorkspace

final class OpenAITranscriptionRequestBuilderTests: XCTestCase {
    func testBuildMultipartRequestIncludesModelAndFile() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("openai-builder-\(UUID().uuidString).wav")
        try Data("audio".utf8).write(to: tempFile)

        let request = TranscriptionRequest(
            taskID: UUID(),
            sourcePath: tempFile.path,
            sourceType: .localFile,
            backend: .openAI,
            modelIdentifier: "gpt-4o-mini-transcribe",
            outputKinds: [.txt],
            languageHint: "en",
            promptHint: "technical lecture",
            temperature: 0.2,
            outputDirectory: nil,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: true,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: nil
        )

        let builder = OpenAITranscriptionRequestBuilder()
        let built = try builder.build(request: request, fileURL: tempFile, apiKey: "test-key")

        XCTAssertEqual(built.urlRequest.httpMethod, "POST")
        XCTAssertEqual(built.urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

        let bodyString = String(data: built.body, encoding: .utf8) ?? ""
        XCTAssertTrue(bodyString.contains("name=\"model\""))
        XCTAssertTrue(bodyString.contains("gpt-4o-mini-transcribe"))
        XCTAssertTrue(bodyString.contains("name=\"language\""))
        XCTAssertTrue(bodyString.contains("name=\"prompt\""))
        XCTAssertTrue(bodyString.contains("name=\"temperature\""))
        XCTAssertTrue(bodyString.contains("name=\"file\""))
    }
}
