import CoreGraphics
import Foundation
import PencilKit

struct ShapeRecognitionResult {
    var drawingWithoutRecognizedStroke: PKDrawing
    var shape: CanvasShape
}

enum ShapeRecognizer {
    static func recognizeLastStroke(in drawing: PKDrawing) -> ShapeRecognitionResult? {
        let strokes = drawing.strokes
        guard let lastStroke = strokes.last else { return nil }

        let points = lastStroke.path.map(\.location)
        guard points.count >= 5 else { return nil }

        let bounds = boundingRect(for: points).insetBy(dx: -2, dy: -2)
        let diagonal = max(hypot(bounds.width, bounds.height), 1)
        guard bounds.width > 16 || bounds.height > 16 else { return nil }

        let simplified = sample(points: points, targetCount: 32)
        let lineError = averageDistanceFromLine(points: points) / diagonal

        let recognizedKind: ShapeKind?
        if lineError < 0.045 {
            recognizedKind = looksLikeArrow(points: simplified) ? .arrow : .line
        } else if isClosed(points: points, tolerance: diagonal * 0.22) {
            let corners = cornerCount(points: simplified)
            let aspect = bounds.width / max(bounds.height, 1)
            if corners <= 2, aspect > 0.72, aspect < 1.28 {
                recognizedKind = .circle
            } else if corners <= 3 {
                recognizedKind = .triangle
            } else if aspect > 0.82, aspect < 1.18 {
                recognizedKind = .square
            } else {
                recognizedKind = .rectangle
            }
        } else {
            recognizedKind = nil
        }

        guard let kind = recognizedKind else { return nil }

        let normalizedSize: CGSize
        if kind == .line || kind == .arrow {
            normalizedSize = CGSize(width: max(bounds.width, 44), height: 44)
        } else if kind == .circle || kind == .square {
            let side = max(bounds.width, bounds.height)
            normalizedSize = CGSize(width: side, height: side)
        } else {
            normalizedSize = bounds.size
        }

        let shape = CanvasShape(
            kind: kind,
            center: CGPoint(x: bounds.midX, y: bounds.midY),
            size: normalizedSize,
            rotationDegrees: kind == .line || kind == .arrow ? lineAngle(points: points) : 0,
            strokeColorHex: "#111827",
            fillColorHex: nil,
            lineWidth: 3
        )

        return ShapeRecognitionResult(
            drawingWithoutRecognizedStroke: PKDrawing(strokes: Array(strokes.dropLast())),
            shape: shape
        )
    }

    private static func boundingRect(for points: [CGPoint]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func isClosed(points: [CGPoint], tolerance: CGFloat) -> Bool {
        guard let first = points.first, let last = points.last else { return false }
        return hypot(first.x - last.x, first.y - last.y) <= tolerance
    }

    private static func sample(points: [CGPoint], targetCount: Int) -> [CGPoint] {
        guard points.count > targetCount, targetCount > 1 else { return points }
        return (0..<targetCount).map { index in
            let sourceIndex = Int(round(Double(index) * Double(points.count - 1) / Double(targetCount - 1)))
            return points[sourceIndex]
        }
    }

    private static func averageDistanceFromLine(points: [CGPoint]) -> CGFloat {
        guard let first = points.first, let last = points.last else { return .greatestFiniteMagnitude }
        let length = max(hypot(last.x - first.x, last.y - first.y), 1)
        let total = points.reduce(CGFloat(0)) { partial, point in
            let numerator = abs((last.y - first.y) * point.x - (last.x - first.x) * point.y + last.x * first.y - last.y * first.x)
            return partial + numerator / length
        }
        return total / CGFloat(points.count)
    }

    private static func cornerCount(points: [CGPoint]) -> Int {
        guard points.count >= 3 else { return 0 }
        var corners = 0

        for index in 1..<(points.count - 1) {
            let previous = points[index - 1]
            let current = points[index]
            let next = points[index + 1]
            let firstAngle = atan2(current.y - previous.y, current.x - previous.x)
            let secondAngle = atan2(next.y - current.y, next.x - current.x)
            let delta = abs(normalizedAngle(secondAngle - firstAngle))
            if delta > CGFloat.pi / 3 {
                corners += 1
            }
        }

        return corners
    }

    private static func looksLikeArrow(points: [CGPoint]) -> Bool {
        guard points.count >= 6 else { return false }
        let tail = points[0]
        let tip = points[points.count - 1]
        let mainAngle = atan2(tip.y - tail.y, tip.x - tail.x)
        let recent = points.suffix(max(3, points.count / 4))
        return recent.contains { point in
            let branchAngle = atan2(tip.y - point.y, tip.x - point.x)
            return abs(normalizedAngle(branchAngle - mainAngle)) > CGFloat.pi / 5
        }
    }

    private static func lineAngle(points: [CGPoint]) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        return Double(atan2(last.y - first.y, last.x - first.x)) * 180 / Double.pi
    }

    private static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var value = angle
        while value > CGFloat.pi { value -= 2 * CGFloat.pi }
        while value < -CGFloat.pi { value += 2 * CGFloat.pi }
        return value
    }
}
