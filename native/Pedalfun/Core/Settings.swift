import Foundation
import Observation
import SwiftUI

enum Units: String, CaseIterable {
    case km, mi
}

enum ThemePref: String, CaseIterable {
    case dark, light, system

    var scheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// User settings, persisted in UserDefaults.
@Observable
final class SettingsStore {
    var units: Units { didSet { save("units", units.rawValue) } }
    var theme: ThemePref { didSet { save("theme", theme.rawValue) } }
    var autoPause: Bool { didSet { save("autoPause", autoPause) } }
    var keepAwake: Bool { didSet { save("keepAwake", keepAwake) } }
    var haptics: Bool { didSet { save("haptics", haptics) } }

    init() {
        let d = UserDefaults.standard
        units = Units(rawValue: d.string(forKey: "units") ?? "") ?? .km
        theme = ThemePref(rawValue: d.string(forKey: "theme") ?? "") ?? .dark
        autoPause = d.object(forKey: "autoPause") as? Bool ?? true
        keepAwake = d.object(forKey: "keepAwake") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
    }

    private func save(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }

    var fmt: Fmt { Fmt(units: units) }
}
