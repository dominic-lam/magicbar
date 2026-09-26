import Foundation

/// Asks GitHub whether a newer release exists — at launch, then once a day — and does nothing
/// else. It never downloads or installs anything.
///
/// **Tell, don't install.** An app that replaces its own code is the most dangerous thing a
/// small utility can do: whoever controls the GitHub account would control every copy. Release
/// builds are also ad-hoc signed, so macOS treats each version as a different app. Opening the
/// Releases page leaves the decision, and the Gatekeeper check, with the user.
///
/// This is the app's only network access, which is why it sits behind a setting and why the
/// request carries nothing but its own version in the `User-Agent`.
@MainActor
final class UpdateChecker: ObservableObject {
    /// Always the fixed Releases page, never a URL taken from the response, so a tampered
    /// release cannot send the user anywhere else.
    nonisolated static let downloadURL = URL(string: "https://github.com/dominic-lam/magicbar/releases/latest")!
    nonisolated static let currentVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private nonisolated static let latestAPI = URL(string: "https://api.github.com/repos/dominic-lam/magicbar/releases/latest")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.app.set(isEnabled, forKey: "checkForUpdates")
            if isEnabled { Task { await check() } } else { available = nil }
        }
    }

    /// The newer version's number without the leading "v", or nil when up to date or unknown.
    @Published private(set) var available: String?

    /// The result of a "Check now" click, shown beside the button for a few seconds. Automatic
    /// checks never set it: a daily "Up to date" nobody asked for is noise.
    @Published private(set) var status: String?
    @Published private(set) var isChecking = false

    private var isSimulated = false
    private var timer: Timer?
    private var clearStatusTask: Task<Void, Never>?

    init() {
        UserDefaults.app.register(defaults: ["checkForUpdates": true])
        isEnabled = UserDefaults.app.bool(forKey: "checkForUpdates")

        let arguments = ProcessInfo.processInfo.arguments
        // Shows the notice without touching the network, so the footer can be checked and
        // screenshotted before any newer release exists.
        if let i = arguments.firstIndex(of: "--simulate-update"), arguments.count > i + 1 {
            available = arguments[i + 1]
            isSimulated = true
            return
        }
        // Diagnostic runs exit within a second and have no business making a request.
        if arguments.contains(where: { $0.hasPrefix("--dump-") || $0 == "--check-updates" }) { return }

        Task { await check() }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    /// `manual` is a click on "Check now". It runs even with automatic checks switched off —
    /// the click is the permission — and reports its result in `status`.
    func check(manual: Bool = false) async {
        guard isEnabled || manual, !isChecking else { return }
        if isSimulated {
            if manual { show("Simulated — no request made") }
            return
        }
        isChecking = true
        if manual { clearStatusTask?.cancel(); status = "Checking…" }
        defer { isChecking = false }

        do {
            let latest = try await Self.fetchLatestVersion()
            available = latest.flatMap { Self.isNewer($0, than: Self.currentVersion) ? $0 : nil }
            NSLog("[magicbar] update check manual=\(manual) current=\(Self.currentVersion) latest=\(latest ?? "none") available=\(available ?? "no")")
            // A newer version already shows as the footer link, so only "nothing newer" needs
            // saying here.
            if manual { show(available == nil ? "Up to date" : nil) }
        } catch {
            // A failed check changes nothing: an offline Mac is not a reason to hide a notice
            // that an earlier check found.
            NSLog("[magicbar] update check manual=\(manual) failed: \(error.localizedDescription)")
            if manual { show("Couldn't connect") }
        }
    }

    /// Shows a manual check's result, then clears it so a stale "Up to date" does not sit
    /// there for days.
    private func show(_ message: String?) {
        status = message
        clearStatusTask?.cancel()
        guard message != nil else { return }
        clearStatusTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.status = nil
        }
    }

    /// The newest published, non-prerelease version, or nil when there is none.
    nonisolated static func fetchLatestVersion() async throws -> String? {
        var request = URLRequest(url: latestAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // Replaces the default agent, which would also report the macOS and Darwin versions.
        request.setValue("magicbar/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode
        // GitHub answers 404 when every release is a prerelease. That is "nothing newer",
        // not a failure.
        if status == 404 { return nil }
        guard status == 200 else { throw URLError(.badServerResponse) }

        struct Release: Decodable { let tag_name: String }
        let tag = try JSONDecoder().decode(Release.self, from: data).tag_name
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Semantic version order: "1.10.0" is newer than "1.9.2", and a prerelease sorts below
    /// its release, so "1.2.0" is newer than "1.2.0-rc.1". A pure function so
    /// `--check-updates` can print its answers.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parse(_ version: String) -> (numbers: [Int], isPrerelease: Bool) {
            let trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
            let parts = trimmed.split(separator: "-", maxSplits: 1)
            let numbers = parts.first.map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? []
            return (numbers, parts.count > 1)
        }
        let a = parse(candidate), b = parse(current)
        for i in 0..<max(a.numbers.count, b.numbers.count) {
            let x = i < a.numbers.count ? a.numbers[i] : 0
            let y = i < b.numbers.count ? b.numbers[i] : 0
            if x != y { return x > y }
        }
        return !a.isPrerelease && b.isPrerelease
    }
}
