import Combine
import Foundation
import PencilKit
import UIKit

struct ExportedDocument: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class NotebookEditorViewModel: ObservableObject {
    @Published var metadata: NotebookMetadata
    @Published var drawing = PKDrawing()
    @Published var shapes: [CanvasShape] = []
    @Published var backgroundImage: UIImage?
    @Published var currentPageIndex = 0
    @Published var isLoaded = false
    @Published var exportedDocument: ExportedDocument?
    @Published var errorMessage: String?
    @Published private var infiniteCanvasHeight: CGFloat = 2_400

    private let store: NotebookStore
    private var autosave: AutosaveCoordinator?
    private var lastStrokeCount = 0
    private var isApplyingLoadedPage = false
    private var currentCanvasSize = CGSize(width: 1_024, height: 1_800)

    init(metadata: NotebookMetadata, store: NotebookStore) {
        self.metadata = metadata
        self.store = store
        autosave = AutosaveCoordinator { [weak self] in
            await self?.saveCurrentPage()
        }
    }

    func load() async {
        guard !isLoaded else { return }
        await loadPage(index: currentPageIndex)
        isLoaded = true
    }

    func canvasSize(in availableSize: CGSize) -> CGSize {
        if let pageSize = metadata.effectivePageSize {
            return pageSize
        }

        return CGSize(
            width: max(availableSize.width, 1_024),
            height: max(availableSize.height * 2.2, infiniteCanvasHeight)
        )
    }

    func updateCanvasSize(_ size: CGSize) {
        currentCanvasSize = size
    }

    func extendInfiniteCanvasIfNeeded() {
        guard metadata.pageMode == .infiniteCanvas else { return }
        infiniteCanvasHeight += 1_600
        currentCanvasSize.height = infiniteCanvasHeight
    }

    func drawingDidChange(_ newDrawing: PKDrawing) {
        guard !isApplyingLoadedPage else { return }

        var updatedDrawing = newDrawing
        if metadata.autoShapeRecognitionEnabled,
           newDrawing.strokes.count > lastStrokeCount,
           let recognition = ShapeRecognizer.recognizeLastStroke(in: newDrawing) {
            updatedDrawing = recognition.drawingWithoutRecognizedStroke
            shapes.append(recognition.shape)
        }

        drawing = updatedDrawing
        lastStrokeCount = drawing.strokes.count
        autosave?.contentDidChange()
    }

    func shapesDidChange() {
        autosave?.contentDidChange()
    }

    func insertShape(_ kind: ShapeKind) {
        insertShape(
            kind,
            at: CGPoint(x: currentCanvasSize.width / 2, y: min(currentCanvasSize.height / 2, 520))
        )
    }

    func insertShape(_ kind: ShapeKind, at location: CGPoint) {
        ShapeLibrary.insert(
            kind: kind,
            into: &shapes,
            at: location,
            constrainedTo: currentCanvasSize
        )
        autosave?.contentDidChange()
    }

    func toggleAutoShapeRecognition() {
        metadata.autoShapeRecognitionEnabled.toggle()
        Task {
            do {
                try await store.updateMetadata(metadata)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func switchPage(to index: Int) async {
        guard metadata.pageMode == .standardPages,
              index != currentPageIndex,
              index >= 0,
              index < metadata.pageCount
        else { return }

        await saveImmediately()
        currentPageIndex = index
        await loadPage(index: index)
    }

    func addPage() async {
        guard metadata.pageMode == .standardPages else { return }

        await saveImmediately()
        do {
            metadata = try await store.addPage(to: metadata)
            currentPageIndex = metadata.pageCount - 1
            await loadPage(index: currentPageIndex)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importBackground(from url: URL) async {
        do {
            let image = try await ImportService.backgroundImage(from: url, targetSize: currentCanvasSize)
            backgroundImage = image
            try await store.saveBackgroundImage(image, metadata: metadata, pageIndex: currentPageIndex)
            autosave?.contentDidChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func export(format: ExportFormat) async {
        await saveImmediately()

        do {
            let url = try await ExportService.exportPage(
                drawing: drawing,
                shapes: shapes,
                backgroundImage: backgroundImage,
                metadata: metadata,
                pageIndex: currentPageIndex,
                canvasSize: currentCanvasSize,
                format: format
            )
            exportedDocument = ExportedDocument(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveImmediately() async {
        await autosave?.saveImmediately()
    }

    func saveCurrentPage() async {
        var updatedMetadata = metadata
        updatedMetadata.lastModifiedDate = Date()
        metadata = updatedMetadata

        do {
            try await store.savePage(
                metadata: updatedMetadata,
                drawing: drawing,
                shapes: shapes,
                backgroundImage: backgroundImage,
                pageIndex: currentPageIndex,
                canvasSize: currentCanvasSize
            )
            try await store.updateMetadata(updatedMetadata)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func thumbnailURL(for pageIndex: Int) -> URL {
        store.thumbnailURL(for: metadata, pageIndex: pageIndex)
    }

    private func loadPage(index: Int) async {
        isApplyingLoadedPage = true
        defer { isApplyingLoadedPage = false }

        do {
            drawing = try store.loadDrawing(metadata: metadata, pageIndex: index)
            shapes = try store.loadShapes(metadata: metadata, pageIndex: index)
            backgroundImage = store.loadBackgroundImage(metadata: metadata, pageIndex: index)
            lastStrokeCount = drawing.strokes.count
            ensureInfiniteCanvasCoversContent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureInfiniteCanvasCoversContent() {
        guard metadata.pageMode == .infiniteCanvas else { return }

        let drawingMaxY = drawing.bounds.isNull ? 0 : drawing.bounds.maxY
        let shapeMaxY = shapes.map(\.boundingRect.maxY).max() ?? 0
        infiniteCanvasHeight = max(infiniteCanvasHeight, drawingMaxY + 900, shapeMaxY + 900)
    }
}
