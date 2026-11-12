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
}
