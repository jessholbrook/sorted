import CoreGraphics

public enum LayoutEngine {
    static let padding: CGFloat = 12

    public static func grid(count: Int, in frame: CGRect) -> [CGRect] {
        guard count > 0 else { return [] }

        let columns = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let cellWidth = (frame.width - padding * CGFloat(columns + 1)) / CGFloat(columns)
        let cellHeight = (frame.height - padding * CGFloat(rows + 1)) / CGFloat(rows)

        return (0..<count).map { index in
            let column = index % columns
            let row = index / columns
            return CGRect(
                x: frame.minX + padding + CGFloat(column) * (cellWidth + padding),
                y: frame.minY + padding + CGFloat(row) * (cellHeight + padding),
                width: cellWidth,
                height: cellHeight
            )
        }
    }

    public static func grouped(groupSizes: [Int], in frame: CGRect) -> [[CGRect]] {
        guard !groupSizes.isEmpty else { return [] }

        let cells = grid(count: groupSizes.count, in: frame)
        return zip(groupSizes, cells).map { count, cell in
            cascade(count: count, in: cell, offset: 24)
        }
    }

    public static func cascade(count: Int, in frame: CGRect, offset: CGFloat = 32) -> [CGRect] {
        guard count > 0 else { return [] }

        let availableOffset = min(offset, min(frame.width, frame.height) / CGFloat(max(count, 1)))
        let width = max(320, frame.width - availableOffset * CGFloat(max(count - 1, 0)))
        let height = max(220, frame.height - availableOffset * CGFloat(max(count - 1, 0)))

        return (0..<count).map { index in
            CGRect(
                x: frame.minX + CGFloat(index) * availableOffset,
                y: frame.minY + CGFloat(index) * availableOffset,
                width: min(width, frame.width),
                height: min(height, frame.height)
            )
        }
    }
}
