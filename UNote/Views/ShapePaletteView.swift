import SwiftUI

struct ShapePaletteView: View {
    let insertShape: (ShapeKind) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach([ShapeKind.circle, .square, .triangle, .line, .arrow, .star]) { kind in
                Button {
                    insertShape(kind)
                } label: {
                    Image(systemName: symbolName(for: kind))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .help(helpText(for: kind))
                .draggable(kind.rawValue)
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func symbolName(for kind: ShapeKind) -> String {
        switch kind {
        case .circle: "circle"
        case .square, .rectangle: "square"
        case .triangle: "triangle"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .star: "star"
        }
    }

    private func helpText(for kind: ShapeKind) -> String {
        switch kind {
        case .circle: "Circle"
        case .square: "Square"
        case .rectangle: "Rectangle"
        case .triangle: "Triangle"
        case .line: "Line"
        case .arrow: "Arrow"
        case .star: "Star"
        }
    }
}
