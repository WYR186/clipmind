import XCTest
@testable import VideoWorkspace

final class ReleaseModeBehaviorTests: XCTestCase {
    func testRuntimeModeFlags() {
        XCTAssertTrue(AppRuntimeMode.debug.allowsMockFallback)
        XCTAssertFalse(AppRuntimeMode.release.allowsMockFallback)
    }

    func testMockEnvironmentReflectsRuntimeModeFallbackBoundary() {
        let debugEnv = AppEnvironment.mock(runtimeMode: .debug)
        XCTAssertEqual(debugEnv.runtimeMode, .debug)
        XCTAssertTrue(debugEnv.allowInspectionFallbackToMock)
        XCTAssertTrue(debugEnv.allowTranscriptionFallbackToMock)

        let releaseEnv = AppEnvironment.mock(runtimeMode: .release)
        XCTAssertEqual(releaseEnv.runtimeMode, .release)
        XCTAssertFalse(releaseEnv.allowInspectionFallbackToMock)
        XCTAssertFalse(releaseEnv.allowTranscriptionFallbackToMock)
    }
}
