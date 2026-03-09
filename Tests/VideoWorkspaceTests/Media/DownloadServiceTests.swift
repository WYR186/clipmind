import XCTest
@testable import VideoWorkspace

final class DownloadServiceTests: XCTestCase {
    func testDownloadSelectionValidation() throws {
        let metadata = MediaMetadata(
            source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
            title: "sample",
            durationSeconds: 1,
            thumbnailURL: nil,
            videoOptions: [VideoFormatOption(formatID: "137", qualityLabel: "1080p", container: "mp4")],
            audioOptions: [AudioFormatOption(formatID: "140", extensionName: "m4a", codec: "aac", bitrateKbps: 128)],
            subtitleTracks: [SubtitleTrack(languageCode: "en", languageName: "English", sourceType: .native)]
        )

        let selection = DownloadSelection(kind: .video, videoFormatID: "137", audioFormatID: nil, subtitleTrack: nil)
        XCTAssertNoThrow(try selection.validate(against: metadata))

        let invalid = DownloadSelection(kind: .subtitle, videoFormatID: nil, audioFormatID: nil, subtitleTrack: nil)
        XCTAssertThrowsError(try invalid.validate(against: metadata))
    }

    func testYTDLPDownloadServiceParsesProgressAndOutput() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("vw-download-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let service = YTDLPMediaDownloadService(
            commandExecutor: StubDownloadCommandExecutor(),
            toolLocator: StubDownloadToolLocator(path: "/usr/local/bin/yt-dlp"),
            logger: ConsoleLogger()
        )

        let request = MediaDownloadRequest(
            source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
            kind: .audioOnly,
            metadataTitle: "Sample",
            outputDirectory: tempDirectory.path
        )

        let collector = ProgressCollector()
        let result = try await service.download(request: request) { progress in
            collector.append(progress.fractionCompleted)
        }

        let values = collector.values()
        XCTAssertTrue(values.contains { $0 > 0 })
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputPath))
    }

    func testProgressParserParsesPercent() {
        let parser = DownloadProgressParser()
        let event = parser.parse(line: "[download]  42.1% of 200.00MiB at 1.0MiB/s ETA 00:10")
        XCTAssertNotNil(event?.progress)
        XCTAssertEqual(event?.progress?.fractionCompleted ?? 0, 0.421, accuracy: 0.01)
    }
}

private struct StubDownloadToolLocator: ExternalToolLocating {
    let path: String

    func locate(_ toolName: String) throws -> String {
        path
    }
}

private struct StubDownloadCommandExecutor: CommandExecuting {
    func executeStreaming(
        executable: String,
        arguments: [String],
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> CommandExecutionResult {
        guard let outputIndex = arguments.firstIndex(of: "-o"), arguments.indices.contains(outputIndex + 1) else {
            throw DownloadError.filenameResolutionFailed(reason: "Missing -o argument")
        }

        let templatePath = arguments[outputIndex + 1]
        let outputPath = templatePath.replacingOccurrences(of: "%(ext)s", with: "m4a")
        FileManager.default.createFile(atPath: outputPath, contents: Data("mock".utf8))

        onOutputLine?("[download] Destination: \(outputPath)")
        onOutputLine?("[download]  50.0% of 10.00MiB at 1.00MiB/s ETA 00:05")
        onOutputLine?("[download] 100.0% of 10.00MiB in 00:10")

        return CommandExecutionResult(
            executablePath: executable,
            arguments: arguments,
            exitCode: 0,
            stdout: "",
            stderr: "",
            durationMs: 100
        )
    }

    func execute(executable: String, arguments: [String]) async throws -> CommandExecutionResult {
        try await executeStreaming(executable: executable, arguments: arguments, onOutputLine: nil)
    }
}

private final class ProgressCollector: @unchecked Sendable {
    private var valuesStorage: [Double] = []
    private let lock = NSLock()

    func append(_ value: Double) {
        lock.lock()
        valuesStorage.append(value)
        lock.unlock()
    }

    func values() -> [Double] {
        lock.lock()
        defer { lock.unlock() }
        return valuesStorage
    }
}
