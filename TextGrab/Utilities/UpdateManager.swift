import Foundation
import AppKit

@MainActor
final class UpdateManager: ObservableObject {
    struct UpdateInfo: Equatable {
        let version: String
        let releaseURL: URL
        let downloadURL: URL?
    }

    enum UpdateState: Equatable {
        case idle
        case upToDate
        case available(UpdateInfo)
        case failed(String)
    }

    @Published var state: UpdateState = .idle
    @Published private(set) var isChecking = false

    private static let releasesAPI = URL(string: "https://api.github.com/repos/arsh342/TextGrab/releases/latest")!
    private static let dailyInterval: TimeInterval = 86_400

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Returns the available update, or nil when already up to date. When run
    /// automatically this checks at most once per day.
    func checkForUpdates(automatically: Bool = false) async -> UpdateInfo? {
        if automatically {
            guard SettingsManager.shared.checkForUpdatesAutomatically else { return nil }
            if let last = SettingsManager.shared.lastUpdateCheckDate,
               Date().timeIntervalSince(last) < Self.dailyInterval {
                return nil
            }
        }
        guard !isChecking else { return nil }
        isChecking = true
        defer { isChecking = false }
        SettingsManager.shared.lastUpdateCheckDate = Date()

        do {
            var request = URLRequest(url: Self.releasesAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let tag = release.tagName else { return nil }
            let latestVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

            guard Self.isVersion(latestVersion, newerThan: currentVersion) else {
                state = .upToDate
                return nil
            }

            let info = UpdateInfo(
                version: latestVersion,
                releaseURL: release.htmlURL
                    ?? URL(string: "https://github.com/arsh342/TextGrab/releases/latest")!,
                downloadURL: release.assets?.first(where: { $0.name?.hasSuffix(".dmg") == true })?.browserDownloadURL
            )
            state = .available(info)
            return info
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Downloads the DMG into Downloads and opens it for drag-to-install;
    /// falls back to the release page in the browser.
    func downloadAndOpenUpdate() async {
        guard case .available(let info) = state else { return }
        if let downloadURL = info.downloadURL {
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
                let destination = FileManager.default
                    .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("TextGrab-\(info.version).dmg")
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: tempURL, to: destination)
                NSWorkspace.shared.open(destination)
                return
            } catch {
                Logger.shared.error("Update download failed: \(error.localizedDescription)")
            }
        }
        NSWorkspace.shared.open(info.releaseURL)
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(candidateParts.count, currentParts.count) {
            let new = index < candidateParts.count ? candidateParts[index] : 0
            let old = index < currentParts.count ? currentParts[index] : 0
            if new != old { return new > old }
        }
        return false
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String?
    let htmlURL: URL?
    let assets: [Asset]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }

    struct Asset: Decodable {
        let name: String?
        let browserDownloadURL: URL?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}
