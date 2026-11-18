import XCTest
@testable import SeedboardCore

final class RouteTests: XCTestCase {
    private let a = CGRect(x: 0, y: 0, width: 100, height: 50)

    func testSideBySideLeavesRightAndArrivesLeft() {
        let b = CGRect(x: 200, y: 0, width: 100, height: 50)
        let path = Route.path(from: a, to: b, style: .elbow)
        XCTAssertEqual(path.leaves, .right)
        XCTAssertEqual(path.arrives, .left)
        XCTAssertEqual(path.points, [CGPoint(x: 100, y: 25), CGPoint(x: 200, y: 25)])
    }

    func testToTheLeftLeavesLeftAndArrivesRight() {
        let b = CGRect(x: -300, y: 0, width: 100, height: 50)
        let path = Route.path(from: a, to: b, style: .elbow)
        XCTAssertEqual(path.leaves, .left)
        XCTAssertEqual(path.arrives, .right)
        XCTAssertEqual(path.points, [CGPoint(x: 0, y: 25), CGPoint(x: -200, y: 25)])
    }

    func testStackedLeavesDownAndArrivesUp() {
        let b = CGRect(x: 0, y: 150, width: 100, height: 50)
        let path = Route.path(from: a, to: b, style: .elbow)
        XCTAssertEqual(path.leaves, .down)
        XCTAssertEqual(path.arrives, .up)
        XCTAssertEqual(path.points, [CGPoint(x: 50, y: 50), CGPoint(x: 50, y: 150)])
        let above = Route.path(from: b, to: a, style: .elbow)
        XCTAssertEqual(above.leaves, .up)
        XCTAssertEqual(above.arrives, .down)
    }

    func testElbowHasFourPointsWhenNotLevel() {
        let side = Route.path(from: a, to: CGRect(x: 200, y: 40, width: 100, height: 50), style: .elbow)
        XCTAssertEqual(side.points.count, 4)
        XCTAssertEqual(side.points[1], CGPoint(x: 150, y: 25))
        XCTAssertEqual(side.points[2], CGPoint(x: 150, y: 65))
        let stack = Route.path(from: a, to: CGRect(x: 30, y: 150, width: 100, height: 50), style: .elbow)
        XCTAssertEqual(stack.points.count, 4)
        XCTAssertEqual(stack.points[1], CGPoint(x: 50, y: 100))
        XCTAssertEqual(stack.points[2], CGPoint(x: 80, y: 100))
    }

    func testStraightAndCurveAreTwoPoints() {
        let b = CGRect(x: 200, y: 40, width: 100, height: 50)
        XCTAssertEqual(Route.path(from: a, to: b, style: .straight).points.count, 2)
        XCTAssertEqual(Route.path(from: a, to: b, style: .curve).points.count, 2)
    }

    func testTheLabelLiesOnTheLine() {
        let others = [CGRect(x: 200, y: 0, width: 100, height: 50), CGRect(x: 200, y: 40, width: 100, height: 50),
                      CGRect(x: 30, y: 150, width: 100, height: 50), CGRect(x: -300, y: -200, width: 100, height: 50)]
        for b in others { for style in LinkStyle.allCases {
            let path = Route.path(from: a, to: b, style: style)
            XCTAssertEqual(Route.distance(from: path.label, to: path.points), 0, accuracy: 0.001)
        } }
    }

    func testMiddleIsHalfWayAlongTheLine() {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)]
        XCTAssertEqual(Route.middle(of: line), CGPoint(x: 100, y: 0))
        XCTAssertEqual(Route.middle(of: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]), CGPoint(x: 50, y: 0))
    }

    func testDistanceToASegment() {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        XCTAssertEqual(Route.distance(from: CGPoint(x: 50, y: 10), to: line), 10, accuracy: 0.001)
        XCTAssertEqual(Route.distance(from: CGPoint(x: 130, y: 40), to: line), 50, accuracy: 0.001)   // past the end
        XCTAssertEqual(Route.distance(from: CGPoint(x: 50, y: 0), to: line), 0, accuracy: 0.001)
        let bent = line + [CGPoint(x: 100, y: 100)]
        XCTAssertEqual(Route.distance(from: CGPoint(x: 90, y: 60), to: bent), 10, accuracy: 0.001)
        XCTAssertEqual(Route.distance(from: .zero, to: []), .infinity)
    }

    func testBranchEnds() {
        let child = CGRect(x: 200, y: 100, width: 80, height: 30)
        let right = Route.branch(from: a, to: child, side: .right)
        XCTAssertEqual(right.start, CGPoint(x: 100, y: 25))
        XCTAssertEqual(right.end, CGPoint(x: 200, y: 115))
        let left = Route.branch(from: a, to: child, side: .left)
        XCTAssertEqual(left.start, CGPoint(x: 0, y: 25))
        XCTAssertEqual(left.end, CGPoint(x: 280, y: 115))
    }
}
