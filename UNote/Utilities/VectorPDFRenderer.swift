import PencilKit
import UIKit

enum VectorPDFRenderer {
    static func pdfData(
        drawing: PKDrawing,
        shapes: [CanvasShape],
        backgroundImage: UIImage?,
        canvasSize: CGSize
    ) -> Data {
        let bounds = CGRect(origin: .zero, size: canvasSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { context in
            context.beginPage()

            if let backgroundImage {
                backgroundImage.draw(in: bounds)
            } else {
                UIColor.white.setFill()
                context.cgContext.fill(bounds)
            }

            drawVectorStrokes(drawing.strokes, in: context.cgContext)

            for shape in shapes {
                ShapeRenderer.draw(shape, in: context.cgContext)
            }
        }
    }

    private static func drawVectorStrokes(_ strokes: [PKStroke], in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setLineJoin(.round)
        context.setLineCap(.round)

        for stroke in strokes {
            let points = stroke.path.map { $0 }
            guard points.count > 1 else { continue }

            let averageWidth = max(
                1,
                points.reduce(CGFloat(0)) { $0 + max($1.size.width, $1.size.height) } / CGFloat(points.count)
            )
            let isMarker = String(describing: stroke.ink.inkType).lowercased().contains("marker")
            let color = isMarker ? stroke.ink.color.withAlphaComponent(0.35) : stroke.ink.color

            context.setStrokeColor(color.cgColor)
            context.setLineWidth(averageWidth)
            context.beginPath()
            context.move(to: points[0].location)

            for point in points.dropFirst() {
                context.addLine(to: point.location)
            }

            context.strokePath()
        }
    }
}
