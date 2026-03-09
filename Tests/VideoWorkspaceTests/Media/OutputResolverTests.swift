import XCTest
@testable import VideoWorkspace

final class OutputResolverTests: XCTestCase {
    func testPrepareOutputCreatesDirectory() throws {
        let resolver = DownloadOutputResolver()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("vw-output-\(UUID().uuidString)")

        let request = MediaDownloadRequest(
            source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
            kind: .video,
            metadataTitle: "Sample",
            outputDirectory: tempDirectory.path,
            overwritePolicy: .renameIfNeeded
        )

        let prepared = try resolver.prepareOutput(request: request, metadata: nil)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: prepared.directoryURL.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(prepared.outputTemplatePath.contains("%(ext)s"))
    }

    func testResolveFinalOutputPathByScan() throws {
        let resolver = DownloadOutputResolver()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("vw-output-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let prepared = PreparedDownloadOutput(
            directoryURL: tempDirectory,
            baseFileName: "sample-video",
            outputTemplatePath: tempDirectory.appendingPathComponent("sample-video.%(ext)s").path
        )

        let file = tempDirectory.appendingPathComponent("sample-video.mp4")
        FileManager.default.createFile(atPath: file.path, contents: Data("ok".utf8))

        let resolved = resolver.resolveFinalOutputPath(prepared: prepared, preferredPath: nil)
        XCTAssertEqual(resolved, file.path)
    }
}
