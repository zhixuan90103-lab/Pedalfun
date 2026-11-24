import SwiftUI

/// A finished ride. `live` = just ended (already saved): one capsule button
/// to confirm. Otherwise it is a history detail with back and export.
struct SummaryView: View {
    var ride: Ride
    var live: Bool
    var fromHistory: Bool

    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var pal

    @State private var wiped = false

    var body: some View {
        let p = SummaryPresentation(ride, live: live, profile: settings.profile, settings.fmt)

        ScreenScaffold {
            TopBar(title: p.topTitle) {
                if !live {
                    IconButton(icon: "chevron.left", label: "返回") { model.go(fromHistory ? .history : .home) }
                }
            } trailing: {
                EmptyView()
            }
        } content: {
            // One screen, no scrolling: the profile flexes, the rows share what is left.
            VStack(alignment: .leading, spacing: 0) {
                Text(p.name)
                    .font(.text(TextScale.body))
                    .foregroundStyle(pal.ink2)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Num(p.distText, TypeScale.display)
                    Text(p.distUnit).font(.text(TextScale.title)).foregroundStyle(pal.ink2)
                }
                .padding(.top, 8)

                ElevationProfile(samples: ride.samples, maxSeg: 64)
                    .frame(minHeight: Metrics.profileHeight.lowerBound, maxHeight: Metrics.profileHeight.upperBound)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    // Wipes in from the left once.
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().frame(width: wiped ? geo.size.width : 0)
                        }
                    }
                    .padding(.top, 18)
                HStack(spacing: 12) {
                    Text("0")
                    Spacer(minLength: 0)
                    legend(pal.flat, "平路")
                    legend(pal.go, "下坡")
                    legend(pal.stop, "上坡")
                    Spacer(minLength: 0)
                    Text(p.endLabel)
                }
                .font(.text(TextScale.caption))
                .foregroundStyle(pal.ink3)
                .padding(.top, 6)

                Spacer(minLength: 10)
                ForEach(Array(p.groups.enumerated()), id: \.element.id) { i, g in
                    if i > 0 { Hairline() }
                    group(g)
                }
            }
            .padding(.horizontal, Metrics.side)
            .padding(.top, 6)
            .padding(.bottom, 4)
        } actions: {
                if live {
                    // Already saved when the ride ended; this only confirms and returns home.
                    CapsuleButton(icon: "checkmark", label: "完成", fill: pal.go) {
                        Haptics.tap(.medium, settings)
                        model.go(.home)
                    }
                } else {
                    RoundButton(icon: "square.and.arrow.up", label: "导出 GPX", fill: pal.surface, tint: pal.ink) {
                        model.exportGPX(ride)
                    }
                }
        }
        .onAppear {
            withAnimation(Motion.profileWipe) { wiped = true }
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.text(TextScale.caption)).foregroundStyle(pal.ink2)
        }
    }

    /// One category: its name in a narrow left column, then its numbers in
    /// two equal columns (a lone number keeps to the first).
    private func group(_ g: SummaryPresentation.Group) -> some View {
        HStack(alignment: .center, spacing: Metrics.gridGap) {
            Text(g.title)
                .font(.text(TextScale.body, .semibold))
                .foregroundStyle(pal.ink)
                .frame(width: Metrics.categoryColumn, alignment: .leading)
            ForEach(g.cells, id: \.label) { Stat($0, TypeScale.stat) }
            if g.cells.count < 2 {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
        }
        .frame(maxHeight: Metrics.categoryRowMax)
        .accessibilityElement(children: .contain)
    }
}
