import Foundation
import Observation

/// User preferences persisted in `UserDefaults`.
@Observable
final class AppSettings {
    enum PanelPosition: String, CaseIterable, Identifiable {
        case caret, mouse, center
        var id: Self { self }
    }

    static let historyLimits = [25, 50, 100, 200, 500, 1000]

    @ObservationIgnored private let defaults: UserDefaults

    var shortcut: KeyShortcut {
        didSet {
            save(shortcut, forKey: Keys.shortcut)
            shortcutIsAvailable = HotKeyCenter.shared.register(shortcut)
        }
    }

    /// `false` when another app already owns the chosen shortcut.
    var shortcutIsAvailable = true

    var panelPosition: PanelPosition {
        didSet { defaults.set(panelPosition.rawValue, forKey: Keys.panelPosition) }
    }

    /// Simulate ⌘V in the frontmost app after an item is chosen.
    var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) }
    }

    var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    var saveImages: Bool {
        didSet { defaults.set(saveImages, forKey: Keys.saveImages) }
    }

    /// Skip content that password managers mark as concealed.
    var ignoreConfidential: Bool {
        didSet { defaults.set(ignoreConfidential, forKey: Keys.ignoreConfidential) }
    }

    var isPaused: Bool {
        didSet { defaults.set(isPaused, forKey: Keys.isPaused) }
    }

    var hasLaunchedBefore: Bool {
        didSet { defaults.set(hasLaunchedBefore, forKey: Keys.hasLaunchedBefore) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.panelPosition: PanelPosition.caret.rawValue,
            Keys.autoPaste: true,
            Keys.historyLimit: 200,
            Keys.saveImages: true,
            Keys.ignoreConfidential: true,
            Keys.isPaused: false,
            Keys.hasLaunchedBefore: false,
        ])
        shortcut = Self.load(KeyShortcut.self, from: defaults, forKey: Keys.shortcut) ?? .default
        panelPosition = PanelPosition(rawValue: defaults.string(forKey: Keys.panelPosition) ?? "") ?? .caret
        autoPaste = defaults.bool(forKey: Keys.autoPaste)
        historyLimit = defaults.integer(forKey: Keys.historyLimit)
        saveImages = defaults.bool(forKey: Keys.saveImages)
        ignoreConfidential = defaults.bool(forKey: Keys.ignoreConfidential)
        isPaused = defaults.bool(forKey: Keys.isPaused)
        hasLaunchedBefore = defaults.bool(forKey: Keys.hasLaunchedBefore)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, forKey key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private enum Keys {
        static let shortcut = "shortcut"
        static let panelPosition = "panelPosition"
        static let autoPaste = "autoPaste"
        static let historyLimit = "historyLimit"
        static let saveImages = "saveImages"
        static let ignoreConfidential = "ignoreConfidential"
        static let isPaused = "isPaused"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }
}
