import XCTest
@testable import VideoWorkspace

@MainActor
final class MockFlowSmokeTests: XCTestCase {
    func testOnlineInspectAndTaskCreation() async {
        let env = AppEnvironment.mock()
        let vm = OnlineVideoViewModel(environment: env)

        vm.urlInput = MockSamples.onlineURL
        vm.inspect()

        for _ in 0..<20 where vm.metadata == nil {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTAssertNotNil(vm.metadata)

        vm.copyTranscript()
        try? await Task.sleep(nanoseconds: 2_200_000_000)

        let tasks = await env.taskRepository.allTasks()
        XCTAssertFalse(tasks.isEmpty)
    }
}
