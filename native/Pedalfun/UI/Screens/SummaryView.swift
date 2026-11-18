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
            ScrollView {
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
                        .frame(height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        // Wipes in from the left once.
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle().frame(width: wiped ? geo.size.width : 0)
                            }
                        }
                        .padding(.top, 26)
                    HStack {
                        Text("0")
                        Spacer()
                        Text("\(f.dist(ride.dist, digits: 1)) \(f.distUnit)")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(pal.ink3)
                    .padding(.top, 6)

                    HStack(spacing: 14) {
                        legend(pal.flat, "平路")
                        legend(pal.go, "下坡")
                        legend(pal.stop, "上坡")
                    }
                    .padding(.top, 12)

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 20) {
                        GridRow {
                            stat("移动时间", Fmt.dur(ride.moving), nil)
                            stat("总耗时", Fmt.dur(ride.total), nil)
                        }
                        GridRow {
                            stat("均速", f.speed(ride.avg), f.speedUnit)
                            stat("最高速度", f.speed(ride.max), f.speedUnit)
                        }
                        GridRow {
                            stat("爬升", f.alt(ride.climb), f.altUnit)
                            stat("最高海拔", f.alt(ride.altMax), f.altUnit)
                        }
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, Metrics.side)
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
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

    private func stat(_ label: String, _ value: String, _ unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            CellLabel(label)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Num(value, TypeScale.stat)
                if let unit {
                    Text(unit).font(.system(size: 13)).foregroundStyle(pal.ink3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
