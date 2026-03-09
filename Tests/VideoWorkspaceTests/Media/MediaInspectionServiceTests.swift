import XCTest
@testable import VideoWorkspace

final class MediaInspectionServiceTests: XCTestCase {
    func testCompositeRoutesBySourceType() async throws {
        let urlService = StubInspectionService(title: "url")
        let localService = StubInspectionService(title: "local")
        let composite = CompositeMediaInspectionService(
            urlInspectionService: urlService,
            localInspectionService: localService,
            fallbackInspectionService: nil,
            allowFallbackToMock: false,
            logger: ConsoleLogger()
        )

        let urlMetadata = try await composite.inspect(source: MediaSource(type: .url, value: "https://a"))
        let localMetadata = try await composite.inspect(source: MediaSource(type: .localFile, value: "/tmp/a.mp4"))

        XCTAssertEqual(urlMetadata.title, "url")
        XCTAssertEqual(localMetadata.title, "local")
    }

    func testCompositeFallbackToMockWhenToolMissing() async throws {
        let failing = FailingInspectionService(inspectionError: MediaInspectionError.external(.toolNotFound(tool: "yt-dlp", searchedPaths: [])))
        let fallback = StubInspectionService(title: "mock")
        let composite = CompositeMediaInspectionService(
            urlInspectionService: failing,
            localInspectionService: failing,
            fallbackInspectionService: fallback,
            allowFallbackToMock: true,
            logger: ConsoleLogger()
        )

        let metadata = try await composite.inspect(source: MediaSource(type: .url, value: "https://a"))
        XCTAssertEqual(metadata.title, "mock")
    }

    func testYTDLPServiceDecodeFailure() async {
        let service = YTDLPMediaInspectionService(
            commandExecutor: StubCommandExecutor(result: CommandExecutionResult(
                executablePath: "/usr/local/bin/yt-dlp",
                arguments: [],
                exitCode: 0,
                stdout: "{not-json}",
                stderr: "",
                durationMs: 10
            )),
            toolLocator: StubToolLocator(path: "/usr/local/bin/yt-dlp"),
            logger: ConsoleLogger()
        )

        do {
            _ = try await service.inspect(source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"))
            XCTFail("Expected decode failure")
        } catch let error as MediaInspectionError {
            guard case .external(.decodeFailed) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFFprobeServiceInvalidSource() async {
        let service = FFprobeMediaInspectionService(
            commandExecutor: StubCommandExecutor(result: CommandExecutionResult(
                executablePath: "/usr/bin/ffprobe",
                arguments: [],
                exitCode: 0,
                stdout: "{}",
                stderr: "",
                durationMs: 1
            )),
            toolLocator: StubToolLocator(path: "/usr/bin/ffprobe"),
            logger: ConsoleLogger()
        )

        do {
            _ = try await service.inspect(source: MediaSource(type: .localFile, value: "/path/not/exist.mp4"))
            XCTFail("Expected invalid source")
        } catch let error as MediaInspectionError {
            guard case .external(.invalidSource) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

private struct StubInspectionService: MediaInspectionServiceProtocol {
    let title: String

    func inspect(source: MediaSource) async throws -> MediaMetadata {
        MediaMetadata(
            source: source,
            title: title,
            durationSeconds: 1,
            thumbnailURL: nil,
            videoOptions: [],
            audioOptions: [],
            subtitleTracks: []
        )
    }
}

private struct FailingInspectionService: MediaInspectionServiceProtocol {
    let inspectionError: MediaInspectionError

    func inspect(source: MediaSource) async throws -> MediaMetadata {
        throw inspectionError
    }
}

private struct StubCommandExecutor: CommandExecuting {
    let result: CommandExecutionResult

    func executeStreaming(
        executable: String,
        arguments: [String],
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> CommandExecutionResult {
        result
    }

    func execute(executable: String, arguments: [String]) async throws -> CommandExecutionResult {
        result
    }
}

private struct StubToolLocator: ExternalToolLocating {
    let path: String

    func locate(_ toolName: String) throws -> String {
        path
    }
}
