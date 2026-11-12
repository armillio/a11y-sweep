#if canImport(XCTest) && os(iOS)
import XCTest
import A11ySweepCore

public struct AppleAuditCheck: SweepCheck {
    public let name = "Apple accessibility audit"
    public let types: XCUIAccessibilityAuditType
    public let disposition: (XCUIAccessibilityAuditIssue) -> FindingSeverity

    public init(
        types: XCUIAccessibilityAuditType = .all,
        disposition: @escaping (XCUIAccessibilityAuditIssue) -> FindingSeverity = { issue in
            issue.auditType == .textClipped ? .report : .fail
        }
    ) {
        self.types = types
        self.disposition = disposition
    }

    public func inspect(screen: SweepScreen, look: SweepLook, app: XCUIApplication) -> [SweepFinding] {
        var findings: [SweepFinding] = []
        do {
            try app.performAccessibilityAudit(for: types) { issue in
                findings.append(SweepFinding(
                    screen: screen.name,
                    look: look.name,
                    check: name,
                    severity: disposition(issue),
                    message: issue.compactDescription,
                    element: issue.element.map { $0.identifier.isEmpty ? $0.label : $0.identifier }
                ))
                return true
            }
        } catch {
            findings.append(SweepFinding(
                screen: screen.name,
                look: look.name,
                check: name,
                severity: .fail,
                message: "audit could not complete: \(error.localizedDescription)"
            ))
        }
        return findings
    }
}
#endif
