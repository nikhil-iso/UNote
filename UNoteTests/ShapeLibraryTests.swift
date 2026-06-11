import XCTest
@testable import UNote

final class ShapeLibraryTests: XCTestCase {
    func testShapeInsertionAppendsShapeWithExpectedKind() {
        var shapes: [CanvasShape] = []

        let inserted = ShapeLibrary.insert(
            kind: .star,
            into: &shapes,
            at: CGPoint(x: 100, y: 120),
            constrainedTo: CGSize(width: 300, height: 400)
        )

        XCTAssertEqual(shapes.count, 1)
        XCTAssertEqual(inserted.kind, .star)
        XCTAssertEqual(shapes[0], inserted)
    }

    func testShapeInsertionClampsCenterToCanvas() {
        var shapes: [CanvasShape] = []

        let inserted = ShapeLibrary.insert(
            kind: .circle,
            into: &shapes,
            at: CGPoint(x: -200, y: 900),
            constrainedTo: CGSize(width: 300, height: 400)
        )

        XCTAssertGreaterThanOrEqual(inserted.center.x, 0)
        XCTAssertLessThanOrEqual(inserted.center.x, 300)
        XCTAssertGreaterThanOrEqual(inserted.center.y, 0)
        XCTAssertLessThanOrEqual(inserted.center.y, 400)
    }
}
