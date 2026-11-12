#if canImport(XCTest) && os(iOS)
import XCTest
import A11ySweepCore

extension XCUIElement {
    func safelyIsHittable(in app: XCUIApplication) -> Bool {
        // A partially clipped SwiftUI Form row can intersect the viewport yet
        // have no valid activation point (for example under a navigation bar).
        guard exists, SweepGeometry.canCheckHittability(frame, in: app.frame),
              app.frame.contains(frame) else { return false }
        return isHittable
    }
}
#endif
