import Combine
import Foundation
import PencilKit
import UIKit

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notebooks: [NotebookSummary] = []

    let rootURL: URL

    init(rootURL: URL = NotebookStore.defaultRootURL()) {
        self.rootURL = rootURL
    }

    static func defaultRootURL() -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notebooks", isDirectory: true)
    }

    func refreshNotebooks() async {
        do {
            notebooks = try await loadNotebookSummaries()
        } catch {
            notebooks = []
        }
    }

    func createNotebook(
        name: String,
        pageMode: PageMode,
        standardSize: StandardPaperSize?,
        renderingMode: RenderingMode
    ) async throws -> NotebookSummary {
        let now = Date()
        let metadata = NotebookMetadata(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Notebook" : name,
            pageMode: pageMode,
            standardSize: pageMode == .standardPages ? (standardSize ?? .letter) : nil,
            creationDate: now,
            lastModifiedDate: now,
            renderingMode: renderingMode,
            pageCount: pageMode == .standardPages ? 1 : 1,
            autoShapeRecognitionEnabled: true
        )

        try createNotebookFolders(for: metadata)
        try await saveMetadata(metadata)
        try await savePage(
            metadata: metadata,
            drawing: PKDrawing(),
            shapes: [],
            backgroundImage: nil,
            pageIndex: 0,
            canvasSize: metadata.effectivePageSize ?? CGSize(width: 1_024, height: 1_800)
        )

        await refreshNotebooks()
        return NotebookSummary(
            metadata: metadata,
            folderURL: notebookURL(for: metadata),
            thumbnailURL: thumbnailURL(for: metadata, pageIndex: 0)
        )
    }

    func updateMetadata(_ metadata: NotebookMetadata) async throws {
        try await saveMetadata(metadata)
        await refreshNotebooks()
    }

    func addPage(to metadata: NotebookMetadata) async throws -> NotebookMetadata {
        guard metadata.pageMode == .standardPages else { return metadata }

        var updated = metadata
        updated.pageCount += 1
        updated.lastModifiedDate = Date()

        try await saveMetadata(updated)
        try await savePage(
            metadata: updated,
            drawing: PKDrawing(),
            shapes: [],
            backgroundImage: nil,
            pageIndex: updated.pageCount - 1,
            canvasSize: updated.effectivePageSize ?? CGSize(width: 612, height: 792)
        )

        await refreshNotebooks()
        return updated
    }

    func loadDrawing(metadata: NotebookMetadata, pageIndex: Int) throws -> PKDrawing {
        let url = drawingURL(for: metadata, pageIndex: pageIndex)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return PKDrawing()
        }
        return try PKDrawing(data: Data(contentsOf: url))
    }

    func loadShapes(metadata: NotebookMetadata, pageIndex: Int) throws -> [CanvasShape] {
        let url = shapesURL(for: metadata, pageIndex: pageIndex)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        return try JSONDecoder.unote.decode([CanvasShape].self, from: Data(contentsOf: url))
    }

    func loadBackgroundImage(metadata: NotebookMetadata, pageIndex: Int) -> UIImage? {
        UIImage(contentsOfFile: backgroundURL(for: metadata, pageIndex: pageIndex).path)
    }

    func savePage(
        metadata: NotebookMetadata,
        drawing: PKDrawing,
        shapes: [CanvasShape],
        backgroundImage: UIImage?,
        pageIndex: Int,
        canvasSize: CGSize
    ) async throws {
        let drawingURL = drawingURL(for: metadata, pageIndex: pageIndex)
        let shapesURL = shapesURL(for: metadata, pageIndex: pageIndex)
        let backgroundURL = backgroundURL(for: metadata, pageIndex: pageIndex)
        let thumbnailURL = thumbnailURL(for: metadata, pageIndex: pageIndex)
        let renderingMode = metadata.renderingMode

        let drawingData = await Task.detached(priority: .background) {
            drawing.dataRepresentation()
        }.value
        try await CoordinatedFileWriter.write(drawingData, to: drawingURL)

        let shapesData = try JSONEncoder.unote.encode(shapes)
        try await CoordinatedFileWriter.write(shapesData, to: shapesURL)

        if let backgroundImage, let pngData = backgroundImage.pngData() {
            try await CoordinatedFileWriter.write(pngData, to: backgroundURL)
        }

        let thumbnailData = try await Task.detached(priority: .background) {
            let thumbnail = RasterPageRenderer.renderImage(
                drawing: drawing,
                shapes: shapes,
                backgroundImage: backgroundImage,
                canvasSize: canvasSize,
                scale: 0.25,
                opaqueBackground: true
            )
            let compression: CGFloat = renderingMode == .raster ? 0.52 : 0.72
            return thumbnail.jpegData(compressionQuality: compression) ?? Data()
        }.value
        try await CoordinatedFileWriter.write(thumbnailData, to: thumbnailURL)
    }

    func saveBackgroundImage(_ image: UIImage, metadata: NotebookMetadata, pageIndex: Int) async throws {
        guard let data = image.pngData() else { return }
        try await CoordinatedFileWriter.write(data, to: backgroundURL(for: metadata, pageIndex: pageIndex))
    }

    func notebookURL(for metadata: NotebookMetadata) -> URL {
        notebookURL(for: metadata.id)
    }

    func notebookURL(for id: UUID) -> URL {
        rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func drawingURL(for metadata: NotebookMetadata, pageIndex: Int) -> URL {
        let pages = pagesURL(for: metadata)
        if metadata.pageMode == .infiniteCanvas {
            return pages.appendingPathComponent("drawing.data")
        }
            return pages.appendingPathComponent(pageFileName(pageIndex: pageIndex, fileExtension: "drawing"))
    }

    func shapesURL(for metadata: NotebookMetadata, pageIndex: Int) -> URL {
        let pages = pagesURL(for: metadata)
        if metadata.pageMode == .infiniteCanvas {
            return pages.appendingPathComponent("shapes.json")
        }
        return pages.appendingPathComponent(pageFileName(pageIndex: pageIndex, fileExtension: "shapes.json"))
    }

    func backgroundURL(for metadata: NotebookMetadata, pageIndex: Int) -> URL {
        let pages = pagesURL(for: metadata)
        if metadata.pageMode == .infiniteCanvas {
            return pages.appendingPathComponent("background.png")
        }
        return pages.appendingPathComponent(pageFileName(pageIndex: pageIndex, fileExtension: "background.png"))
    }

    func thumbnailURL(for metadata: NotebookMetadata, pageIndex: Int) -> URL {
        let folder = notebookURL(for: metadata).appendingPathComponent("thumbnails", isDirectory: true)
        if metadata.pageMode == .infiniteCanvas {
            return folder.appendingPathComponent("infinite.jpg")
        }
        return folder.appendingPathComponent(pageFileName(pageIndex: pageIndex, fileExtension: "jpg"))
    }

    private func loadNotebookSummaries() async throws -> [NotebookSummary] {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let folderURLs = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let summaries = folderURLs.compactMap { folderURL -> NotebookSummary? in
            let metadataURL = folderURL.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? JSONDecoder.unote.decode(NotebookMetadata.self, from: data)
            else {
                return nil
            }
            let thumbURL = thumbnailURL(for: metadata, pageIndex: 0)
            return NotebookSummary(
                metadata: metadata,
                folderURL: folderURL,
                thumbnailURL: FileManager.default.fileExists(atPath: thumbURL.path) ? thumbURL : nil
            )
        }

        return summaries.sorted { $0.metadata.lastModifiedDate > $1.metadata.lastModifiedDate }
    }

    private func createNotebookFolders(for metadata: NotebookMetadata) throws {
        try FileManager.default.createDirectory(at: notebookURL(for: metadata), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pagesURL(for: metadata), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: notebookURL(for: metadata).appendingPathComponent("thumbnails", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    private func saveMetadata(_ metadata: NotebookMetadata) async throws {
        try createNotebookFolders(for: metadata)
        let data = try JSONEncoder.unote.encode(metadata)
        try await CoordinatedFileWriter.write(data, to: notebookURL(for: metadata).appendingPathComponent("metadata.json"))
    }

    private func pagesURL(for metadata: NotebookMetadata) -> URL {
        notebookURL(for: metadata).appendingPathComponent("pages", isDirectory: true)
    }

    private func pageFileName(pageIndex: Int, fileExtension: String) -> String {
        let oneBasedIndex = pageIndex + 1
        return "page-\(String(format: "%04d", oneBasedIndex)).\(fileExtension)"
    }
}
