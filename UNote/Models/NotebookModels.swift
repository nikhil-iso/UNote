import CoreGraphics
import Foundation

enum RenderingMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case vector
    case raster

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vector:
            "Vector"
        case .raster:
            "Raster"
        }
    }

    var preferenceDescription: String {
        switch self {
        case .vector:
            "Vector (always sharp, larger file)"
        case .raster:
            "Raster (flattened exports, smaller thumbnails)"
        }
    }
}

enum PageMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case infiniteCanvas
    case standardPages

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .infiniteCanvas:
            "Infinite canvas"
        case .standardPages:
            "Standard pages"
        }
    }
}

enum StandardPaperSize: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case letter
    case legal
    case a2
    case a3
    case a4
    case a5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .letter: "Letter"
        case .legal: "Legal"
        case .a2: "A2"
        case .a3: "A3"
        case .a4: "A4"
        case .a5: "A5"
        }
    }

    /// PDF points at 72 points per inch. Exports use these exact dimensions.
    var dimensionsInPoints: CGSize {
        switch self {
        case .letter:
            CGSize(width: 612, height: 792)
        case .legal:
            CGSize(width: 612, height: 1_008)
        case .a2:
            CGSize(width: 1_191, height: 1_684)
        case .a3:
            CGSize(width: 842, height: 1_191)
        case .a4:
            CGSize(width: 595, height: 842)
        case .a5:
            CGSize(width: 420, height: 595)
        }
    }
}

struct NotebookMetadata: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var pageMode: PageMode
    var standardSize: StandardPaperSize?
    var creationDate: Date
    var lastModifiedDate: Date
    var renderingMode: RenderingMode
    var pageCount: Int
    var autoShapeRecognitionEnabled: Bool

    var effectivePageSize: CGSize? {
        guard pageMode == .standardPages else { return nil }
        return standardSize?.dimensionsInPoints
    }
}

struct NotebookSummary: Identifiable, Equatable, Sendable {
    var id: UUID { metadata.id }
    var metadata: NotebookMetadata
    var folderURL: URL
    var thumbnailURL: URL?
}

struct CanvasPoint: Codable, Equatable, Hashable, Sendable {
    var x: CGFloat
    var y: CGFloat

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

struct CanvasSize: Codable, Equatable, Hashable, Sendable {
    var width: CGFloat
    var height: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    init(_ size: CGSize) {
        width = size.width
        height = size.height
    }

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

enum ShapeKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case circle
    case square
    case rectangle
    case triangle
    case line
    case arrow
    case star

    var id: String { rawValue }
}

struct CanvasShape: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var kind: ShapeKind
    var center: CanvasPoint
    var size: CanvasSize
    var rotationDegrees: Double
    var strokeColorHex: String
    var fillColorHex: String?
    var lineWidth: Double

    init(
        id: UUID = UUID(),
        kind: ShapeKind,
        center: CGPoint,
        size: CGSize,
        rotationDegrees: Double = 0,
        strokeColorHex: String = "#111827",
        fillColorHex: String? = nil,
        lineWidth: Double = 3
    ) {
        self.id = id
        self.kind = kind
        self.center = CanvasPoint(center)
        self.size = CanvasSize(size)
        self.rotationDegrees = rotationDegrees
        self.strokeColorHex = strokeColorHex
        self.fillColorHex = fillColorHex
        self.lineWidth = lineWidth
    }

    var boundingRect: CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
