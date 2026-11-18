import SwiftUI

/// Top bar shared by every screen except the riding screen.
struct TopBar<Leading: View, Trailing: View>: View {
    var title: String = ""
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.palette) private var pal

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(pal.ink)
            HStack(spacing: 4) {
                leading
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 14)
        .frame(height: Metrics.topBar)
    }
}

/// The frame every screen is built in: header, content, and an optional
/// bottom action zone. Using it is what keeps the top bar, the margins and
/// the main button at the same place on every screen.
struct ScreenScaffold<Header: View, Content: View, Actions: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            header
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            if Actions.self != EmptyView.self {
                ActionBar { actions }
            }
        }
    }
}

extension ScreenScaffold where Actions == EmptyView {
    /// A screen with no bottom action zone (lists, settings).
    init(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.init(header: header, content: content, actions: { EmptyView() })
    }
}

/// Bottom action zone: the same height on every screen, so the main button
/// is always in the same place.
struct ActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Metrics.buttonGap) {
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.actionBar)
    }
}

struct ToastView: View {
    var text: String

    @Environment(\.palette) private var pal

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(pal.bg)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: true, vertical: true)
                .background(pal.ink, in: RoundedRectangle(cornerRadius: 18))
                .padding(.bottom, Metrics.actionBar + 8)
        }
        .allowsHitTesting(false)
    }
}
