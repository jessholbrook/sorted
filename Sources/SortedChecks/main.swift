import CoreGraphics
import SortedCore

let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
let grid = LayoutEngine.grid(count: 5, in: bounds)
precondition(grid.count == 5)
precondition(grid.allSatisfy { bounds.contains($0) })

let grouped = LayoutEngine.grouped(
    groupSizes: [2, 1, 3],
    in: CGRect(x: 0, y: 0, width: 1440, height: 900)
)
precondition(grouped.map(\.count) == [2, 1, 3])

let cascade = LayoutEngine.cascade(count: 3, in: bounds)
precondition(cascade.count == 3)
precondition(cascade[1].minX > cascade[0].minX)
precondition(cascade[2].minY > cascade[1].minY)

print("Sorted layout checks passed.")
