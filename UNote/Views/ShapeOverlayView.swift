import SwiftUI

struct ShapeOverlayView: View {
    @Binding var shape: CanvasShape
    let canvasSize: CGSize
    let onFinishedEditing: () -> Void

    @State private var dragStart: CanvasPoint?
    @State private var resizeStart: CanvasSize?
    @State private var rotationStart: Double?
    @State private var magnificationStart: CanvasSize?

    var body: some View {
        shapeBody
            .frame(width: max(shape.size.width, 24), height: max(shape.size.height, 24))
            .rotationEffect(.degrees(shape.rotationDegrees))
            .position(shape.center.cgPoint)
            .contentShape(Rectangle())
            .gesture(moveGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(rotateGesture)
            .overlay(alignment: .bottomTrailing) {
                resizeHandle
            }
    }

    @ViewBuilder
    private var shapeBody: some View {
        let lineWidth = CGFloat(shape.lineWidth)
        let stroke = Color(hex: shape.strokeColorHex)
        let fill = shape.fillColorHex.map(Color.init(hex:)) ?? .clear

        switch shape.kind {
        case .circle:
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(stroke, lineWidth: lineWidth))
        case .square, .rectangle:
            Rectangle()
                .fill(fill)
                .overlay(Rectangle().stroke(stroke, lineWidth: lineWidth))
        case .triangle:
            TriangleShape()
                .fill(fill)
                .overlay(TriangleShape().stroke(stroke, lineWidth: lineWidth))
        case .line:
            LineShape(arrow: false)
                .stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        case .arrow:
            LineShape(arrow: true)
                .stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        case .star:
            StarShape()
                .fill(fill)
                .overlay(StarShape().stroke(stroke, lineWidth: lineWidth))
        }
    }

    private var resizeHandle: some View {
        Circle()
            .fill(.white)
            .stroke(.blue, lineWidth: 2)
            .frame(width: 18, height: 18)
            .offset(x: 9, y: 9)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if resizeStart == nil {
                            resizeStart = shape.size
                        }
                        let start = resizeStart?.cgSize ?? shape.size.cgSize
                        let width = max(32, start.width + value.translation.width * 2)
                        let height = max(32, start.height + value.translation.height * 2)
                        shape.size = CanvasSize(width: width, height: height)
                    }
                    .onEnded { _ in
                        resizeStart = nil
                        clampToCanvas()
                        onFinishedEditing()
                    }
            )
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil {
                    dragStart = shape.center
                }
                let start = dragStart?.cgPoint ?? shape.center.cgPoint
                shape.center = CanvasPoint(
                    CGPoint(
                        x: start.x + value.translation.width,
                        y: start.y + value.translation.height
                    )
                )
            }
            .onEnded { _ in
                dragStart = nil
                clampToCanvas()
                onFinishedEditing()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if magnificationStart == nil {
                    magnificationStart = shape.size
                }
                let start = magnificationStart?.cgSize ?? shape.size.cgSize
                shape.size = CanvasSize(
                    width: max(32, start.width * value),
                    height: max(32, start.height * value)
                )
            }
            .onEnded { _ in
                magnificationStart = nil
                clampToCanvas()
                onFinishedEditing()
            }
    }

    private var rotateGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                if rotationStart == nil {
                    rotationStart = shape.rotationDegrees
                }
                shape.rotationDegrees = (rotationStart ?? 0) + angle.degrees
            }
            .onEnded { _ in
                rotationStart = nil
                onFinishedEditing()
            }
    }

    private func clampToCanvas() {
        let halfWidth = shape.size.width / 2
        let halfHeight = shape.size.height / 2
        shape.center = CanvasPoint(
            x: min(max(shape.center.x, halfWidth), max(halfWidth, canvasSize.width - halfWidth)),
            y: min(max(shape.center.y, halfHeight), max(halfHeight, canvasSize.height - halfHeight))
        )
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LineShape: Shape {
    let arrow: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + 4, y: rect.midY)
        let end = CGPoint(x: rect.maxX - 4, y: rect.midY)
        path.move(to: start)
        path.addLine(to: end)

        if arrow {
            let headLength = min(rect.width * 0.18, 34)
            let halfHeadHeight = min(rect.height * 0.34, 18)
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - headLength, y: end.y - halfHeadHeight))
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - headLength, y: end.y + halfHeadHeight))
        }

        return path
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.45

        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}
