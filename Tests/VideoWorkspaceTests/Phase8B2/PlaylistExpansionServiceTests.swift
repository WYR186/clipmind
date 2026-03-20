import XCTest
@testable import VideoWorkspace

final class PlaylistExpansionServiceTests: XCTestCase {
    func testExpandPlaylistParsesEntriesAndFiltersUnavailableAndDuplicates() async throws {
        let service = PlaylistExpansionService(
            commandExecutor: StubCommandExecutor(
                result: CommandExecutionResult(
                    executablePath: "/opt/homebrew/bin/yt-dlp",
                    arguments: [],
                    exitCode: 0,
                    stdout: playlistFixture,
                    stderr: "",
                    durationMs: 15
                )
            ),
            toolLocator: StubToolLocator(path: "/opt/homebrew/bin/yt-dlp"),
            logger: ConsoleLogger()
        )

        let result = try await service.expandPlaylist(
            url: "https://www.youtube.com/playlist?list=PL123",
            deduplicationPolicy: .normalizedURL,
            selectionDefault: .selectAllValid
        )

        XCTAssertEqual(result.sourceKind, .playlistURL)
        XCTAssertEqual(result.playlistMetadata?.title, "Study Playlist")
        XCTAssertEqual(result.expandedItems.count, 2)
        XCTAssertEqual(result.skippedItems.count, 4)
        XCTAssertEqual(result.selectedCount, 2)
        XCTAssertEqual(result.status, .partial)
        XCTAssertTrue(result.expandedItems.allSatisfy(\.isSelected))
    }

    func testExpandPlaylistThrowsForNonPlaylistPayload() async {
        let service = PlaylistExpansionService(
            commandExecutor: StubCommandExecutor(
                result: CommandExecutionResult(
                    executablePath: "/opt/homebrew/bin/yt-dlp",
                    arguments: [],
                    exitCode: 0,
                    stdout: "{\"title\":\"Single Video\",\"entries\":[]}",
                    stderr: "",
                    durationMs: 5
                )
            ),
            toolLocator: StubToolLocator(path: "/opt/homebrew/bin/yt-dlp"),
            logger: ConsoleLogger()
        )

        do {
            _ = try await service.expandPlaylist(
                url: "https://www.youtube.com/watch?v=abc",
                deduplicationPolicy: .normalizedURL,
                selectionDefault: .selectAllValid
            )
            XCTFail("Expected playlist expansion to fail")
        } catch {
            guard case SourceExpansionError.playlistNotDetected = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

private let playlistFixture = """
{
  "id": "PL123",
  "title": "Study Playlist",
  "extractor": "youtube:playlist",
  "extractor_key": "YoutubeTab",
  "webpage_url": "https://www.youtube.com/playlist?list=PL123",
  "playlist_count": 6,
  "entries": [
    {
      "id": "abc111",
      "title": "Entry 1",
      "webpage_url": "https://www.youtube.com/watch?v=abc111",
      "duration": 120,
      "playlist_index": 1,
      "availability": "public"
    },
    {
      "id": "abc111",
      "title": "Entry 1 Duplicate",
      "webpage_url": "https://www.youtube.com/watch?v=abc111",
      "duration": 121,
      "playlist_index": 2,
      "availability": "public"
    },
    {
      "id": "private1",
      "title": "Private Entry",
      "webpage_url": "https://www.youtube.com/watch?v=private1",
      "playlist_index": 3,
      "availability": "private"
    },
    {
      "id": "broken1",
      "title": "Broken Entry",
      "playlist_index": 4,
      "availability": "public"
    },
    null,
    {
      "id": "abc999",
      "title": "ID-only Entry",
      "url": "abc999",
      "duration": 88,
      "playlist_index": 6,
      "availability": "public"
    }
  ]
}
"""

private struct StubToolLocator: ExternalToolLocating {
    let path: String

    func locate(_ toolName: String) throws -> String {
        _ = toolName
        return path
    }
}

private struct StubCommandExecutor: CommandExecuting {
    let result: CommandExecutionResult

    func executeStreaming(
        executable: String,
        arguments: [String],
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> CommandExecutionResult {
        _ = executable
        _ = arguments
        _ = onOutputLine
        return result
    }
}
