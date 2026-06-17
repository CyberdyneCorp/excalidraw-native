import Foundation

/// Validates an embeddable element's link against an allow-list of known hosts
/// and rewrites it to an embeddable URL (e.g. a YouTube watch URL → its
/// `/embed/` form). Only allow-listed hosts return a URL, so arbitrary pages
/// can't be embedded — mirrors the host gating in Excalidraw's `embeddable.ts`.
public enum EmbedAllowList {
    /// Hosts permitted for live embedding (suffix match, so subdomains count).
    public static let allowedHosts: Set<String> = [
        "youtube.com", "youtu.be", "player.vimeo.com", "vimeo.com",
        "figma.com", "codesandbox.io", "codepen.io", "excalidraw.com",
        "val.town", "giphy.com", "stackblitz.com"
    ]

    /// The embeddable URL for `link`, or `nil` when the host isn't allow-listed
    /// or the link is malformed.
    public static func embedURL(for link: String) -> URL? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              components.scheme == "https" || components.scheme == "http",
              let host = components.host?.lowercased(),
              isAllowed(host) else { return nil }

        if let youTube = youTubeEmbed(components, host: host) { return youTube }
        if let vimeo = vimeoEmbed(components, host: host) { return vimeo }
        // Allow-listed but no special transform: embed the URL as-is.
        return components.url
    }

    /// Whether `link`'s host is allow-listed (used to decide live vs placeholder).
    public static func isEmbeddable(_ link: String?) -> Bool {
        guard let link else { return false }
        return embedURL(for: link) != nil
    }

    private static func isAllowed(_ host: String) -> Bool {
        allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func youTubeEmbed(_ components: URLComponents, host: String) -> URL? {
        var videoID: String?
        if host.hasSuffix("youtu.be") {
            videoID = String(components.path.dropFirst()) // /<id>
        } else if host.hasSuffix("youtube.com") {
            if components.path == "/watch" {
                videoID = components.queryItems?.first { $0.name == "v" }?.value
            } else if components.path.hasPrefix("/embed/") {
                return components.url // already an embed URL
            }
        }
        guard let id = videoID, !id.isEmpty else { return nil }
        return URL(string: "https://www.youtube.com/embed/\(id)")
    }

    private static func vimeoEmbed(_ components: URLComponents, host: String) -> URL? {
        if host == "player.vimeo.com" { return components.url } // already embeddable
        guard host.hasSuffix("vimeo.com") else { return nil }
        let id = components.path.split(separator: "/").last.map(String.init) ?? ""
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://player.vimeo.com/video/\(id)")
    }
}
