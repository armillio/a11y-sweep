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
            let container = scrollables.filter { $0.frame.intersects(element.frame) || $0.frame.contains(element.frame) }
                .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
                ?? scrollables.min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            if let container {
                for direction in 0..<8 {
                    if direction < 4 { container.swipeUp() } else { container.swipeDown() }
                    if element.safelyIsHittable(in: app) { return nil }
                }
            }
            let identity = element.identifier.isEmpty ? (element.label.isEmpty ? "action \(index + 1)" : element.label) : element.identifier
            return failure(screen: screen, look: look, element: identity)
        }
    }

    private func failure(screen: SweepScreen, look: SweepLook, element: String) -> SweepFinding {
        SweepFinding(screen: screen.name, look: look.name, check: name, severity: .fail,
                     message: "decisive action not operable in this look", element: element)
    }
}
#endif
