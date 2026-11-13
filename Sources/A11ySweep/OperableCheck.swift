#if canImport(XCTest) && os(iOS)
import XCTest
import A11ySweepCore

public struct OperableCheck: SweepCheck {
    public let name = "Decisive actions"
    public init() {}

    public func inspect(screen: SweepScreen, look: SweepLook, app: XCUIApplication) -> [SweepFinding] {
        screen.mustStayOperable.enumerated().compactMap { index, locator in
            let element = locator(app)
            guard element.exists else {
                return failure(screen: screen, look: look, element: "action \(index + 1)")
            }
            if element.safelyIsHittable(in: app) { return nil }

            let scrollables = app.descendants(matching: .any).allElementsBoundByIndex.filter {
                [.scrollView, .table, .collectionView].contains($0.elementType) && $0.exists
            }
            if let index = SweepGeometry.scrollContainerIndex(for: element.frame,
                                                             among: scrollables.map(\.frame)) {
                let container = scrollables[index]
                // Short drags that stop dead, never flicks: a flick's momentum can carry the
                // action straight past a short visible window, which is exactly the window a
                // landscape screen at a large text size leaves. Drag toward the action first;
                // only when that end is reached without making it hittable, try the other way.
                let visible = container.frame.intersection(app.frame)
                let startFrame = element.exists ? element.frame : .null
                let targetIsAbove = !visible.isNull && !startFrame.isNull && startFrame.maxY <= visible.minY
                for up in targetIsAbove ? [false, true] : [true, false] {
                    var lastFrame = startFrame
                    var missingSteps = 0
                    for _ in 0..<Self.maxStepsPerDirection {
                        guard drag(container, in: app, up: up) else { break }
                        if element.safelyIsHittable(in: app) { return nil }
                        // A lazy container can recycle the action's cell while it is off
                        // screen. Reading the frame of a missing element fails the host test,
                        // so a missing action just means "keep scrolling".
                        guard element.exists else {
                            missingSteps += 1
                            if missingSteps >= Self.maxMissingSteps { break }
                            lastFrame = .null
                            continue
                        }
                        missingSteps = 0
                        let frame = element.frame
                        if frame == lastFrame { break } // this end of the content is reached
                        lastFrame = frame
                    }
                }
            }
            let identity = element.identifier.isEmpty ? (element.label.isEmpty ? "action \(index + 1)" : element.label) : element.identifier
            return failure(screen: screen, look: look, element: identity)
        }
    }

    /// A safety net only: each direction normally ends when the action stops moving, and the
    /// cap must stay well above the steps a long screen at a large text size needs.
    static let maxStepsPerDirection = 150
    /// Steps a direction may keep going while the action is out of the tree before it gives up.
    static let maxMissingSteps = 20

    /// Drags the visible part of `container` by 40% of its height and holds before lifting,
    /// so the content moves by the drag alone. Returns false when too little of it is visible
    /// to drag at all.
    private func drag(_ container: XCUIElement, in app: XCUIApplication, up: Bool) -> Bool {
        let visible = container.frame.intersection(app.frame)
        guard !visible.isNull, visible.height >= 60, visible.width >= 20 else { return false }
        // Frames are in screen space; offsets from the app's own origin are not, whenever the
        // app does not fill the screen (iPad split view).
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = visible.midX - app.frame.minX, top = visible.minY - app.frame.minY
        let from = up ? 0.7 : 0.3, to = up ? 0.3 : 0.7
        let start = origin.withOffset(CGVector(dx: x, dy: top + visible.height * from))
        let end = origin.withOffset(CGVector(dx: x, dy: top + visible.height * to))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        return true
    }

    private func failure(screen: SweepScreen, look: SweepLook, element: String) -> SweepFinding {
        SweepFinding(screen: screen.name, look: look.name, check: name, severity: .fail,
                     message: "decisive action not operable in this look", element: element)
    }
}
#endif
