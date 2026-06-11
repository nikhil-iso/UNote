import XCTest
@testable import UNote

final class AutosaveCoordinatorTests: XCTestCase {
    @MainActor
    func testAutosaveRunsAfterDelay() async {
        let expectation = expectation(description: "Autosave fired")
        let coordinator = AutosaveCoordinator(delay: .milliseconds(40)) {
            expectation.fulfill()
        }

        coordinator.contentDidChange()

        await fulfillment(of: [expectation], timeout: 1)
    }

    @MainActor
    func testAutosaveDebouncesRepeatedChanges() async throws {
        var saveCount = 0
        let expectation = expectation(description: "Debounced autosave fired")
        let coordinator = AutosaveCoordinator(delay: .milliseconds(60)) {
            saveCount += 1
            expectation.fulfill()
        }

        coordinator.contentDidChange()
        try await Task.sleep(for: .milliseconds(20))
        coordinator.contentDidChange()
        try await Task.sleep(for: .milliseconds(20))
        coordinator.contentDidChange()

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(saveCount, 1)
    }
}
