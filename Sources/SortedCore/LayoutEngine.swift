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

        let steps = CGFloat(count - 1)
        let preferredOffset = min(offset, min(frame.width, frame.height) / CGFloat(count))
        let width = min(max(320, frame.width - preferredOffset * steps), frame.width)
        let height = min(max(220, frame.height - preferredOffset * steps), frame.height)
        // Clamp offsets so the minimum window size can't push the deepest
        // windows in the stack past the frame's edges.
        let xOffset = steps > 0 ? min(preferredOffset, (frame.width - width) / steps) : 0
        let yOffset = steps > 0 ? min(preferredOffset, (frame.height - height) / steps) : 0

        return (0..<count).map { index in
            CGRect(
                x: frame.minX + CGFloat(index) * xOffset,
                y: frame.minY + CGFloat(index) * yOffset,
                width: width,
                height: height
            )
        }
    }
}
