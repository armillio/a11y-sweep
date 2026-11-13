import Foundation
import CoreGraphics

/// Avoid asking XCTest for hittability when an element has no usable activation frame.
public enum SweepGeometry {
    public static func canCheckHittability(_ frame: CGRect, in viewport: CGRect) -> Bool {
        guard !frame.isNull, !frame.isInfinite, !frame.isEmpty,
              !viewport.isNull, !viewport.isInfinite, !viewport.isEmpty,
              frame.minX.isFinite, frame.minY.isFinite,
              frame.maxX.isFinite, frame.maxY.isFinite,
              viewport.minX.isFinite, viewport.minY.isFinite,
              viewport.maxX.isFinite, viewport.maxY.isFinite else { return false }
        return frame.intersects(viewport)
    }

    /// Which scroll container to scroll to bring `target` into view, by index into `containers`.
    ///
    /// A container that already overlaps the target wins, smallest first, because the target
    /// is then on screen but covered and a nested scroller is the one that moves it. A target
    /// off screen overlaps nothing, so the next choice is the largest container in the
    /// target's own column: a sidebar or a list beside the content is never the one that holds
    /// it. Only when no container shares the column does the largest one overall win.
    package static func scrollContainerIndex(for target: CGRect, among containers: [CGRect]) -> Int? {
        let area: (CGRect) -> CGFloat = { $0.width * $0.height }
        let indexed = containers.enumerated().filter { !$0.element.isNull && !$0.element.isEmpty }
        if let hit = indexed.filter({ $0.element.intersects(target) })
            .min(by: { area($0.element) < area($1.element) }) {
            return hit.offset
        }
        let column = indexed.filter { $0.element.minX < target.maxX && target.minX < $0.element.maxX }
        if let best = column.max(by: { area($0.element) < area($1.element) }) { return best.offset }
        return indexed.max(by: { area($0.element) < area($1.element) })?.offset
    }
}
