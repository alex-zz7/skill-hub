import AppKit
import Foundation

/// In-app language override. macOS resolves bundle localizations from `AppleLanguages` at launch,
/// so switching writes that default and relaunches; "system" removes the override.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
    case ja = "ja"
    case ko = "ko"
    case es = "es"
    case fr = "fr"
    case de = "de"

    var id: String { rawValue }

    /// Shown in its own script so a user stuck in the wrong language can still find theirs.
    var title: String {
        switch self {
        case .system: String(localized: "跟随系统")
        case .zhHans: "简体中文"
        case .zhHant: "繁體中文"
        case .en: "English"
        case .ja: "日本語"
        case .ko: "한국어"
        case .es: "Español"
        case .fr: "Français"
        case .de: "Deutsch"
        }
    }

    private static let key = "AppleLanguages"

    static var current: AppLanguage {
        guard let list = UserDefaults.standard.array(forKey: key) as? [String], let first = list.first else {
            return .system
        }
        return AppLanguage.allCases.first { $0 != .system && first.hasPrefix($0.rawValue) } ?? .system
    }

    /// Persists the choice and relaunches so every view picks up the new bundle localization.
    static func apply(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
        UserDefaults.standard.synchronize()
        relaunch()
    }

    private static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
