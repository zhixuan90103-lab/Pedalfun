import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(RideStore.self) private var store
    @Environment(\.palette) private var pal

    @State private var permission: LocationPermission = .prompt
    @State private var grown = false
    @State private var startFrame: CGRect = .zero
    private static var autoStarted = false

    var body: some View {
        let f = settings.fmt
        let week = WeekStats(rides: store.rides)

        ScreenScaffold {
            TopBar {
                Text("Pedalfun")
                    .font(.num(TypeScale.card, bold: false))
                    .foregroundStyle(pal.ink)
                    .padding(.leading, 10)
            } trailing: {
                IconButton(icon: "text.alignleft", label: "骑行记录") { model.go(.history) }
                IconButton(icon: "slider.horizontal.3", label: "设置") { model.go(.settings) }
            }
        } content: {
            VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    CellLabel("本周里程")
                    Spacer()
                    GPSChip(permission: permission)
                }
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Num(f.dist(week.dist, digits: 1), TypeScale.display)
                    Text(f.distUnit).font(.system(size: 16)).foregroundStyle(pal.ink2)
                }
                .padding(.top, 4)
                Text(week.count == 0
                    ? "这周还没骑。"
                    : "\(week.count) 次骑行，\(Fmt.dur(week.moving))，爬升 \(f.alt(week.climb)) \(f.altUnit)")
                    .font(.system(size: 14))
                    .foregroundStyle(pal.ink2)
                    .padding(.top, 12)

                bars(week)
                    .frame(maxHeight: 150)
                    .padding(.top, 30)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.side)
            .padding(.top, 22)

            if let last = store.rides.first {
                lastRide(last, f)
            }
            }
        } actions: {
                RoundButton(icon: "play.fill", label: "开始骑行", fill: pal.go) {
                    Task {
                        await model.startRide(
                            origin: CGPoint(x: startFrame.midX, y: startFrame.midY),
                            radius: startFrame.width / 2
                        )
                        permission = LocationRecorder().permission
                    }
                }
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { startFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, r in startFrame = r }
                    }
                }
        }
        .onAppear {
            permission = LocationRecorder().permission
            grown = true
            // Review hook: `-autostart 1` presses start once, to exercise the real flow unattended.
            if ProcessInfo.processInfo.arguments.contains("-autostart"), !HomeView.autoStarted {
                HomeView.autoStarted = true
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    await model.startRide(
                        origin: CGPoint(x: startFrame.midX, y: startFrame.midY),
                        radius: startFrame.width / 2
                    )
                }
            }
        }
    }

    /// Seven day bars with weekday and date; today in green.
    private func bars(_ week: WeekStats) -> some View {
        let peak = max(week.perDay.max() ?? 0, 1)
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 14) {
            ForEach(0..<7, id: \.self) { i in
                let today = i == week.todayIndex
                let ratio = week.perDay[i] > 0 ? max(0.06, week.perDay[i] / peak) : 0
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            Capsule().fill(pal.surface)
                            Capsule()
                                .fill(today ? pal.go : pal.ink2)
                                .frame(height: max(geo.size.width, geo.size.height * ratio))
                                .opacity(ratio > 0 ? 1 : 0)
                                .scaleEffect(y: grown ? 1 : 0, anchor: .bottom)
                                .animation(
                                    Motion.barGrow.delay(Double(i) * 0.045 + 0.08),
                                    value: grown
                                )
                        }
                    }
                    .opacity(i > week.todayIndex ? 0.5 : 1)
                    VStack(spacing: 1) {
                        Text(labels[i])
                            .font(.system(size: 12, weight: today ? .semibold : .regular))
                            .foregroundStyle(today ? pal.goText : pal.ink3)
                        Text("\(week.dayNumbers[i])")
                            .font(.num(15, bold: false))
                            .foregroundStyle(today ? pal.goText : pal.ink2)
                    }
                }
            }
        }
    }

    private func lastRide(_ ride: Ride, _ f: Fmt) -> some View {
        Button {
            model.go(.summary(ride, live: false, fromHistory: false))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    CellLabel("上次骑行，\(Fmt.date(ride.date))")
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Num(f.dist(ride.dist, digits: 1), TypeScale.card)
                        Text(f.distUnit).font(.system(size: 13)).foregroundStyle(pal.ink2)
                        Num(Fmt.dur(ride.moving), TypeScale.card).padding(.leading, 8)
                    }
                }
                Spacer(minLength: 8)
                ElevationProfile(samples: ride.samples, maxSeg: 30)
                    .frame(width: 110, height: 36)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(pal.surface, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .padding(.horizontal, 16)
    }
}
