import PencilKit
import UIKit

enum RasterPageRenderer {
    static func renderImage(
        drawing: PKDrawing,
        shapes: [CanvasShape],
        backgroundImage: UIImage?,
        canvasSize: CGSize,
        scale: CGFloat,
        opaqueBackground: Bool
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(scale, 0.1)
        format.opaque = opaqueBackground

        let bounds = CGRect(origin: .zero, size: canvasSize)
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { rendererContext in
            if opaqueBackground {
                UIColor.white.setFill()
                rendererContext.fill(bounds)
            }

            backgroundImage?.draw(in: bounds)

            let drawingImage = drawing.image(from: bounds, scale: max(scale, 0.1))
            drawingImage.draw(in: bounds)

            for shape in shapes {
                ShapeRenderer.draw(shape, in: rendererContext.cgContext)
            }
        }
    }
}
