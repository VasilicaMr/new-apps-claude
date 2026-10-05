import SwiftUI

/// Equal-width column grid that lays out every cell up front.
///
/// Use instead of `LazyVGrid` on tvOS: a lazy grid doesn't create cells that are off screen,
/// so the focus engine finds nothing below and pressing down on the remote does nothing
/// (e.g. from "Create Custom Game" to the card games further down the home screen).
struct TVGrid: Layout {
    var columns: Int
    /// Space between rows.
    var spacing: CGFloat
    /// Space between columns; defaults to `spacing`.
    var columnSpacing: CGFloat? = nil

    private var hSpacing: CGFloat { columnSpacing ?? spacing }
    private var columnCount: Int { max(columns, 1) }

    private func cellWidth(for width: CGFloat) -> CGFloat {
        max(0, (width - hSpacing * CGFloat(columnCount - 1)) / CGFloat(columnCount))
    }

    private func rowHeights(_ subviews: Subviews, cellWidth: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columnCount).map { start in
            subviews[start..<min(start + columnCount, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height }
                .max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 1760
        let heights = rowHeights(subviews, cellWidth: cellWidth(for: width))
        let height = heights.reduce(0, +) + spacing * CGFloat(max(heights.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = cellWidth(for: bounds.width)
        let heights = rowHeights(subviews, cellWidth: width)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for column in 0..<columnCount {
                let index = row * columnCount + column
                guard index < subviews.count else { break }
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (width + hSpacing), y: y),
                    proposal: ProposedViewSize(width: width, height: height)
                )
            }
            y += height + spacing
        }
    }
}
