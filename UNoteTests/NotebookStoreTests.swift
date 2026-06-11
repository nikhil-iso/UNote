import PencilKit
import XCTest
@testable import UNote

final class NotebookStoreTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUp() {
        super.setUp()
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UNoteTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryRoot)
        temporaryRoot = nil
        super.tearDown()
    }

    @MainActor
    func testCreateStandardNotebookWritesMetadataAndFirstPage() async throws {
        let store = NotebookStore(rootURL: temporaryRoot)

        let summary = try await store.createNotebook(
            name: "Physics",
            pageMode: .standardPages,
            standardSize: .a4,
            renderingMode: .vector
        )

        XCTAssertEqual(summary.metadata.pageCount, 1)
        XCTAssertEqual(summary.metadata.standardSize, .a4)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.drawingURL(for: summary.metadata, pageIndex: 0).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.shapesURL(for: summary.metadata, pageIndex: 0).path))
    }

    @MainActor
    func testAddPageCreatesSecondPageArchive() async throws {
        let store = NotebookStore(rootURL: temporaryRoot)
        let summary = try await store.createNotebook(
            name: "Math",
            pageMode: .standardPages,
            standardSize: .letter,
            renderingMode: .raster
        )

        let updated = try await store.addPage(to: summary.metadata)

        XCTAssertEqual(updated.pageCount, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.drawingURL(for: updated, pageIndex: 1).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.thumbnailURL(for: updated, pageIndex: 1).path))
    }
}
