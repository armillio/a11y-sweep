import Foundation

public struct SweepLook: Hashable, Sendable {
    public enum Appearance: String, Hashable, Sendable {
        case light, dark
    }

    public enum Orientation: String, Hashable, Sendable {
        case portrait, landscape
    }

    public enum HostSetting: String, Hashable, Sendable {
        case none
        case increaseContrast = "increase-contrast"
    }

    public enum Idiom: String, Hashable, Sendable {
        case any, phone, pad
    }

    public let name: String
    public let appearance: Appearance
    public let contentSize: String?
    public let orientation: Orientation
    public let hostSetting: HostSetting
    public let idiom: Idiom

    public init(
        name: String,
        appearance: Appearance = .light,
        contentSize: String? = nil,
        orientation: Orientation = .portrait,
        hostSetting: HostSetting = .none,
        idiom: Idiom = .any
    ) {
        self.name = name
        self.appearance = appearance
        self.contentSize = contentSize
        self.orientation = orientation
        self.hostSetting = hostSetting
        self.idiom = idiom
    }

    private static let largest = "UICTContentSizeCategoryAccessibilityXXXL"
    public static let baseline = SweepLook(name: "baseline")
    public static let dark = SweepLook(name: "dark", appearance: .dark)
    public static let largestText = SweepLook(name: "largest-text", contentSize: largest)
    public static let darkLargestText = SweepLook(name: "dark-largest-text", appearance: .dark, contentSize: largest)
    public static let landscape = SweepLook(name: "landscape", orientation: .landscape)
    public static let landscapeLargestText = SweepLook(name: "landscape-largest-text", contentSize: largest, orientation: .landscape)
    public static let increasedContrast = SweepLook(name: "increased-contrast", hostSetting: .increaseContrast)
    public static let increasedContrastDark = SweepLook(name: "increased-contrast-dark", appearance: .dark, hostSetting: .increaseContrast)

    public static let standardMatrix: [SweepLook] = [
        .baseline, .dark, .largestText, .darkLargestText, .landscape,
        .landscapeLargestText, .increasedContrast, .increasedContrastDark
    ]

    public func applies(hostSetting: HostSetting, idiom: Idiom) -> Bool {
        self.hostSetting == hostSetting && (self.idiom == .any || self.idiom == idiom)
    }

    public static func selected(
        from looks: [SweepLook],
        hostSetting: HostSetting,
        idiom: Idiom,
        restrictedTo names: String? = nil
    ) -> [SweepLook] {
        let allowed = names.map {
            Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }
        return looks.filter { $0.applies(hostSetting: hostSetting, idiom: idiom) &&
            (allowed == nil || allowed!.contains($0.name)) }
    }
}
