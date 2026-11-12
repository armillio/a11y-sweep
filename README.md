# A11ySweep

A test-only Swift package for sweeping an iOS app's screens in XCUITest. Each look saves JPEG screenshots and a text summary. Audit failures, inoperable decisive actions, unreachable screens, and evidence write failures fail the test.

## Status

Verified on iPhone 16 with iOS 18.6. Xcode 15 or later is required. iPad is unverified and is known not to work with the iPadOS floating, paginated tab bar; apps must supply their own iPad routes. Landscape routes depend on the app.

## Checks and limits

- Apple's accessibility audit checks contrast, hit regions, element descriptions, dynamic type, clipping, and other supported types. Text-clipped findings are report-only by default because the audit can flag fully visible labels and miss truncation.
- OCR compares visible control text with accessibility labels. It is report-only by default because recognition is uncertain. Set `LabelInNameCheck(severity: .fail)` if appropriate for your app.
- Decisive actions named by the app must exist and remain hittable after scrolling.

This does not test real VoiceOver focus order or speech, Switch Control, Voice Control by voice, Reduce Motion or Reduce Transparency system settings, or Apple Watch. These need a device or a service with assistive-technology users such as Fable, or real-device screen-reader automation such as BrowserStack/TestMu AI.

## Native app quick start

Add this package to the app project and link the `A11ySweep` product to its UI-test target. Define screens in navigation order. Each `open` closure navigates from the preceding screen and returns a reason if it cannot reach the destination. Give decisive actions stable identifiers.

```swift
import XCTest
import A11ySweep

final class AccessibilitySweepTests: XCTestCase {
    func testSweep() throws {
        let screens = [
            SweepScreen(name: "home", open: { _ in nil }, mustStayOperable: [
                { $0.buttons["primaryAction"] }
            ]),
            SweepScreen(name: "details", open: { app in
                let button = app.buttons["detailsLink"]
                guard button.waitForExistence(timeout: 5) else { return "details link missing" }
                button.tap()
                return nil
            }, leave: { $0.buttons["closeDetails"].tap() })
        ]
        try AccessibilitySweep(screens: screens, launch: { look in
            let app = XCUIApplication()
            app.launchArguments += AccessibilitySweep.launchArguments(for: look)
            app.launch()
            return app
        }).run(in: self)
    }
}
```

Copy `scripts/a11y-sweep.sh` into the app repo and run, for example:

```sh
scripts/a11y-sweep.sh --project App.xcodeproj --scheme App --only-testing AppUITests/AccessibilitySweepTests/testSweep
```

Use `--workspace` instead of `--project` for a workspace. Optional flags are `--device iphone|ipad|both`, `--looks baseline,dark`, `--runtime <simulator-runtime-id>`, and `--output <directory>`. The default runtime is iOS 18.6; install it or pass a runtime available on your machine. The runner creates and removes its own simulators and DerivedData.
The default device is `iphone`. Custom looks can use the nested types `SweepLook.Appearance`, `SweepLook.Orientation`, `SweepLook.Idiom`, and `SweepLook.HostSetting` through `import A11ySweep`.

## Expo and React Native

The same package works once the generated `ios/` project has an XCUITest target. Navigate with stable `accessibilityIdentifier` values from React Native `testID` props. Run the copied script against the generated project or workspace.

## Environment and output

Setting `A11Y_SWEEP_OUTPUT` opts the test in; without it, the test skips. The script forwards it through `TEST_RUNNER_A11Y_SWEEP_OUTPUT`. `A11Y_SWEEP_HOST_SETTING` is `none` or `increase-contrast`; the script sets the simulator contrast option before the corresponding run. `A11Y_SWEEP_LOOKS` is an optional comma-separated list of look names. The script forwards both through the matching `TEST_RUNNER_` variables.

The output folder contains `<device>-<look>-NN-<screen>.jpg` and `<device>-<look>-summary.txt`, plus one `.xcresult` per simulator run. Each unreachable screen also gets `<device>-<look>-NN-<screen>-hierarchy.txt` with the XCUI hierarchy. Errors thrown by a screen's route, checks, or leave action are recorded as unreachable for that screen so the look can continue and write its summary. A missing summary fails the script even if `xcodebuild` reports success.

## Versioning

Use semantic version tags. Apps should pin the package with `upToNextMinor` so a minor update is an explicit choice.
