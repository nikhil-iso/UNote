import Foundation
import PDFKit
import UniformTypeIdentifiers
import UIKit

enum ImportService {
    enum ImportError: Error {
        case unsupportedFile
        case couldNotReadImage
        case couldNotReadPDF
    }

    static func backgroundImage(from url: URL, targetSize: CGSize) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            let needsSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if needsSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "pdf" {
                return try renderFirstPDFPage(url: url, targetSize: targetSize)
            }

            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data)
            else {
                throw ImportError.couldNotReadImage
            }

            return image
        }.value
    }

    private static func renderFirstPDFPage(url: URL, targetSize: CGSize) throws -> UIImage {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0)
        else {
            throw ImportError.couldNotReadPDF
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            let pageBounds = page.bounds(for: .mediaBox)
            let scale = min(targetSize.width / pageBounds.width, targetSize.height / pageBounds.height)
            let drawSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
            let origin = CGPoint(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2
            )

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: origin.x, y: origin.y + drawSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }
}
