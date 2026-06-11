import Foundation
import PencilKit
import UIKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case png
    case jpeg

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        switch self {
        case .pdf: "pdf"
        case .png: "png"
        case .jpeg: "jpg"
        }
    }
}

enum ExportService {
    static func exportPage(
        drawing: PKDrawing,
        shapes: [CanvasShape],
        backgroundImage: UIImage?,
        metadata: NotebookMetadata,
        pageIndex: Int,
        canvasSize: CGSize,
        format: ExportFormat
    ) async throws -> URL {
        let exportFolder = FileManager.default.temporaryDirectory.appendingPathComponent("UNoteExports", isDirectory: true)
        try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)

        let sanitizedName = metadata.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "\(sanitizedName)-page-\(pageIndex + 1).\(format.fileExtension)"
        let outputURL = exportFolder.appendingPathComponent(fileName)
        let pageSize = metadata.effectivePageSize ?? canvasSize
        let screenScale = await MainActor.run { UIScreen.main.scale }

        let data: Data
        switch format {
        case .pdf:
            if metadata.renderingMode == .vector {
                data = await Task.detached(priority: .background) {
                    VectorPDFRenderer.pdfData(
                        drawing: drawing,
                        shapes: shapes,
                        backgroundImage: backgroundImage,
                        canvasSize: pageSize
                    )
                }.value
            } else {
                data = await Task.detached(priority: .background) {
                    let image = RasterPageRenderer.renderImage(
                        drawing: drawing,
                        shapes: shapes,
                        backgroundImage: backgroundImage,
                        canvasSize: pageSize,
                        scale: screenScale,
                        opaqueBackground: true
                    )
                    return Self.rasterPDFData(image: image, pageSize: pageSize)
                }.value
            }
        case .png:
            data = await Task.detached(priority: .background) {
                RasterPageRenderer.renderImage(
                    drawing: drawing,
                    shapes: shapes,
                    backgroundImage: backgroundImage,
                    canvasSize: pageSize,
                    scale: screenScale,
                    opaqueBackground: false
                ).pngData() ?? Data()
            }.value
        case .jpeg:
            data = await Task.detached(priority: .background) {
                RasterPageRenderer.renderImage(
                    drawing: drawing,
                    shapes: shapes,
                    backgroundImage: backgroundImage,
                    canvasSize: pageSize,
                    scale: screenScale,
                    opaqueBackground: true
                ).jpegData(compressionQuality: metadata.renderingMode == .raster ? 0.72 : 0.9) ?? Data()
            }.value
        }

        try await CoordinatedFileWriter.write(data, to: outputURL)
        return outputURL
    }

    private static func rasterPDFData(image: UIImage, pageSize: CGSize) -> Data {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        return renderer.pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
    }
}
