import Foundation
import AppKit
import Security

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

    private let settingsManager: SettingsManager
    private static let releasesAPI = URL(string: "https://api.github.com/repos/arsh342/TextGrab/releases/latest")!
    private static let dailyInterval: TimeInterval = 86_400
    private static let expectedBundleID = "com.textgrab.TextGrab"
    // Set this to your Developer ID Team ID for distribution builds
    // Can be overridden via TEAM_ID environment variable or Info.plist
    private static let expectedTeamID: String? = {
        if let envTeamID = ProcessInfo.processInfo.environment["TEAM_ID"], !envTeamID.isEmpty {
            return envTeamID
        }
        // Try to read from Info.plist
        if let plistTeamID = Bundle.main.object(forInfoDictionaryKey: "TEAM_ID") as? String, !plistTeamID.isEmpty {
            return plistTeamID
        }
        return nil
    }()

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    /// Returns the available update, or nil when already up to date. When run
    /// automatically this checks at most once per day.
    func checkForUpdates(automatically: Bool = false) async -> UpdateInfo? {
        if automatically {
            guard settingsManager.checkForUpdatesAutomatically else { return nil }
            if let last = settingsManager.lastUpdateCheckDate,
               Date().timeIntervalSince(last) < Self.dailyInterval {
                return nil
            }
        }
        guard !isChecking else { return nil }
        isChecking = true
        defer { isChecking = false }
        // Only record successful check date after validation
        // settingsManager.lastUpdateCheckDate = Date() - MOVED TO AFTER SUCCESS

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
            // Record successful check only after validating response
            settingsManager.lastUpdateCheckDate = Date()
            return info
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Downloads the DMG into Downloads, verifies its signature, and opens it for drag-to-install;
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

                // Verify the DMG before opening
                if await verifyDMG(at: destination) {
                    NSWorkspace.shared.open(destination)
                    return
                } else {
                    Logger.shared.error("DMG verification failed for \(info.version)")
                    // Don't open unverified DMG, fall through to release page
                }
            } catch {
                Logger.shared.error("Update download failed: \(error.localizedDescription)")
            }
        }
        NSWorkspace.shared.open(info.releaseURL)
    }

    /// Verifies the downloaded DMG contains a properly signed and notarized app.
    private func verifyDMG(at dmgURL: URL) async -> Bool {
        // Mount the DMG
        let mountPoint = FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TextGrabVerify-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        } catch {
            Logger.shared.error("Failed to create mount point: \(error)")
            return false
        }

        let mountProcess = Process()
        mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mountProcess.arguments = ["attach", dmgURL.path, "-mountpoint", mountPoint.path, "-nobrowse", "-readonly"]

        do {
            try mountProcess.run()
            mountProcess.waitUntilExit()
            guard mountProcess.terminationStatus == 0 else {
                Logger.shared.error("Failed to mount DMG")
                return false
            }
        } catch {
            Logger.shared.error("Mount failed: \(error)")
            return false
        }

        defer {
            // Unmount
            let unmountProcess = Process()
            unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmountProcess.arguments = ["detach", mountPoint.path, "-force"]
            try? unmountProcess.run()
            unmountProcess.waitUntilExit()
            try? FileManager.default.removeItem(at: mountPoint)
        }

        // Find the app bundle in the mounted DMG
        guard let appURL = findAppBundle(in: mountPoint) else {
            Logger.shared.error("No app bundle found in DMG")
            return false
        }

        // Verify code signature
        guard verifyCodeSignature(appURL: appURL) else {
            Logger.shared.error("Code signature verification failed")
            return false
        }

        // Verify bundle identifier
        guard verifyBundleIdentifier(appURL: appURL) else {
            Logger.shared.error("Bundle identifier mismatch")
            return false
        }

        // Verify Team ID if configured
        if let expectedTeamID = Self.expectedTeamID {
            guard verifyTeamID(appURL: appURL, expectedTeamID: expectedTeamID) else {
                Logger.shared.error("Team ID mismatch")
                return false
            }
        }

        // Verify notarization (stapled ticket)
        guard verifyNotarization(appURL: appURL) else {
            Logger.shared.error("Notarization verification failed")
            return false
        }

        Logger.shared.info("DMG verification passed for \(appURL.lastPathComponent)")
        return true
    }

    private func findAppBundle(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return nil
        }
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "app" {
                return fileURL
            }
        }
        return nil
    }

    private func verifyCodeSignature(appURL: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            Logger.shared.error("codesign verify failed: \(error)")
            return false
        }
    }

    private func verifyBundleIdentifier(appURL: URL) -> Bool {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let infoDict = NSDictionary(contentsOf: infoPlistURL),
              let bundleID = infoDict["CFBundleIdentifier"] as? String else {
            return false
        }
        return bundleID == Self.expectedBundleID
    }

    private func verifyTeamID(appURL: URL, expectedTeamID: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-d", "-vvv", appURL.path]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // Parse TeamIdentifier from codesign output
            for line in output.components(separatedBy: .newlines) {
                if line.contains("TeamIdentifier=") {
                    let teamID = line.replacingOccurrences(of: "TeamIdentifier=", with: "").trimmingCharacters(in: .whitespaces)
                    return teamID == expectedTeamID
                }
            }
        } catch {
            Logger.shared.error("codesign team ID check failed: \(error)")
        }
        return false
    }

    private func verifyNotarization(appURL: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/spctl")
        process.arguments = ["--assess", "--type", "execute", "--verbose", appURL.path]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            Logger.shared.error("spctl assess failed: \(error)")
            return false
        }
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
