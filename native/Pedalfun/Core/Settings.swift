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
    /// Rider profile, only used to estimate energy. Unset until filled in.
    var sex: Sex? { didSet { save("sex", sex?.rawValue) } }
    /// centimetres
    var height: Double? { didSet { save("height", height) } }
    /// kilograms
    var weight: Double? { didSet { save("weight", weight) } }

    init() {
        let d = UserDefaults.standard
        units = Units(rawValue: d.string(forKey: "units") ?? "") ?? .km
        theme = ThemePref(rawValue: d.string(forKey: "theme") ?? "") ?? .dark
        autoPause = d.object(forKey: "autoPause") as? Bool ?? true
        keepAwake = d.object(forKey: "keepAwake") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        sex = Sex(rawValue: d.string(forKey: "sex") ?? "")
        height = d.double(forKey: "height") > 0 ? d.double(forKey: "height") : nil
        weight = d.double(forKey: "weight") > 0 ? d.double(forKey: "weight") : nil
        loaded = true
    }

    /// Optionals start out as nil, so assigning them in `init` already counts
    /// as a change. Without this, values read from launch arguments would be
    /// written back and outlive the launch.
    @ObservationIgnored private var loaded = false

    var profile: Profile { Profile(sex: sex, height: height, weight: weight) }

    private func save(_ key: String, _ value: Any?) {
        guard loaded else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    var fmt: Fmt { Fmt(units: units) }
}
