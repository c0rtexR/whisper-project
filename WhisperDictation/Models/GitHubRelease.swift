import Foundation

struct GitHubRelease: Codable, Equatable {
    let tagName: String
    let name: String
    let body: String
    let assets: [ReleaseAsset]
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body, assets
        case publishedAt = "published_at"
    }

    var version: AppVersion? {
        AppVersion(string: tagName)
    }

    var sha256Checksum: String? {
        // Extract SHA256 from body using regex
        let pattern = "SHA256[:\\s]+([a-fA-F0-9]{64})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: body, options: [], range: NSRange(body.startIndex..., in: body)),
              let range = Range(match.range(at: 1), in: body) else {
            return nil
        }
        return String(body[range])
    }

    var zipAsset: ReleaseAsset? {
        assets.first { $0.name.hasSuffix(".zip") }
    }
}

struct ReleaseAsset: Codable, Equatable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name, size
        case browserDownloadUrl = "browser_download_url"
    }
}
