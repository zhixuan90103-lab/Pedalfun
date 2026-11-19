import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

/// Dark slate with a green "go" and a red "stop"; nothing else carries colour
/// except the amber GPS warning.
struct Palette {
    var bg, surface, ink, ink2, ink3, dim: Color
    var go, goText, stop: Color
    /// speed field on the riding screen: moving / auto-paused / paused
    var field, fieldAuto, fieldPaused: Color
    var warn, flat: Color

    static let dark = Palette(
        bg: Color(hex: 0x363744), surface: Color(hex: 0x434451), ink: .white,
        ink2: Color(hex: 0xa9aab4), ink3: Color(hex: 0x7f808b), dim: Color(hex: 0x8a8b95),
        go: Color(hex: 0x2bd78e), goText: Color(hex: 0x2bd78e), stop: Color(hex: 0xf25050),
        field: Color(hex: 0x1fc480), fieldAuto: Color(hex: 0x5c5d6b), fieldPaused: Color(hex: 0x26272f),
        warn: Color(hex: 0xffc94a), flat: Color(hex: 0x565766)
    )

    static let light = Palette(
        bg: Color(hex: 0xf3f4f6), surface: Color(hex: 0xe4e6ea), ink: Color(hex: 0x2b2c36),
        ink2: Color(hex: 0x6b6d78), ink3: Color(hex: 0xa0a2ac), dim: Color(hex: 0xa6a8b2),
        go: Color(hex: 0x1fc47e), goText: Color(hex: 0x0f9a60), stop: Color(hex: 0xee4b4b),
        field: Color(hex: 0x1fc480), fieldAuto: Color(hex: 0x9a9da8), fieldPaused: Color(hex: 0x2b2c36),
        warn: Color(hex: 0xc98a00), flat: Color(hex: 0xc9ccd3)
    )

    /// GPS warning on the speed field: the same in both themes, since the field is.
    static let warnOnField = Color(hex: 0xffc94a)
    static let warnChip = Color(hex: 0x24252e)

    func band(_ band: GradeBand) -> Color {
        switch band {
        case .up: return stop
        case .down: return go
        case .flat: return flat
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.dark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Shared measurements, so every screen has the same top bar, the same
/// side margin, and its main button at the same height.
enum Metrics {
    static let side: CGFloat = 24
    static let topBar: CGFloat = 52
    /// Height of the bottom action zone above the home indicator. The button
    /// is centred in it, which puts it in easy thumb reach.
    static let actionBar: CGFloat = 148
    static let button: CGFloat = 80
    /// between two buttons side by side (play and stop)
    static let buttonGap: CGFloat = 84
    /// the confirming capsule on the summary screen
    static let capsule = CGSize(width: 184, height: 64)
    /// ring of a hold button: gap outside the disc, and stroke
    static let holdRingGap: CGFloat = 7
    static let holdRingWidth: CGFloat = 4.5
    /// touch area beyond a hold button's disc
    static let holdTouchSlop: CGFloat = 12
    /// riding screen grid
    static let gridGap: CGFloat = 12
    /// padding of the grade capsule around its text
    static let capsulePad = CGSize(width: 16, height: 8)
}

/// Numeral sizes. One size per role; screens never invent their own.
enum TypeScale {
    /// current speed on the riding screen
    static let hero: CGFloat = 156
    /// the one headline number of a screen (week distance, ride distance)
    static let display: CGFloat = 92
    /// riding screen, tier 1: time and distance
    static let primary: CGFloat = 50
    /// summary statistics
    static let stat: CGFloat = 36
    /// grade, and the distance of a history row
    static let emphasis: CGFloat = 32
    /// riding screen, tier 2: average, max, climb, altitude
    static let secondary: CGFloat = 26
    /// numbers inside a compact card
    static let card: CGFloat = 24
    /// numbers set inline with small text
    static let inline: CGFloat = 19
    /// the speed unit beside the hero number, the wordmark
    static let unit: CGFloat = 22
    /// small labels and units
    static let label: CGFloat = 13
}

/// Every animation in the app. Screens reference these by role, so timing
/// stays consistent and can be tuned in one place.
enum Motion {
    /// pressing any button
    static let press = Animation.spring(response: 0.3, dampingFraction: 0.55)
    /// pushing / popping a screen
    static let push = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.26)
    static let pushOffset: CGFloat = 36
    /// start: green floods out of the start button…
    static let floodDuration = 0.43
    static let flood = Animation.timingCurve(0.5, 0, 0.2, 1, duration: floodDuration)
    /// …then retracts into the speed field
    static let settleDuration = 0.4
    static let settle = Animation.timingCurve(0.3, 0, 0.1, 1, duration: settleDuration)
    /// content rising into place
    static let rise = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.42)
    /// stagger between the riding screen's tiers
    static let riseStep = 0.06
    /// the pause button's own entrance, after the tiers
    static let pauseEnter = Animation.spring(response: 0.45, dampingFraction: 0.6).delay(0.3)
    /// pause ⇄ play + stop
    static let split = Animation.spring(response: 0.36, dampingFraction: 0.6)
    /// how long the stop button must be held
    static let holdDuration = 0.6
    static let holdRelease = Animation.easeOut(duration: 0.25)
    /// colour changes of the speed field and the grade capsule
    static let stateChange = Animation.easeInOut(duration: 0.35)
    static let gradePop = Animation.spring(response: 0.42, dampingFraction: 0.5)
    /// selection sliding in a picker or switch
    static let select = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let toast = Animation.easeOut(duration: 0.18)
    /// a deleted history row closing up
    static let rowRemove = Animation.easeOut(duration: 0.25)
    /// one-off reveals: week bars growing, elevation profile wiping in
    static let barGrow = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5)
    static let profileWipe = Animation.timingCurve(0.3, 0, 0.2, 1, duration: 0.7).delay(0.12)
}

extension Font {
    /// Barlow Condensed: the numeral face.
    static func num(_ size: CGFloat, bold: Bool = true) -> Font {
        // Tabular digits: a changing number must not shift its neighbours.
        .custom(bold ? "BarlowCondensed-Bold" : "BarlowCondensed-SemiBold", fixedSize: size).monospacedDigit()
    }
}
