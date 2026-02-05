import Foundation

struct AppVersion: Codable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(string: String) {
        let components = string.replacingOccurrences(of: "v", with: "")
                               .split(separator: ".")
                               .compactMap { Int($0) }

        guard components.count >= 2 else { return nil }
        self.major = components[0]
        self.minor = components[1]
        self.patch = components.count >= 3 ? components[2] : 0
    }

    var string: String {
        "\(major).\(minor).\(patch)"
    }

    var tagString: String {
        "v\(string)"
    }

    // Comparable conformance
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    // Get current app version from Bundle
    static var current: AppVersion {
        let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return AppVersion(string: versionString) ?? AppVersion(major: 1, minor: 0, patch: 0)
    }
}
