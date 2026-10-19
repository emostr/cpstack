import AppKit

/// Interface language override. CPStack follows the system language by default;
/// a choice made in Settings is stored in the app's own `AppleLanguages`
/// and takes effect after a relaunch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", russian = "ru"

    var id: Self { self }

    private static let key = "AppleLanguages"

    static var current: AppLanguage {
        // Only the app domain matters here: the global domain holds the system list.
        let languages = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?[key] as? [String]
        guard let first = languages?.first else { return .system }
        return first.hasPrefix("ru") ? .russian : .english
    }

    func apply() {
        switch self {
        case .system: UserDefaults.standard.removeObject(forKey: Self.key)
        case .english, .russian: UserDefaults.standard.set([rawValue], forKey: Self.key)
        }
    }

    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
