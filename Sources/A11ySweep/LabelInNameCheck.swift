#if canImport(XCTest) && os(iOS)
import XCTest
import Vision
import UIKit
import A11ySweepCore

public struct LabelInNameCheck: SweepCheck {
    public let name = "Label in name"
    public let severity: FindingSeverity

    public init(severity: FindingSeverity = .report) {
        self.severity = severity
    }

    public func inspect(screen: SweepScreen, look: SweepLook, app: XCUIApplication) -> [SweepFinding] {
        let screenshot = XCUIScreen.main.screenshot().image
        guard let image = screenshot.cgImage else { return [] }
        let screenFrame = CGRect(origin: .zero, size: screenshot.size)
        let controls = app.descendants(matching: .any).allElementsBoundByIndex.filter {
            [.button, .link, .switch, .textField, .secureTextField].contains($0.elementType)
        }
        var findings: [SweepFinding] = []
        for element in controls {
            guard element.exists else { continue }
            let frame = element.frame
            // Lazy SwiftUI controls can remain in the tree with an invalid frame.
            // XCTest itself fails when asked for isHittable on one of those elements.
            guard frame.minX.isFinite, frame.minY.isFinite,
                  frame.width >= 10, frame.height >= 10,
                  screenFrame.intersects(frame) else { continue }
            let crop = frame.intersection(screenFrame)
            let pixels = CGRect(
                x: crop.minX * screenshot.scale,
                y: crop.minY * screenshot.scale,
                width: crop.width * screenshot.scale,
                height: crop.height * screenshot.scale
            ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard !pixels.isEmpty, let cropped = image.cropping(to: pixels) else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            do {
                try VNImageRequestHandler(cgImage: cropped).perform([request])
            } catch {
                continue
            }
            let recognized = (request.results ?? []).compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= 0.8 else { return nil }
                return candidate.string
            }
            for visibleText in recognized where !LabelMatch.labelContainsVisibleText(label: element.label, visibleText: visibleText) {
                findings.append(SweepFinding(
                    screen: screen.name,
                    look: look.name,
                    check: name,
                    severity: severity,
                    message: "visible text \"\(visibleText)\" is absent from accessibility label \"\(element.label)\"",
                    element: element.identifier.isEmpty ? element.label : element.identifier
                ))
            }
        }
        return findings
    }
}
#endif
