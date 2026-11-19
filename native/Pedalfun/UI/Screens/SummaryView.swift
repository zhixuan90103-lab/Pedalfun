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
        let f = settings.fmt

        ScreenScaffold {
            TopBar(title: "\(Fmt.date(ride.date)) \(Fmt.clock(ride.date))") {
                if !live {
                    IconButton(icon: "chevron.left", label: "返回") { model.go(fromHistory ? .history : .home) }
                }
            } trailing: {
                EmptyView()
            }
        } content: {
            // One screen, no scrolling: the profile flexes, the rows share what is left.
            VStack(alignment: .leading, spacing: 0) {
                Text(live ? "\(ride.name)，已保存" : ride.name)
                    .font(.system(size: 15))
                    .foregroundStyle(pal.ink2)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Num(f.dist(ride.dist), TypeScale.display)
                    Text(f.distUnit).font(.system(size: 16)).foregroundStyle(pal.ink2)
                }
                .padding(.top, 8)

                ElevationProfile(samples: ride.samples, maxSeg: 64)
                    .frame(minHeight: 40, maxHeight: 96)
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
                    Text("\(f.dist(ride.dist, digits: 1)) \(f.distUnit)")
                }
                .font(.system(size: 12))
                .foregroundStyle(pal.ink3)
                .padding(.top, 6)

                Spacer(minLength: 10)
                group("时间") {
                    stat("移动时间", nil, Fmt.dur(ride.moving))
                    stat("总耗时", nil, Fmt.dur(ride.total))
                }
                rule
                group("速度") {
                    stat("均速", f.speedUnit, f.speed(ride.avg))
                    stat("最高", f.speedUnit, f.speed(ride.max))
                }
                rule
                group("海拔") {
                    stat("爬升", f.altUnit, f.alt(ride.climb))
                    stat("最高", f.altUnit, f.alt(ride.altMax))
                }
                rule
                group("消耗") {
                    stat("估算", "kcal", ride.kcal(settings.profile).map(Fmt.kcal) ?? "--")
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
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
            Text(text).font(.system(size: 12)).foregroundStyle(pal.ink2)
        }
    }

    private var rule: some View {
        Rectangle().fill(pal.surface).frame(height: 1)
    }

    /// One category: its name in a narrow left column, then its numbers.
    private func group<Cells: View>(_ title: String, @ViewBuilder cells: () -> Cells) -> some View {
        HStack(alignment: .center, spacing: Metrics.gridGap) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pal.ink)
                .frame(width: 52, alignment: .leading)
            cells()
        }
        .frame(maxHeight: 78)
        .accessibilityElement(children: .contain)
    }

    private func stat(_ label: String, _ unit: String?, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            CellLabel(label, unit: unit)
            Num(value, TypeScale.stat)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
