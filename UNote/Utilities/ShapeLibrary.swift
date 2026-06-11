import CoreGraphics
import Foundation

enum ShapeLibrary {
    static let defaultShapeSize = CGSize(width: 160, height: 120)

    @discardableResult
    static func insert(
        kind: ShapeKind,
        into shapes: inout [CanvasShape],
        at center: CGPoint,
        constrainedTo canvasSize: CGSize? = nil
    ) -> CanvasShape {
        let normalizedCenter: CGPoint
        if let canvasSize {
            normalizedCenter = CGPoint(
                x: min(max(center.x, 40), max(40, canvasSize.width - 40)),
                y: min(max(center.y, 40), max(40, canvasSize.height - 40))
            )
        } else {
            normalizedCenter = center
        }

        let size: CGSize
        switch kind {
        case .circle, .square, .star:
            size = CGSize(width: 120, height: 120)
        case .line, .arrow:
            size = CGSize(width: 180, height: 44)
        case .rectangle:
            size = CGSize(width: 180, height: 110)
        case .triangle:
            size = CGSize(width: 150, height: 130)
        }

        let shape = CanvasShape(kind: kind, center: normalizedCenter, size: size)
        shapes.append(shape)
        return shape
    }
}
