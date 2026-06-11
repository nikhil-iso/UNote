import CoreGraphics
import UIKit

enum ShapeRenderer {
    static func draw(_ shape: CanvasShape, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        let center = shape.center.cgPoint
        let size = shape.size.cgSize
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)

        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(shape.rotationDegrees * .pi / 180))
        context.setLineWidth(CGFloat(shape.lineWidth))
        context.setLineJoin(.round)
        context.setLineCap(.round)

        if let fillHex = shape.fillColorHex {
            context.setFillColor(UIColor(hex: fillHex).cgColor)
        }
        context.setStrokeColor(UIColor(hex: shape.strokeColorHex).cgColor)

        switch shape.kind {
        case .line:
            context.move(to: CGPoint(x: rect.minX, y: 0))
            context.addLine(to: CGPoint(x: rect.maxX, y: 0))
            context.strokePath()
        case .arrow:
            drawArrow(in: rect, context: context)
        default:
            let path = path(for: shape.kind, in: rect)
            if shape.fillColorHex != nil {
                context.addPath(path)
                context.fillPath()
            }
            context.addPath(path)
            context.strokePath()
        }
    }

    static func path(for kind: ShapeKind, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        switch kind {
        case .circle:
            path.addEllipse(in: rect)
        case .square, .rectangle:
            path.addRoundedRect(in: rect, cornerWidth: 2, cornerHeight: 2)
        case .triangle:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .star:
            addStar(to: path, in: rect)
        case .line, .arrow:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        return path
    }

    private static func drawArrow(in rect: CGRect, context: CGContext) {
        let headLength = min(rect.width * 0.18, 34)
        let halfHeadHeight = min(rect.height * 0.38, 18)
        let start = CGPoint(x: rect.minX, y: 0)
        let end = CGPoint(x: rect.maxX, y: 0)

        context.move(to: start)
        context.addLine(to: end)
        context.move(to: end)
        context.addLine(to: CGPoint(x: rect.maxX - headLength, y: -halfHeadHeight))
        context.move(to: end)
        context.addLine(to: CGPoint(x: rect.maxX - headLength, y: halfHeadHeight))
        context.strokePath()
    }

    private static func addStar(to path: CGMutablePath, in rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.45
        let points = 10

        for index in 0..<points {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) * .pi / CGFloat(points / 2) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
    }
}
