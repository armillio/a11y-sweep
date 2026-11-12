#if canImport(XCTest) && os(iOS)
import Foundation
import XCTest
import UIKit
@_exported import A11ySweepCore

public final class AccessibilitySweep {
    public let screens: [SweepScreen]
    public let looks: [SweepLook]
    public let checks: [SweepCheck]
    public let launch: (SweepLook) -> XCUIApplication

    public init(
        screens: [SweepScreen],
        looks: [SweepLook] = SweepLook.standardMatrix,
        checks: [SweepCheck] = [AppleAuditCheck(), LabelInNameCheck(), OperableCheck()],
        launch: @escaping (SweepLook) -> XCUIApplication
    ) {
        self.screens = screens
        self.looks = looks
        self.checks = checks
        self.launch = launch
    }

    public static func launchArguments(for look: SweepLook) -> [String] {
        look.contentSize.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? []
    }

    public func run(in testCase: XCTestCase) throws {
        try runSelected(looks, in: testCase)
    }

    public func run(look: SweepLook, in testCase: XCTestCase) throws {
        try runSelected([look], in: testCase)
    }

    private func runSelected(_ candidates: [SweepLook], in testCase: XCTestCase) throws {
        let environment = ProcessInfo.processInfo.environment
        guard let folder = environment[SweepEnvironment.outputFolder], !folder.isEmpty else {
            throw XCTSkip("Set \(SweepEnvironment.outputFolder) to opt in to the accessibility sweep")
        }
        guard let host = SweepLook.HostSetting(rawValue: environment[SweepEnvironment.hostSetting] ?? SweepLook.HostSetting.none.rawValue) else {
            XCTFail("Invalid \(SweepEnvironment.hostSetting)")
            return
        }
        let idiom: SweepLook.Idiom = UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        let device = idiom == .pad ? "ipad" : "iphone"
        let selected = SweepLook.selected(from: candidates, hostSetting: host, idiom: idiom,
                                          restrictedTo: environment[SweepEnvironment.looks])
        guard !selected.isEmpty else { throw XCTSkip("No sweep looks selected for this host setting and device") }
        let folderURL = URL(fileURLWithPath: folder, isDirectory: true)
        for look in selected {
            XCUIDevice.shared.appearance = look.appearance == .dark ? .dark : .light
            let app = launch(look)
            XCUIDevice.shared.orientation = look.orientation == .landscape ? .landscapeLeft : .portrait
            defer {
                app.terminate()
                XCUIDevice.shared.orientation = .portrait
                XCUIDevice.shared.appearance = .light
            }
            var visited: [String] = []
            var unreachable: [(screen: String, reason: String)] = []
            var findings: [SweepFinding] = []
            // Keep the evidence write on the unwind path as well as the normal path.
            // SweepStep turns thrown route/check/leave errors into unreachable screens.
            defer {
                let summary = SweepSummary(look: look.name, device: device, screensVisited: visited,
                                           screensUnreachable: unreachable, findings: findings,
                                           screenOrder: screens.map(\.name))
                write(Data(summary.text.utf8), to: folderURL.appendingPathComponent("\(device)-\(look.name)-summary.txt"), testCase: testCase)
                if summary.failingCount > 0 || !unreachable.isEmpty {
                    let examples = (summary.failingLines + unreachable.map { "  \($0.screen): \($0.reason)" }).prefix(3).joined(separator: "\n")
                    XCTFail("\(look.name): \(summary.failingCount) failing findings, \(unreachable.count) unreachable screens\n\(examples)")
                }
            }
            for (index, screen) in screens.enumerated() {
                let prefix = String(format: "%@-%@-%02d-%@", device, look.name, index + 1, screen.name)
                let reason = SweepStep.unreachableReason {
                    let routeReason = try screen.open(app)
                    if let routeReason { return routeReason }
                    Thread.sleep(forTimeInterval: 0.3)
                    let image = XCUIScreen.main.screenshot().image
                    if let jpeg = image.jpegData(compressionQuality: 0.7) {
                        write(jpeg, to: folderURL.appendingPathComponent(prefix + ".jpg"), testCase: testCase)
                    } else {
                        XCTFail("Could not encode screenshot: \(prefix).jpg")
                    }
                    for check in checks {
                        findings += try check.inspect(screen: screen, look: look, app: app)
                    }
                    try screen.leave?(app)
                    return nil
                }
                if let reason {
                    unreachable.append((screen.name, reason))
                    write(Data(app.debugDescription.utf8),
                          to: folderURL.appendingPathComponent(prefix + "-hierarchy.txt"),
                          testCase: testCase)
                } else {
                    visited.append(screen.name)
                }
            }
        }
    }

    private func write(_ data: Data, to url: URL, testCase: XCTestCase) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            XCTFail("Could not write sweep evidence at \(url.path): \(error.localizedDescription)")
        }
    }
}
#endif
