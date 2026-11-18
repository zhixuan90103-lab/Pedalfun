import UIKit

enum Haptics {
    // Reused and kept warm: a freshly created generator answers its first tap late.
    private static let generators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [
        .light: UIImpactFeedbackGenerator(style: .light),
        .medium: UIImpactFeedbackGenerator(style: .medium),
        .heavy: UIImpactFeedbackGenerator(style: .heavy),
    ]

    static func warmUp() {
        generators.values.forEach { $0.prepare() }
    }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle, _ settings: SettingsStore) {
        guard settings.haptics, let g = generators[style] else { return }
        g.impactOccurred()
        g.prepare()
    }
}
