import XCTest
@testable import A11ySweepCore

final class A11ySweepCoreTests: XCTestCase {
    func testHittabilityRequiresFiniteVisibleNonemptyFrame() {
        let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)
        XCTAssertTrue(SweepGeometry.canCheckHittability(
            CGRect(x: 10, y: 10, width: 44, height: 44), in: viewport))
        XCTAssertTrue(SweepGeometry.canCheckHittability(
            CGRect(x: -10, y: 10, width: 44, height: 44), in: viewport))
        XCTAssertFalse(SweepGeometry.canCheckHittability(
            CGRect(x: 10, y: -1400, width: 44, height: 44), in: viewport))
        XCTAssertFalse(SweepGeometry.canCheckHittability(
            CGRect(x: 10, y: 10, width: 0, height: 44), in: viewport))
        XCTAssertFalse(SweepGeometry.canCheckHittability(
            CGRect(x: CGFloat.infinity, y: 10, width: 44, height: 44), in: viewport))
    }

    func testThrownScreenStepBecomesUnreachableAndNextStepCanRun() {
        let failure = NSError(domain: "Sweep", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "invalid activation point"])
        let reason = SweepStep.unreachableReason { () throws -> String? in throw failure }
        XCTAssertEqual(reason, "invalid activation point")
        XCTAssertEqual(SweepStep.unreachableReason { "form missing" }, "form missing")
        XCTAssertNil(SweepStep.unreachableReason { nil })

        let summary = SweepSummary(look: "largest-text", device: "iphone",
                                   screensVisited: ["cabinet", "care"],
                                   screensUnreachable: [("medicine-detail", reason!)], findings: [],
                                   screenOrder: ["cabinet", "medicine-detail", "care"])
        XCTAssertTrue(summary.text.contains("Screens unreachable (1):\n  medicine-detail: invalid activation point\n"))
        XCTAssertTrue(summary.text.contains("Screens visited (2): cabinet, care"))
    }

    func testLabelInNameNormalizationAndOrder() {
        XCTAssertTrue(LabelMatch.labelContainsVisibleText(label: "Resume café check in", visibleText: "Résumé, Café: check-in"))
        XCTAssertTrue(LabelMatch.labelContainsVisibleText(label: "Take 2 pills now", visibleText: "Take 2 pills"))
        XCTAssertFalse(LabelMatch.labelContainsVisibleText(label: "Pills take now", visibleText: "Take pills"))
        XCTAssertFalse(LabelMatch.labelContainsVisibleText(label: "Start over", visibleText: "Star"))
        XCTAssertTrue(LabelMatch.labelContainsVisibleText(label: "Anything", visibleText: "123!?"))
        XCTAssertTrue(LabelMatch.labelContainsVisibleText(label: "Anything", visibleText: "  "))
    }

    func testLookSelectionByHostIdiomAndRestriction() {
        let padOnly = SweepLook(name: "pad-only", idiom: .pad)
        let looks = SweepLook.standardMatrix + [padOnly]
        XCTAssertEqual(SweepLook.selected(from: looks, hostSetting: .none, idiom: .phone).map(\.name),
                       ["baseline", "dark", "largest-text", "dark-largest-text", "landscape", "landscape-largest-text"])
        XCTAssertEqual(SweepLook.selected(from: looks, hostSetting: .increaseContrast, idiom: .pad).map(\.name),
                       ["increased-contrast", "increased-contrast-dark"])
        XCTAssertEqual(SweepLook.selected(from: looks, hostSetting: .none, idiom: .pad,
                                          restrictedTo: " pad-only, dark, unknown ").map(\.name),
                       ["dark", "pad-only"])
        XCTAssertTrue(SweepLook.selected(from: looks, hostSetting: .none, idiom: .phone,
                                         restrictedTo: "pad-only").isEmpty)
    }

    func testSummarySectionsAndOrdering() {
        let findings = [
            SweepFinding(screen: "second", look: "baseline", check: "Audit", severity: .fail, message: "zeta"),
            SweepFinding(screen: "first", look: "baseline", check: "OCR", severity: .report, message: "guess"),
            SweepFinding(screen: "first", look: "baseline", check: "Audit", severity: .fail, message: "alpha"),
            SweepFinding(screen: "second", look: "baseline", check: "Audit", severity: .report, message: "maybe"),
            SweepFinding(screen: "second", look: "baseline", check: "Zebra", severity: .fail, message: "other")
        ]
        let summary = SweepSummary(look: "baseline", device: "iphone", screensVisited: ["first", "second"],
                                   screensUnreachable: [("third", "missing")], findings: findings,
                                   screenOrder: ["first", "second", "third"])
        XCTAssertEqual(summary.failingCount, 3)
        XCTAssertTrue(summary.text.hasPrefix("A11y sweep: baseline (iphone)\nScreens visited (2): first, second\nScreens unreachable (1):\n  third: missing\n"))
        let text = summary.text
        XCTAssertLessThan(text.range(of: "Audit (fails the run):")!.lowerBound,
                          text.range(of: "OCR (report only; check the screenshot):")!.lowerBound)
        XCTAssertLessThan(text.range(of: "Zebra (fails the run):")!.lowerBound,
                          text.range(of: "Audit (report only; check the screenshot):")!.lowerBound)
        XCTAssertLessThan(text.range(of: "first: alpha")!.lowerBound,
                          text.range(of: "second: zeta")!.lowerBound)
        XCTAssertEqual(summary.failingLines, ["  first: alpha", "  second: zeta", "  second: other"])
    }

    func testScrollContainerPrefersAnOverlappingContainer() {
        let content = CGRect(x: 300, y: 0, width: 900, height: 800)
        let chips = CGRect(x: 300, y: 100, width: 900, height: 50)
        XCTAssertEqual(SweepGeometry.scrollContainerIndex(
            for: CGRect(x: 400, y: 110, width: 80, height: 30), among: [content, chips]), 1)
    }

    func testScrollContainerForAnOffscreenTargetSkipsTheSidebar() {
        let sidebar = CGRect(x: 0, y: 0, width: 300, height: 800)
        let content = CGRect(x: 300, y: 400, width: 900, height: 400)
        XCTAssertEqual(SweepGeometry.scrollContainerIndex(
            for: CGRect(x: 800, y: 1500, width: 120, height: 60), among: [sidebar, content]), 1)
    }

    func testScrollContainerFallsBackToTheLargest() {
        let small = CGRect(x: 0, y: 0, width: 100, height: 100)
        let large = CGRect(x: 0, y: 0, width: 400, height: 400)
        XCTAssertEqual(SweepGeometry.scrollContainerIndex(
            for: CGRect(x: 600, y: 900, width: 50, height: 50), among: [small, large]), 1)
        XCTAssertNil(SweepGeometry.scrollContainerIndex(for: .zero, among: []))
    }
}
