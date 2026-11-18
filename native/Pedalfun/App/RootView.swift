import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        Themed {
            RootContent()
        }
        .preferredColorScheme((model.reviewTheme ?? settings.theme).scheme)
    }
}

/// Resolves the palette from the effective colour scheme and injects it.
private struct Themed<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content

    var body: some View {
        content.environment(\.palette, scheme == .dark ? .dark : .light)
    }
}

private struct RootContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var pal

    var body: some View {
        ZStack {
            pal.bg.ignoresSafeArea()

            screen
                .id(model.route.key)
                .transition(.asymmetric(
                    insertion: .offset(x: model.forward ? Motion.pushOffset : -Motion.pushOffset).combined(with: .opacity),
                    removal: .opacity
                ))

            RevealOverlay()

            if let text = model.toast {
                ToastView(text: text)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
    }

    @ViewBuilder private var screen: some View {
        switch model.route {
        case .home: HomeView()
        case .ride: RideView()
        case .history: HistoryView()
        case .settings: SettingsView()
        case .summary(let ride, let live, let fromHistory):
            SummaryView(ride: ride, live: live, fromHistory: fromHistory)
        }
    }
}

private struct RevealOverlay: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var pal

    var body: some View {
        GeometryReader { geo in
            switch model.reveal {
            case .none:
                Color.clear
            case .flood(let expanded):
                let d = model.revealRadius * 2
                Circle()
                    .fill(pal.field)
                    .frame(width: d, height: d)
                    .scaleEffect(expanded ? 2.2 * hypot(geo.size.width, geo.size.height) / d : 1)
                    .position(model.revealOrigin)
            case .settle(let retracted):
                pal.field
                    .frame(height: retracted ? model.heroBottom : geo.size.height)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
