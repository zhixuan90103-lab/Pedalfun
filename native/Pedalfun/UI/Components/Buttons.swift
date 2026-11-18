import SwiftUI
import UIKit

struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Round icon button: one flat disc.
struct RoundButton: View {
    var icon: String
    var label: String
    var fill: Color
    var tint: Color = .white
    var size: CGFloat = Metrics.button
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(tint)
                }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// Capsule button for confirming, to read differently from the round
/// start / pause buttons.
struct CapsuleButton: View {
    var icon: String
    var label: String
    var fill: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(fill)
                .frame(width: Metrics.capsule.width, height: Metrics.capsule.height)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .accessibilityLabel(label)
    }
}

struct IconButton: View {
    var icon: String
    var label: String
    var action: () -> Void

    @Environment(\.palette) private var pal

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(pal.ink)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .accessibilityLabel(label)
    }
}

/// Press-and-hold button: a ring outside the disc fills while held and the
/// action fires when it completes. An early release calls `onShort`.
///
/// Touches are read straight from UIKit (`touchesBegan`), not through a
/// SwiftUI gesture: gestures wait to be told apart from other gestures before
/// they report, which made the ring and the haptic start late. This way the
/// hold is timed from first contact.
struct HoldButton: View {
    var icon: String
    var label: String
    var fill: Color
    var tint: Color = .white
    var ring: Color
    var duration: Double = Motion.holdDuration
    var onShort: () -> Void = {}
    var action: () -> Void

    @Environment(SettingsStore.self) private var settings
    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var fire: Task<Void, Never>?
    /// Milliseconds from the finger touching the glass to `begin` running (last press).
    @State private var latencyMs = -1

    var body: some View {
        let size = Metrics.button
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(tint)
            }
            .scaleEffect(holding ? 0.94 : 1)
            // Scoped to the disc only, so it cannot re-time the ring.
            .animation(Motion.press, value: holding)
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ring, style: StrokeStyle(lineWidth: Metrics.holdRingWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size + Metrics.holdRingGap * 2, height: size + Metrics.holdRingGap * 2)
            }
            .overlay {
                TouchCatcher(onDown: begin, onUp: end)
                    .frame(width: size + Metrics.holdTouchSlop * 2, height: size + Metrics.holdTouchSlop * 2)
            }
            .onAppear { Haptics.warmUp() }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityIdentifier("holdButton")
            .accessibilityValue("\(latencyMs)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }

    private func begin(touchTime: TimeInterval) {
        guard !holding else { return }
        latencyMs = Int(((ProcessInfo.processInfo.systemUptime - touchTime) * 1000).rounded())
        Haptics.tap(.light, settings)
        holding = true
        withAnimation(.linear(duration: duration)) { progress = 1 }
        fire = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            Haptics.tap(.heavy, settings)
            fire = nil
            holding = false
            progress = 0
            action()
        }
    }

    private func end(cancelled: Bool) {
        guard let pending = fire else { return }
        pending.cancel()
        fire = nil
        holding = false
        withAnimation(Motion.holdRelease) { progress = 0 }
        if !cancelled { onShort() }
    }
}

/// Reports touch-down and touch-up with no recognition delay.
private struct TouchCatcher: UIViewRepresentable {
    /// `touchTime`: when the touch hit the screen, in system uptime.
    var onDown: (_ touchTime: TimeInterval) -> Void
    var onUp: (_ cancelled: Bool) -> Void

    func makeUIView(context: Context) -> TouchView {
        let v = TouchView()
        v.backgroundColor = .clear
        v.isExclusiveTouch = true
        return v
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onDown = onDown
        view.onUp = onUp
    }

    final class TouchView: UIView {
        var onDown: (TimeInterval) -> Void = { _ in }
        var onUp: (Bool) -> Void = { _ in }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            onDown(touches.first?.timestamp ?? ProcessInfo.processInfo.systemUptime)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            onUp(false)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            onUp(true)
        }
    }
}
