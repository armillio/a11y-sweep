#if canImport(XCTest) && os(iOS)
import XCTest
import A11ySweepCore

public struct SweepScreen {
    public let name: String
    public let open: (XCUIApplication) throws -> String?
    public let mustStayOperable: [(XCUIApplication) -> XCUIElement]
    public let leave: ((XCUIApplication) throws -> Void)?

    public init(
        name: String,
        open: @escaping (XCUIApplication) throws -> String?,
        mustStayOperable: [(XCUIApplication) -> XCUIElement] = [],
        leave: ((XCUIApplication) throws -> Void)? = nil
    ) {
        self.name = name
        self.open = open
        self.mustStayOperable = mustStayOperable
        self.leave = leave
    }
}

public protocol SweepCheck {
    var name: String { get }
    func inspect(screen: SweepScreen, look: SweepLook, app: XCUIApplication) throws -> [SweepFinding]
}
#endif
