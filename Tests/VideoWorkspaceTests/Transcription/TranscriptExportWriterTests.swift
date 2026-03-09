import XCTest
@testable import VideoWorkspace

final class TranscriptExportWriterTests: XCTestCase {
    func testWriteArtifactsCreatesTxtSrtVtt() throws {
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("export-source-\(UUID().uuidString).mp4")
        let outputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("export-out-\(UUID().uuidString)")

        try Data("src".utf8).write(to: sourceURL)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let request = TranscriptionRequest(
            taskID: UUID(),
            sourcePath: sourceURL.path,
            sourceType: .localFile,
            backend: .whisperCPP,
            modelIdentifier: "base",
            outputKinds: [.txt, .srt, .vtt],
            languageHint: "en",
            promptHint: nil,
            temperature: nil,
            outputDirectory: outputDirectory.path,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: false,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: nil
        )

        let segments = [
            TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 1.2, text: "hello")
        ]

        let writer = TranscriptExportWriter()
        let artifacts = try writer.write(request: request, transcriptText: "hello", segments: segments)

        XCTAssertEqual(artifacts.count, 3)
        XCTAssertTrue(artifacts.contains { $0.kind == .txt && FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertTrue(artifacts.contains { $0.kind == .srt && FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertTrue(artifacts.contains { $0.kind == .vtt && FileManager.default.fileExists(atPath: $0.path) })
    }
}
