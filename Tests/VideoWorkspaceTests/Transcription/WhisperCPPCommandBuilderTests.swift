import XCTest
@testable import VideoWorkspace

final class WhisperCPPCommandBuilderTests: XCTestCase {
    func testBuildArgumentsIncludesRequiredFlags() throws {
        let modelURL = FileManager.default.temporaryDirectory.appendingPathComponent("model-\(UUID().uuidString).bin")
        try Data("model".utf8).write(to: modelURL)

        let request = TranscriptionRequest(
            taskID: UUID(),
            sourcePath: "/tmp/input.mp4",
            sourceType: .localFile,
            backend: .whisperCPP,
            modelIdentifier: "base",
            outputKinds: [.txt, .srt, .vtt],
            languageHint: "en",
            promptHint: "meeting",
            temperature: 0.1,
            outputDirectory: nil,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: true,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: modelURL.path
        )

        let builder = WhisperCPPCommandBuilder()
        let args = try builder.buildArguments(
            request: request,
            inputAudioPath: "/tmp/input.wav",
            outputBasePath: "/tmp/output"
        )

        XCTAssertTrue(args.contains("-m"))
        XCTAssertTrue(args.contains(modelURL.path))
        XCTAssertTrue(args.contains("-f"))
        XCTAssertTrue(args.contains("/tmp/input.wav"))
        XCTAssertTrue(args.contains("-otxt"))
        XCTAssertTrue(args.contains("-osrt"))
        XCTAssertTrue(args.contains("-ovtt"))
    }
}
