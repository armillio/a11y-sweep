import Foundation

public enum FindingSeverity: String, Sendable {
    case fail, report
}

public struct SweepFinding: Sendable {
    public let screen: String
    public let look: String
    public let check: String
    public let severity: FindingSeverity
    public let message: String
    public let element: String?

    public init(screen: String, look: String, check: String, severity: FindingSeverity, message: String, element: String? = nil) {
        self.screen = screen
        self.look = look
        self.check = check
        self.severity = severity
        self.message = message
        self.element = element
    }
}

/// A failed navigation or check belongs to one screen, never to the whole look.
public enum SweepStep {
    public static func unreachableReason(from operation: () throws -> String?) -> String? {
        do { return try operation() }
        catch { return error.localizedDescription }
    }
}

public struct SweepSummary {
    public let look: String
    public let device: String
    public let screensVisited: [String]
    public let screensUnreachable: [(screen: String, reason: String)]
    public let findings: [SweepFinding]
    public let screenOrder: [String]

    public init(look: String, device: String, screensVisited: [String], screensUnreachable: [(screen: String, reason: String)], findings: [SweepFinding], screenOrder: [String]? = nil) {
        self.look = look
        self.device = device
        self.screensVisited = screensVisited
        self.screensUnreachable = screensUnreachable
        self.findings = findings
        self.screenOrder = screenOrder ?? screensVisited + screensUnreachable.map(\.screen)
    }

    public var failingCount: Int { findings.filter { $0.severity == .fail }.count }

    public var failingLines: [String] {
        orderedCheckNames.flatMap { check in
            orderedFindings.filter { $0.check == check && $0.severity == .fail }.map(Self.line(for:))
        }
    }

    public var text: String {
        var lines = ["A11y sweep: \(look) (\(device))"]
        lines.append("Screens visited (\(screensVisited.count)): \(screensVisited.joined(separator: ", "))")
        lines.append("Screens unreachable (\(screensUnreachable.count)):")
        lines += screensUnreachable.map { "  \($0.screen): \($0.reason)" }
        for severity in [FindingSeverity.fail, .report] {
            for check in orderedCheckNames {
                let matching = orderedFindings.filter { $0.check == check && $0.severity == severity }
                guard !matching.isEmpty else { continue }
                let description = severity == .fail ? "fails the run" : "report only; check the screenshot"
                lines.append("\(check) (\(description)):")
                lines += matching.map(Self.line(for:))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private var orderedCheckNames: [String] {
        let names = Set(findings.map(\.check))
        return names.sorted { a, b in
            let aFails = findings.contains { $0.check == a && $0.severity == .fail }
            let bFails = findings.contains { $0.check == b && $0.severity == .fail }
            return aFails == bFails ? a < b : aFails
        }
    }

    private var orderedFindings: [SweepFinding] {
        let order = Dictionary(uniqueKeysWithValues: screenOrder.enumerated().map { ($0.element, $0.offset) })
        return findings.sorted {
            let a = order[$0.screen] ?? Int.max
            let b = order[$1.screen] ?? Int.max
            if a != b { return a < b }
            if $0.message != $1.message { return $0.message < $1.message }
            return ($0.element ?? "") < ($1.element ?? "")
        }
    }

    private static func line(for finding: SweepFinding) -> String {
        let element = finding.element.map { " [\($0)]" } ?? ""
        return "  \(finding.screen): \(finding.message)\(element)"
    }
}
