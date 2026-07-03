import CoreGraphics
import Testing
@testable import SortedCore

@Suite struct LayoutEngineTests {
    let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)

    /// Containment with a tiny tolerance for floating-point rounding.
    private func contained(_ rect: CGRect, in frame: CGRect) -> Bool {
        frame.insetBy(dx: -0.001, dy: -0.001).contains(rect)
    }

    // MARK: Grid

    @Test func gridProducesOneFramePerWindow() {
        #expect(LayoutEngine.grid(count: 5, in: bounds).count == 5)
        #expect(LayoutEngine.grid(count: 1, in: bounds).count == 1)
    }

    @Test func gridWithZeroWindowsIsEmpty() {
        #expect(LayoutEngine.grid(count: 0, in: bounds).isEmpty)
    }

    @Test(arguments: [1, 2, 3, 5, 8, 13])
    func gridFramesStayInsideBounds(count: Int) {
        let frames = LayoutEngine.grid(count: count, in: bounds)
        #expect(frames.allSatisfy { contained($0, in: bounds) })
    }

    @Test func gridFramesDoNotOverlap() {
        let frames = LayoutEngine.grid(count: 4, in: bounds)
        for (index, frame) in frames.enumerated() {
            for other in frames[(index + 1)...] {
                #expect(!frame.intersects(other))
            }
        }
    }

    // MARK: Grouped

    @Test func groupedMatchesGroupSizes() {
        let grouped = LayoutEngine.grouped(groupSizes: [2, 1, 3], in: bounds)
        #expect(grouped.map(\.count) == [2, 1, 3])
    }

    @Test func groupedWithNoGroupsIsEmpty() {
        #expect(LayoutEngine.grouped(groupSizes: [], in: bounds).isEmpty)
    }

    @Test func groupedFramesStayInsideBoundsEvenWithManySmallCells() {
        let smallBounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let grouped = LayoutEngine.grouped(
            groupSizes: [2, 1, 3, 4, 5, 2, 1, 3, 4],
            in: smallBounds
        )
        #expect(grouped.flatMap(\.self).allSatisfy { contained($0, in: smallBounds) })
    }

    // MARK: Cascade

    @Test func cascadeProducesOneFramePerWindow() {
        #expect(LayoutEngine.cascade(count: 3, in: bounds).count == 3)
    }

    @Test func cascadeWithZeroWindowsIsEmpty() {
        #expect(LayoutEngine.cascade(count: 0, in: bounds).isEmpty)
    }

    @Test func cascadeOffsetsEachWindow() {
        let frames = LayoutEngine.cascade(count: 3, in: bounds)
        #expect(frames[1].minX > frames[0].minX)
        #expect(frames[2].minY > frames[1].minY)
    }

    @Test(arguments: [1, 2, 3, 5, 10])
    func cascadeStaysInsideBounds(count: Int) {
        let frames = LayoutEngine.cascade(count: count, in: bounds)
        #expect(frames.allSatisfy { contained($0, in: bounds) })
    }

    @Test func cascadeStaysInsideFrameSmallerThanMinimumWindowSize() {
        // The 320x220 minimum window size used to push later windows past the
        // frame's edges; offsets are clamped so the stack stays contained.
        let smallBounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        let frames = LayoutEngine.cascade(count: 5, in: smallBounds)
        #expect(frames.count == 5)
        #expect(frames.allSatisfy { contained($0, in: smallBounds) })
    }
}
