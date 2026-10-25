// Check for Updates, for the copy downloaded from GitHub. It asks GitHub's API for the latest release and, if it's
// newer than this app, offers to download its DMG. Nothing is installed automatically: the user drags the new app
// over the old one, as when they first installed it.
// The Mac App Store copy is built with -D APPSTORE (./build.sh --appstore). There the App Store updates the app,
// and apps from the store must not update themselves, so this file compiles to nothing and the menu has no item.
#if !APPSTORE
import AppKit
import os

private let log = Logger(subsystem: "com.semicolonc.desktopcloth", category: "updates")

enum Updates {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/semicolonconsulting/desktopcloth/releases/latest")!
    private static let releasesPage = URL(string: "https://github.com/semicolonconsulting/desktopcloth/releases")!
    private static let automaticKey = "checkForUpdatesAutomatically"
    private static let lastCheckKey = "lastUpdateCheck"
    private static let skippedKey = "skippedVersion"
    // Automatic checks happen at most once a week, so GitHub hears from each Mac about 52 times a year.
    private static let interval: TimeInterval = 7 * 24 * 60 * 60
    private static var timer: Timer?
    private static var checking = false

    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // On unless the user turned it off in the menu.
    static var checksAutomatically: Bool {
        get { UserDefaults.standard.object(forKey: automaticKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: automaticKey)
            if newValue { checkIfDue() }
        }
    }

    // Called at launch. The app usually runs for days, so it also looks every few hours whether a week has passed.
    static func startAutomaticChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { checkIfDue() }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in checkIfDue() }
    }

    private static func checkIfDue() {
        guard checksAutomatically else { return }
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(last) >= interval { check(userInitiated: false) }
    }

    // A check from the menu always says what it found. An automatic one stays quiet unless there's a new version
    // the user hasn't chosen to skip.
    static func check(userInitiated: Bool) {
        guard !checking else { return }
        checking = true
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("desktopcloth/\(current)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let release = data.flatMap { try? JSONDecoder().decode(Release.self, from: $0) }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                checking = false
                guard let release, status == 200 else {
                    log.error("update check failed: status \(status, privacy: .public), \(error?.localizedDescription ?? "unreadable reply", privacy: .public)")
                    if userInitiated { showFailure() }
                    return
                }
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
                log.info("latest release \(release.version, privacy: .public), running \(current, privacy: .public)")
                if isVersion(release.version, newerThan: current) {
                    if userInitiated || UserDefaults.standard.string(forKey: skippedKey) != release.version {
                        offer(release)
                    }
                } else if userInitiated {
                    showUpToDate()
                }
            }
        }.resume()
    }

    private static func offer(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "desktopcloth \(release.version) is available"
        var info = "You have version \(current)."
        if let summary = release.summary { info += "\n\n" + summary }
        alert.informativeText = info + "\n\nDownload the new version, quit desktopcloth, then drag it onto Applications to replace this one."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: NSWorkspace.shared.open(release.downloadURL)
        case .alertThirdButtonReturn: UserDefaults.standard.set(release.version, forKey: skippedKey)
        default: break
        }
    }

    private static func showUpToDate() {
        let alert = NSAlert()
        alert.messageText = "desktopcloth is up to date"
        alert.informativeText = "Version \(current) is the latest version."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func showFailure() {
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = "Check your internet connection and try again, or see the releases page on GitHub."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Releases Page")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(releasesPage) }
    }

    // Compares dotted version numbers part by part, so 1.10 is newer than 1.9 and 1.2 equals 1.2.0.
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    // The parts of GitHub's release JSON that are used. Tags are named like v1.2.1.
    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let html_url: URL
        let body: String?
        let assets: [Asset]

        var version: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
        // The DMG if the release has one, otherwise the release page.
        var downloadURL: URL { assets.first { $0.name.hasSuffix(".dmg") }?.browser_download_url ?? html_url }
        // The release notes' first paragraph, which says in a sentence what's new.
        var summary: String? {
            let first = body?.components(separatedBy: "\n\n").first?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let first, !first.isEmpty, !first.hasPrefix("#") else { return nil }
            return first
        }
    }
}
#endif
